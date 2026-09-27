import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../services/alert_preferences_service.dart';
import '../services/budget_alert_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/smart_category_engine.dart';
import '../services/tab_scroll_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/ai_budget_plan_sheet.dart';
import '../widgets/dialogs/natural_language_money_add_dialog.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/cards/monthly_summary_card.dart';
import '../widgets/shimmer_skeleton.dart';
import 'package:uuid/uuid.dart';

// Modularized Money tab building blocks. The screen is now a slim stateful
// shell: state, data loading and the hero header live here; every content
// section is a standalone memoized widget in money/ — so tab switches and
// data refreshes rebuild small subtrees instead of the whole 3000-line tree.
import 'money/forms/budget_form_sheets.dart';
import 'money/forms/envelope_form_sheet.dart';
import 'money/forms/recurring_form_sheet.dart';
import 'money/forms/transaction_form_sheet.dart';
import 'money/money_planning_cards.dart';
import 'money/money_rows.dart';
import 'money/money_summary_cards.dart';

// Public API kept import-stable for envelopes/budgets/records/home screens,
// quick actions and tests: they import money_screen.dart for these.
export 'money/money_rows.dart'
    show BudgetRow, EnvelopeCard, TransactionTile;
export 'money/forms/transaction_form_sheet.dart'
    show TransactionFormSheet;
export 'money/forms/budget_form_sheets.dart'
    show OverallBudgetFormSheet, CategoryBudgetFormSheet;
export 'money/forms/envelope_form_sheet.dart' show EnvelopeFormSheet;

