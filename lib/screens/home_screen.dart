import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/document_collection.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/streak_service.dart';
import '../services/tab_scroll_registry.dart';
import '../theme/app_theme.dart';
import 'home/home_banners.dart';
import 'home/home_collection_switcher.dart';
import 'home/home_upcoming_section.dart';
import 'home/streak_details_sheet.dart';

// Peloton-inspired home tab (design reference only). Sections map to Finavig:
// search header, profile + activity streak, timeframe tabs, metrics cards
// (active docs, renewals, spend, net), category/filter pills, alerts,
// and "Live and Upcoming" renewals.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  DocumentCollection? _activeCollection;
  List<ExpiryItem> _items = [];
  bool _loading = true;

  /// Selected timeframe: 7, 30, or 90 days.
  int _selectedPeriod = 7;

  // "renewals need attention" banner dismissed this session.
  int? _dismissedAttentionCount;

  @override
  void initState() {
    super.initState();
    if (DocumentScannerService.instance.isInitialized) {
      _activeCollection = DocumentCollectionService.instance.collections
          .where(
            (c) =>
                c.id == DocumentCollectionService.instance.activeCollectionId,
          )
          .firstOrNull;
      _items = DocumentScannerService.instance.activeItems;
      _loading = false;
    }
    _loadData();
    TabScrollRegistry.register(0, _scrollController);
    FinanceService.instance.addListener(_reloadMoney);
    DocumentScannerService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(0, _scrollController);
    _scrollController.dispose();
    FinanceService.instance.removeListener(_reloadMoney);
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadData();
  }

  void _reloadMoney() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final collection = await DocumentCollectionService.instance
        .getActiveCollection();
    final items = await DocumentScannerService().getAllItems(
      includeExpired: true,
    );
    await FinanceService.instance.init();
    unawaited(StreakService.instance.recordActivity());
    if (mounted) {
      setState(() {
        _activeCollection = collection;
        _items = items;
        _loading = false;
      });
    }
  }

  List<ExpiryItem> get _expiredItems {
    final now = DateTime.now();
    return _items.where((i) => i.isActive && i.expiresAt.isBefore(now)).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  List<ExpiryItem> _upcomingItems() {
    final now = DateTime.now();
    final upcoming =
        _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return upcoming;
  }

  ({double income, double expense, double net}) get _financeSummary {
    final now = DateTime.now();
    return FinanceMath.summaryForMonth(
      FinanceService.instance.activeTransactions,
      now,
    );
  }

  /// Count of days in the last [period] with tracked activity — derived from
  /// the unified [StreakService].
  int _activeDaysInPeriod(int period) {
    return StreakService.instance.activeDaysInPeriod(
      period,
      items: _items,
      transactions: FinanceService.instance.activeTransactions,
    );
  }

  Future<void> _showCollectionSwitcher() async {
    final selectedId = await showHomeCollectionSwitcher(context);
    if (!mounted || selectedId == null) return;
    await applyHomeCollectionSelection(context, selectedId);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = FinavigTransition.of(
      context,
    ).color(const Color(0xFFF5F5F7), FinavigColors.obsidian);

    return Scaffold(
      backgroundColor: canvas,
      body: Container(
        color: canvas,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.secondary,
            onRefresh: _loadData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchHeader(onSearchTap: () => context.push('/search')),
                      const SizedBox(height: 10),
                      _ProfileStreakSection(
                        collectionName: _activeCollection?.name ?? 'Personal',
                        isPersonal: _activeCollection?.isPersonal ?? true,
                        userName: AuthService.instance.displayName,
                        onTap: _showCollectionSwitcher,
                      ),
                      const SizedBox(height: 14),
                      _TimeframeTabs(
                        selected: _selectedPeriod,
                        onPeriodChanged: (p) =>
                            setState(() => _selectedPeriod = p),
                      ),
                      const SizedBox(height: 12),
                      _MetricsCarousel(
                        activeDays: _activeDaysInPeriod(_selectedPeriod),
                        docsCount: _items.where((i) => i.isActive).length,
                        spent: _financeSummary.expense,
                        upcomingCount: _upcomingItems()
                            .where((i) => i.daysRemaining <= _selectedPeriod)
                            .length,
                      ),
                      const SizedBox(height: 14),
                      const _CategoryPillsRow(),
                      const SizedBox(height: 14),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _HomeSkeletonView(),
                        )
                      else ...[
                        HomeConsolidatedAlerts(
                          pendingActionNames: _upcomingItems()
                              .where((i) => i.daysRemaining <= 30)
                              .map((i) => i.displayName)
                              .toList(),
                          dismissedAttentionCount: _dismissedAttentionCount,
                          onDismissAttention: (count) => setState(
                            () => _dismissedAttentionCount = count,
                          ),
                          expiredItems: _expiredItems
                              .map(
                                (i) => HomeExpiredItem(
                                  id: i.id,
                                  displayName: i.displayName,
                                  daysRemaining: i.daysRemaining,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        _UpcomingSection(
                          items: _upcomingItems(),
                          onItemTap: (id) => context.push('/document/$id'),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  fillOverscroll: true,
                  child: ColoredBox(color: canvas),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _FloatingActionButton(
        onTap: () => context.push('/scan'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search header (Peloton-style pill search + action icons)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final VoidCallback onSearchTap;
  const _SearchHeader({required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final iconColor = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );
    final pillBg = fade.color(
      const Color(0xFFEDEDEF),
      FinavigColors.charcoal,
    );
    final hintColor = fade.color(
      FinavigColors.textMutedLight,
      FinavigColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: hintColor),
                      const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.bookmark_border_rounded,
            color: iconColor,
            onTap: () => context.push('/expiry-list'),
          ),
          _HeaderIconButton(
            icon: Icons.play_circle_outline_rounded,
            color: iconColor,
            onTap: () => context.push('/ai-summary'),
          ),
          _HeaderIconButton(
            icon: Icons.calendar_today_outlined,
            color: iconColor,
            onTap: () => context.push('/expiry-list'),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile + streak section (maps to Finavig collection / active-usage streak)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStreakSection extends StatelessWidget {
  final String collectionName;
  final bool isPersonal;
  final String userName;
  final VoidCallback onTap;

  const _ProfileStreakSection({
    required this.collectionName,
    required this.isPersonal,
    required this.userName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);

    return ListenableBuilder(
      listenable: StreakService.instance,
      builder: (context, _) {
        final streakCount = StreakService.instance.currentStreak;
        final weekDays = StreakService.instance.weekActivity();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: fade.color(
                      FinavigColors.accentSoft,
                      FinavigColors.slate,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: fade.color(FinavigColors.accent, Colors.white),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FV DASHBOARD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: fade.color(
                          FinavigColors.textMutedLight,
                          FinavigColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Welcome, $userName',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: fade.color(
                                FinavigColors.textPrimaryLight,
                                FinavigColors.textPrimary,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: fade.color(
                                const Color(0xFFEBECEF),
                                FinavigColors.slate,
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: fade.color(
                                  const Color(0xFFDCDDE2),
                                  Colors.white12,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPersonal
                                      ? Icons.person_rounded
                                      : Icons.business_center_rounded,
                                  size: 11,
                                  color: FinavigColors.accent,
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  isPersonal ? 'Personal' : collectionName,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: fade.color(
                                      FinavigColors.textPrimaryLight,
                                      FinavigColors.textPrimary,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.unfold_more_rounded,
                                  size: 11,
                                  color: fade.color(
                                    FinavigColors.textMutedLight,
                                    FinavigColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () => showStreakDetailsSheet(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              streakCount > 0 ? '🔥 ' : '⚡ ',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Flexible(
                              child: Text(
                                streakCount > 0
                                    ? (streakCount == 1
                                        ? '1 day streak active'
                                        : '$streakCount day streak going')
                                    : 'Start your streak today',
                                style: TextStyle(
                                  color: streakCount > 0
                                      ? fade.color(
                                          FinavigColors.textPrimaryLight,
                                          FinavigColors.textPrimary,
                                        )
                                      : fade.color(
                                          FinavigColors.textSecondaryLight,
                                          FinavigColors.textSecondary,
                                        ),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: fade.color(
                                FinavigColors.textMutedLight,
                                FinavigColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showStreakDetailsSheet(context),
                      child: _StreakRow(days: weekDays),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StreakRow extends StatelessWidget {
  final List<bool> days;
  const _StreakRow({required this.days});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    return Row(
      children: List.generate(7, (i) {
        final done = days[i];
        final isToday = i == todayIndex;
        final bg = done
            ? (isToday
                ? FinavigColors.accent
                : fade.color(
                    const Color(0xFFD9D9DE),
                    FinavigColors.slateLight,
                  ))
            : Colors.transparent;
        final border = !done
            ? Border.all(
                color: fade.color(
                  const Color(0xFFD0D0D6),
                  FinavigColors.slateLight,
                ),
                width: 1.2,
              )
            : null;
        final labelColor = isToday
            ? fade.color(
                FinavigColors.textPrimaryLight,
                FinavigColors.textPrimary,
              )
            : fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              );

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: border,
                ),
                child: done
                    ? Icon(
                        Icons.check,
                        size: 11,
                        color: isToday
                            ? Colors.white
                            : fade.color(
                                Colors.white,
                                FinavigColors.textPrimary,
                              ),
                      )
                    : null,
              ),
              const SizedBox(height: 2),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeframe tabs (7/30/90 Day)
// ─────────────────────────────────────────────────────────────────────────────

class _TimeframeTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPeriodChanged;
  const _TimeframeTabs({
    required this.selected,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    const periods = [7, 30, 90];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: periods.map((p) {
          final active = p == selected;
          return GestureDetector(
            onTap: () => onPeriodChanged(p),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$p Day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? fade.color(
                              FinavigColors.textPrimaryLight,
                              FinavigColors.textPrimary,
                            )
                          : fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2.5,
                    width: active ? 36 : 0,
                    decoration: BoxDecoration(
                      color: FinavigColors.logoRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics summary cards (Finavig: active days, documents, spend, renewals)
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsCarousel extends StatelessWidget {
  final int activeDays;
  final int docsCount;
  final double spent;
  final int upcomingCount;
  const _MetricsCarousel({
    required this.activeDays,
    required this.docsCount,
    required this.spent,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCardData(
        label: 'Active days',
        value: '$activeDays',
        delta: '+$activeDays',
      ),
      _MetricCardData(
        label: 'Documents',
        value: '$docsCount',
        delta: docsCount > 0 ? '+$docsCount' : '0',
      ),
      _MetricCardData(
        label: 'Spent',
        value: MoneyFormat.aed(spent),
        delta: spent > 0 ? '100%' : '0%',
        compactValue: true,
      ),
      _MetricCardData(
        label: 'Renewals',
        value: '$upcomingCount',
        delta: upcomingCount > 0 ? '+$upcomingCount' : '0',
      ),
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _MetricCard(data: cards[i]),
      ),
    );
  }
}

class _MetricCardData {
  final String label;
  final String value;
  final String delta;
  final bool compactValue;
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.delta,
    this.compactValue = false,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fade.color(
                FinavigColors.textSecondaryLight,
                FinavigColors.textSecondary,
              ),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: data.compactValue ? 15 : 18,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_drop_up_rounded,
                    size: 14,
                    color: FinavigColors.safe,
                  ),
                  Text(
                    data.delta,
                    style: const TextStyle(
                      color: FinavigColors.safe,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category filter pills (Finavig: Documents, Renewals, Money, AI)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPillsRow extends StatelessWidget {
  const _CategoryPillsRow();

  @override
  Widget build(BuildContext context) {
    final pills = [
      _CategoryPillData(
        label: 'Documents',
        icon: Icons.description_outlined,
        route: '/documents',
      ),
      _CategoryPillData(
        label: 'Renewals',
        icon: Icons.event_outlined,
        route: '/expiry-list',
      ),
      _CategoryPillData(
        label: 'Money',
        icon: Icons.account_balance_wallet_outlined,
        route: '/money',
      ),
      _CategoryPillData(
        label: 'AI Plan',
        icon: Icons.auto_awesome_outlined,
        route: '/ai-budget-plan',
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _CategoryPill(data: pills[i]),
      ),
    );
  }
}

class _CategoryPillData {
  final String label;
  final IconData icon;
  final String route;
  const _CategoryPillData({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class _CategoryPill extends StatelessWidget {
  final _CategoryPillData data;
  const _CategoryPill({required this.data});

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final bg = fade.color(Colors.white, FinavigColors.charcoal);
    final border = fade.color(
      Colors.black.withValues(alpha: 0.06),
      Colors.white.withValues(alpha: 0.08),
    );
    final fg = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: () {
          if (data.route == '/documents' ||
              data.route == '/money' ||
              data.route == '/home' ||
              data.route == '/profile') {
            context.go(data.route);
          } else {
            context.push(data.route);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Live and Upcoming" section (maps to Finavig upcoming renewals)
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingSection extends StatelessWidget {
  final List<ExpiryItem> items;
  final void Function(String id) onItemTap;
  const _UpcomingSection({required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = items.isNotEmpty ? items.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live and Upcoming',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (featured == null)
            _UpcomingEmptyCard()
          else
            _UpcomingFeatureCard(
              item: featured,
              onTap: () => onItemTap(featured.id),
            ),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next renewals · ${items.length - 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/expiry-list'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text('View all', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...items.skip(1).take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: HomeUpcomingTile(item: item),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingEmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No upcoming renewals',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan a document to start tracking renewals and deadlines.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fade.color(
                FinavigColors.textSecondaryLight,
                FinavigColors.textSecondary,
              ),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/scan'),
            style: FilledButton.styleFrom(
              backgroundColor: FinavigColors.logoRed,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              'SCAN DOCUMENT',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingFeatureCard extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback onTap;
  const _UpcomingFeatureCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isCritical = item.daysRemaining <= 7;
    final badgeText = item.daysRemaining <= 0
        ? 'EXPIRED'
        : isCritical
            ? 'URGENT'
            : 'UPCOMING';

    return Container(
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.expiresAt.day} ${_month(item.expiresAt.month)} ${item.expiresAt.year}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: fade.color(
                            FinavigColors.textMutedLight,
                            FinavigColors.textMuted,
                          ),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: fade.color(
                            FinavigColors.textSecondaryLight,
                            FinavigColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: fade.color(
                    Colors.black.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: fade.color(
                        FinavigColors.accentSoft,
                        FinavigColors.slate,
                      ),
                      child: Icon(
                        item.docType.icon,
                        color: fade.color(FinavigColors.accent, Colors.white),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.docType.displayName.toUpperCase()} · RENEWAL',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: fade.color(
                                FinavigColors.textSecondaryLight,
                                FinavigColors.textSecondary,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: FinavigColors.logoRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'VIEW',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.daysRemaining}d remaining',
                      style: const TextStyle(
                        color: FinavigColors.logoRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _month(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m - 1];
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating action button (Peloton-style red FAB)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingActionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: FinavigColors.logoRed,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: const Icon(Icons.document_scanner_rounded, size: 24),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSkeletonView extends StatelessWidget {
  const _HomeSkeletonView();

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final base = fade.color(const Color(0xFFE8E8EC), FinavigColors.slate);
    Widget box(double h, {double? w, double r = 12}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: box(68)),
          const SizedBox(width: 8),
          Expanded(child: box(68)),
          const SizedBox(width: 8),
          Expanded(child: box(68)),
        ]),
        const SizedBox(height: 12),
        box(140, r: 16),
      ],
    );
  }
}
