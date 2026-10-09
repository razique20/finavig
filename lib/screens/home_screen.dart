import 'package:flutter/material.dart';

import '../models/document_collection.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/tab_scroll_registry.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'home/home_banners.dart';
import 'home/home_categories_grid.dart';
import 'home/home_collection_switcher.dart';
import 'home/home_hero_header.dart';
import 'home/home_upcoming_section.dart';
import 'money/forms/transaction_form_sheet.dart';

/// Home tab: cross-tier dashboard on the light, airy canvas.
///
/// A greeting + gradient balance card, a bento categories grid, the alert
/// banners, and the next renewals. Details live in the Documents and Money
/// tabs. The heavy lifting lives in `lib/screens/home/` modules so each
/// section rebuilds independently.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Root scrollable of this tab — registered so a bottom-nav tap scrolls
  // the tab back to the top (see TabScrollRegistry).
  final ScrollController _scrollController = ScrollController();

  DocumentCollection? _activeCollection;
  List<ExpiryItem> _items = [];
  bool _loading = true;

  /// The "renewals need attention" banner was closed by the user this
  /// session. Re-appears on restart or when data reloads with a *new* count.
  int? _dismissedAttentionCount;

  @override
  void initState() {
    super.initState();
    if (DocumentScannerService.instance.isInitialized) {
      _activeCollection = DocumentCollectionService
          .instance.collections
          .where((c) =>
              c.id ==
              DocumentCollectionService.instance.activeCollectionId)
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

  /// Active documents already past their expiry date.
  List<ExpiryItem> get _expiredItems {
    final now = DateTime.now();
    return _items.where((i) => i.isActive && i.expiresAt.isBefore(now)).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  Future<void> _loadData() async {
    final collection =
        await DocumentCollectionService.instance.getActiveCollection();
    final items = await DocumentScannerService().getAllItems(
      includeExpired: true,
    );
    await FinanceService.instance.init();
    if (mounted) {
      setState(() {
        _activeCollection = collection;
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);
    // Canvas + wash resolve through the theme transition factor so they
    // cross-fade with the theme animation instead of snapping.
    final fade = FinavigTransition.of(context);
    final canvas = fade.color(FinavigColors.snowWhite, FinavigColors.obsidian);
    final wash = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        fade.color(FinavigColors.accentSoft, const Color(0xFF151830)),
        canvas,
      ],
      stops: const [0.0, 0.55],
    );

    return Scaffold(
      backgroundColor: canvas,
      body: Container(
        decoration: BoxDecoration(gradient: wash),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: theme.colorScheme.secondary,
            onRefresh: _loadData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeHeroHeader(
                        activeCollection: _activeCollection,
                        items: _items,
                        dismissedAttentionCount: _dismissedAttentionCount,
                        budgetUsagePct: _budgetUsagePct(),
                        onCollectionSwitcherTap: _showCollectionSwitcher,
                        onQuickAddRecord: _quickAddRecord,
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const SizedBox(height: 420, child: HomeSkeletonView())
                      else ...[
                        HomeCategoriesGrid(
                          pendingActionsCount: urgency.pendingActions.length,
                          onScanTap: _openScanner,
                        ),
                        const FirstRunGuideBanner(),
                        HomePlanRestrictionBanner(),
                        // Both banners own their top margin internally and
                        // collapse to zero height when not applicable, so
                        // no reserved gap can ever appear between sections.
                        HomeAttentionBanner(
                          pendingActionNames: urgency.pendingActions
                              .map((a) => a.displayName)
                              .toList(),
                          dismissedAttentionCount: _dismissedAttentionCount,
                          onDismiss: (count) => setState(
                            () => _dismissedAttentionCount = count,
                          ),
                        ),
                        if (_expiredItems.isNotEmpty)
                          HomeExpiredAlert(
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
                        const SizedBox(height: 20),
                        HomeUpcomingSection(
                          upcomingItems: _upcomingItems(),
                        ),
                        // Keep the last tile clear of the floating nav pill
                        // (height + margins ≈ 80).
                        SizedBox(
                          height:
                              8 + MediaQuery.of(context).padding.bottom + 80,
                        ),
                      ],
                    ],
                  ),
                ),
                // Canvas filler: extends the background across the rest of
                // the viewport and into overscroll behind the nav pill.
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
    );
  }

  /// Monthly budget usage percentage (0-100), or 0 if no budgets exist.
  int _budgetUsagePct() {
    final budgets = FinanceService.instance.activeBudgets;
    if (budgets.isEmpty) return 0;
    final spend = FinanceMath.spendByCategory(
      FinanceService.instance.activeTransactions,
      DateTime.now(),
      collectionId: FinanceService.instance.activeCollectionIdSafe,
    );
    final statuses = FinanceMath.budgetStatuses(budgets, spend);
    return (statuses.fold<double>(
      0.0,
      (prev, s) => prev + (s.ratio * 100),
    )).round();
  }

  /// Upcoming (active, not yet expired) documents sorted by expiry.
  List<ExpiryItem> _upcomingItems() {
    final now = DateTime.now();
    final upcoming =
        _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return upcoming;
  }

  /// Open the collection switcher sheet and apply the selection.
  Future<void> _showCollectionSwitcher() async {
    final selectedId = await showHomeCollectionSwitcher(context);
    if (!mounted || selectedId == null) return;

    await applyHomeCollectionSelection(context, selectedId);
    await _loadData();
  }

  /// Open the scan flow after enforcing the free-tier document limit.
  Future<void> _openScanner() => openGatedScanner(context);

  /// Quick-add a money record without leaving Home: the same form sheet the
  /// Money tab uses; FinanceService notifies and the balance card refreshes.
  Future<void> _quickAddRecord() async {
    final created = await showModalBottomSheet<FinanceTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TransactionFormSheet(),
    );
    if (created == null) return;
    await FinanceService.instance.addTransaction(created);
  }
}
