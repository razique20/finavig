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

/// Home tab: cross-tier dashboard.
///
/// Only the essentials: what needs attention (documents), where the money
/// stands this month (budget summary), and the next renewals. Details live in
/// the Documents and Money tabs. The heavy lifting lives in `lib/screens/home/`
/// modules so each section rebuilds independently.
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeroHeader(
                  activeCollection: _activeCollection,
                  items: _items,
                  dismissedAttentionCount: _dismissedAttentionCount,
                  onCollectionSwitcherTap: _showCollectionSwitcher,
                  onQuickAddRecord: _quickAddRecord,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? HomeSkeletonView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
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
                            // Keep the last tile scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height: 8 +
                                  MediaQuery.of(context).padding.bottom +
                                  80,
                            ),
                          ],
                        ),
                ),
              ),
              // White filler: extends the sheet across the rest of the
              // viewport when content is short, and into overscroll
              // (iOS bounce) — the navy backdrop never peeks out below
              // the content, behind the floating nav pill. Kept empty: a
              // fill-remaining sliver queries the child's intrinsics
              // during overscroll, which a shrinkWrap grid can't do.
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: ColoredBox(color: theme.colorScheme.surface),
              ),
            ],
          ),
        ),
      ),
    );
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
  /// Money tab uses; FinanceService notifies and the hero totals refresh.
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