/// The Money tab: renewal cost outlook, monthly budget tracking, savings
/// envelopes and a transaction log with CSV export.
///
/// Architecture (modularization + frame-rate work):
/// * This shell owns mutable state and data loading only.
/// * Each section below is a [StatelessWidget]/memoized [StatefulWidget] in
///   lib/screens/money/ that rebuilds independently — a theme flip, a
///   snackbar, or a scroll never re-runs the other sections' builds.
/// * Derived computations (week buckets, top expenses, recent transactions)
///   are cached against list identity inside their widgets.
/// * Chart rows and transaction tiles are wrapped in [RepaintBoundary] so
///   ripples/ink effects stay local to their layer.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  // Root scrollable of this tab — registered so a bottom-nav tap scrolls
  // the tab back to the top (see TabScrollRegistry).
  final ScrollController _scrollController = ScrollController();

  List<FinanceTransaction> _transactions = [];
  List<CategoryBudget> _budgets = [];
  List<SavingsEnvelope> _envelopes = [];
  List<RecurringTransaction> _recurring = [];
  List<ExpiryItem> _items = [];
  double _renewalOutlook90 = 0;
  bool _loading = true;

  /// Bill-spike transaction ids the user dismissed this session; keeps the
  /// card hidden until a *new* anomaly appears. Cleared when the user
  /// re-enables bill spike alerts in Profile.
  final Set<String> _dismissedSpikeIds = {};

  StreamSubscription<BudgetAlertEvent>? _alertSub;

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(1, _scrollController);
    if (FinanceService.instance.isInitialized) {
      _transactions = FinanceService.instance.activeTransactions;
      _budgets = FinanceService.instance.activeBudgets;
      _envelopes = FinanceService.instance.activeEnvelopes;
      _recurring = FinanceService.instance.activeRecurring;
      if (DocumentScannerService.instance.isInitialized) {
        _items = DocumentScannerService.instance.activeItems;
        _renewalOutlook90 = FinanceMath.renewalOutlook(_items, 90);
      }
      _loading = false;
    }
    FinanceService.instance.addListener(_reload);
    _alertSub = BudgetAlertService.instance.stream.listen(_showBudgetAlert);
    _reload();
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(1, _scrollController);
    _scrollController.dispose();
    FinanceService.instance.removeListener(_reload);
    _alertSub?.cancel();
    super.dispose();
  }

  /// In-app surfacing of the budget alerts the service fires. (An OS
  /// notification is shown regardless — this is the "while the app is
  /// open" path.)
  void _showBudgetAlert(BudgetAlertEvent event) {
    // Respect the Profile toggle: no snackbar when budget alerts are off.
    if (!AlertPreferencesService.instance.budgetAlertsEnabled) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.title}\n${event.body}'),
        backgroundColor: event.isExceeded
            ? Theme.of(context).colorScheme.error
            : FinavigColors.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _reload() async {
    await FinanceService.instance.init();
    final items = await DocumentScannerService().getAllItems();
    if (!mounted) return;
    setState(() {
      _transactions = FinanceService.instance.activeTransactions;
      _budgets = FinanceService.instance.activeBudgets;
      _envelopes = FinanceService.instance.activeEnvelopes;
      _recurring = FinanceService.instance.activeRecurring;
      _items = items;
      _renewalOutlook90 = FinanceMath.renewalOutlook(items, 90);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(_transactions, now);
    final spendByCategory = FinanceMath.spendByCategory(_transactions, now);

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      // Same backdrop colors as the redesigned Home and Documents tabs.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: _reload,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroHeader(theme, summary),
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
                      ? MoneySkeletonView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            // Urgent anomalies (section owns its top spacing).
                            _sheetPadding(
                              BillSpikeAlertsCard(
                                transactions: _transactions,
                                dismissedIds: _dismissedSpikeIds,
                                onDismiss: (ids) => setState(() {
                                  _dismissedSpikeIds.addAll(ids);
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 1. Budget control.
                            _sheetPadding(
                              BudgetsSection(
                                budgets: _budgets,
                                spendByCategory: spendByCategory,
                                overallBudget:
                                    FinanceService.instance.activeOverallBudget,
                                onAddCategory: _showBudgetSheet,
                                onEditCategory: (b) =>
                                    _showBudgetSheet(existing: b),
                                onDeleteCategory: (b) =>
                                    FinanceService.instance.deleteBudget(b.id),
                                onEditOverall: _showOverallBudgetSheet,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 2. Spending analysis.
                            _sheetPadding(SpendingPaceCard(summary: summary)),
                            const SizedBox(height: 24),
                            _sheetPadding(
                                WeeklySpendChart(transactions: _transactions)),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              CategoryBreakdownCard(
                                spendByCategory: spendByCategory,
                                totalExpense: summary.expense,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                                TopExpensesCard(transactions: _transactions)),
                            const SizedBox(height: 24),
                            // 3. Compact AI summary, below the spending story
                            //    it reports on.
                            _sheetPadding(const MonthlySummaryCard()),
                            const SizedBox(height: 24),
                            // 4. Upcoming renewals & forecast.
                            _sheetPadding(
                                RenewalOutlookCard(outlook90: _renewalOutlook90)),
                            const SizedBox(height: 24),
                            _sheetPadding(
                                RenewalBreakdownCard(items: _items)),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              CashFlowTeaserCard(
                                transactions: _transactions,
                                recurring: _recurring,
                                items: _items,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 5. Planning & history.
                            _sheetPadding(
                              RecurringSection(
                                recurring: _recurring,
                                transactions: _transactions,
                                onAdd: _showRecurringSheet,
                                onEdit: (r) => _showRecurringSheet(existing: r),
                                onDelete: (r) =>
                                    FinanceService.instance.deleteRecurring(r.id),
                                onToggle: (r) => FinanceService.instance
                                    .setRecurringActive(r.id, !r.isActive),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              EnvelopesSection(
                                envelopes: _envelopes,
                                onAdd: _showEnvelopeSheet,
                                onAdjust: (e) => _adjustEnvelope(e, 100),
                                onDelete: (e) =>
                                    FinanceService.instance.deleteEnvelope(e.id),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                                TransactionsSection(
                                    transactions: _transactions)),
                            // Keep the last card scrollable clear of the
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
              // viewport when content is short, and into overscroll —
              // the navy backdrop never peeks out below the content,
              // behind the floating nav pill.
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

  // ------------------------------------------------------------------
  // Hero header: title, quick actions, month net + action pills
  // ------------------------------------------------------------------

  /// Navy gradient hero, same family as Home/Documents: title + quick
  /// actions, one live status line, the month net as the headline number,
  /// and the primary action pills.
  Widget _buildHeroHeader(
    ThemeData theme,
    ({double income, double expense, double net}) summary,
  ) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Money',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _MoneyHeroIconButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'Auto-Categorize with AI',
                onTap: _runAutoCategorizationAI,
              ),
              const SizedBox(width: 8),
              _MoneyHeroIconButton(
                icon: Icons.bolt_rounded,
                tooltip: 'Quick Add with Natural Language',
                onTap: () async {
                  final created = await NaturalLanguageMoneyAddDialog.show(
                    context,
                  );
                  if (created != null) _reload();
                },
              ),
              const SizedBox(width: 8),
              _MoneyHeroIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Export CSV',
                enabled: _transactions.isNotEmpty,
                onTap: _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // One-line live status: month + record count (tappable to view transactions).
          InkWell(
            onTap: () => context.push('/records'),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$monthName · ${_transactions.length} records',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Net this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // FittedBox: long balances scale down instead of overflowing the
          // hero on narrow screens (same fix as Home). No Flexible wrapper —
          // the hero Column gets unbounded height inside the sliver, so a
          // flex child here would crash the layout.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormat.aed(summary.net),
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyFormat.aed(summary.income)} in · ${MoneyFormat.aed(summary.expense)} out',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // 3 Navigation Pills in an equal-width row
          Row(
            children: [
              Expanded(
                child: _MoneyActionPill(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transactions',
                  onTap: () => context.push('/records'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MoneyActionPill(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Budgets',
                  onTap: () => context.push('/budgets'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MoneyActionPill(
                  icon: Icons.savings_rounded,
                  label: 'Envelopes',
                  onTap: () => context.push('/envelopes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // AI Budget Planner + Add Record side by side (quota is enforced
          // in-service).
          Row(
            children: [
              Expanded(
                child: _MoneyAddCard(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Budget Plan',
                  onTap: () => showAiBudgetPlanSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyAddCard(
                  icon: Icons.add_rounded,
                  label: 'Add Record',
                  onTap: _showAddTransactionSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Horizontal inset for cards inside the content sheet (the old layout
  /// relied on the ListView's global padding).
  Widget _sheetPadding(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      );

  // ------------------------------------------------------------------
  // Sheets & dialogs
  // ------------------------------------------------------------------

  Future<void> _showAddTransactionSheet() async {
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

    // Tier glue: a renewals payment linked to a tracked document closes the
    // loop — offer to mark that document as renewed right away.
    if (created.kind == FinanceKind.expense &&
        created.category == FinanceCategory.renewals &&
        created.documentId != null) {
      final item = await DocumentScannerService.instance.getItemById(
        created.documentId!,
      );
      if (item != null && mounted) {
        await _offerMarkAsRenewed(item, paymentAmount: created.amount);
      }
    }
  }

  /// Ask whether the just-logged payment completed the document's renewal.
  Future<void> _offerMarkAsRenewed(
    ExpiryItem item, {
    double? paymentAmount,
  }) async {
    final renewed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark ${item.displayName} as renewed?'),
        content: Text(
          'You logged a ${paymentAmount != null ? MoneyFormat.aed(paymentAmount) : 'renewal'} payment '
          'linked to this document. Renew it in place — the expiry date moves '
          'forward one year and reminders are rescheduled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Mark renewed ✓'),
          ),
        ],
      ),
    );
    if (renewed != true || !mounted) return;
    final newExpiry = DateTime(
      item.expiresAt.year + 1,
      item.expiresAt.month,
      item.expiresAt.day,
    );
    await DocumentScannerService.instance.markAsRenewed(
      item.id,
      newExpiryDate: newExpiry,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.displayName} renewed — now expires ${ExpiryItem.formatDate(newExpiry)} ✓',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showOverallBudgetSheet() async {
    final current = FinanceService.instance.activeOverallBudget;
    final result = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: OverallBudgetFormSheet(currentLimit: current),
      ),
    );
    if (result == null) return;
    await FinanceService.instance.setOverallBudget(result);
  }

  Future<void> _showBudgetSheet({CategoryBudget? existing}) async {
    final overallBudget = FinanceService.instance.activeOverallBudget;
    final double? maxAllowed = overallBudget != null
        ? FinanceMath.remainingUnallocatedBudget(
            overallBudget,
            _budgets,
            excludingCategoryId: existing?.id,
          )
        : null;

    final result = await showModalBottomSheet<(FinanceCategory, double)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CategoryBudgetFormSheet(
          existing: existing,
          maxAllowedLimit: maxAllowed,
        ),
      ),
    );
    if (result == null) return;
    await FinanceService.instance.upsertBudget(result.$1, result.$2);
  }

  Future<void> _showEnvelopeSheet() async {
    final result = await showModalBottomSheet<(String, double, double)>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EnvelopeFormSheet(),
    );
    if (result == null) return;
    await FinanceService.instance.addEnvelope(result.$1, result.$2, result.$3);
  }

  Future<void> _showRecurringSheet({RecurringTransaction? existing}) async {
    final result = await showModalBottomSheet<RecurringTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RecurringFormSheet(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await FinanceService.instance.addRecurring(result);
    } else {
      await FinanceService.instance.updateRecurring(result);
    }
  }

  Future<void> _adjustEnvelope(SavingsEnvelope envelope, double delta) async {
    await FinanceService.instance.adjustEnvelope(envelope.id, delta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delta > 0
              ? 'Set aside ${MoneyFormat.aed(delta)} in ${envelope.name}'
              : 'Withdrew ${MoneyFormat.aed(-delta)} from ${envelope.name}',
        ),
      ),
    );
  }

  Future<void> _runAutoCategorizationAI() async {
    final updatedCount = await FinanceService.instance
        .autoCategorizeExistingTransactions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedCount > 0
              ? 'AI Auto-Categorized $updatedCount transaction${updatedCount > 1 ? "s" : ""}! ✨'
              : 'All transactions are already accurately categorized! ✓',
        ),
        backgroundColor: updatedCount > 0
            ? FinavigColors.violetAccent
            : Colors.green,
      ),
    );
    _reload();
  }

  // ------------------------------------------------------------------
  // CSV export
  // ------------------------------------------------------------------

  Future<void> _exportCsv() async {
    // Track 1 gate: CSV/PDF report export is a Plus feature.
    if (!EntitlementService.instance.allows(EntitlementFeature.reportExport)) {
      await showUpgradeDialog(context, EntitlementFeature.reportExport);
      return;
    }

    final csv = FinanceMath.toCsv(_transactions);
    try {
      final path = await FilePicker.platform.saveFile(
        fileName:
            'finavig-finance-${DateTime.now().toIso8601String().split('T').first}.csv',
        bytes: Uint8List.fromList(csv.codeUnits),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'CSV saved to $path' : 'Export cancelled',
          ),
        ),
      );
    } catch (_) {
      // saveFile unsupported on this platform — fall back to clipboard.
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    }
  }
}

/// Frosted glass icon button in the Money hero header — same style as the
/// Home/Documents hero icon buttons.
class _MoneyHeroIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _MoneyHeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: enabled
                  ? Colors.white
                  : Colors.white.withOpacity(0.35),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact filled card button for the hero's primary action.
class _MoneyAddCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoneyAddCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted glass action pill used in the hero row.
class _MoneyActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoneyActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
