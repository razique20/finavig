import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/credit.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../services/alert_preferences_service.dart';
import '../services/budget_alert_service.dart';
import '../services/credit_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/tab_scroll_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/ai_budget_plan_sheet.dart';
import '../widgets/dialogs/ask_finavig_sheet.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/cards/monthly_summary_card.dart';
import '../widgets/shimmer_skeleton.dart';

// Modularized Money tab building blocks. The screen is now a slim stateful
// shell: state, data loading and the hero header live here; every content
// section is a standalone memoized widget in money/ — so tab switches and
// data refreshes rebuild small subtrees instead of the whole 3000-line tree.
import 'money/credit_section.dart';
import 'money/forms/budget_form_sheets.dart';
import 'money/forms/credit_extend_sheet.dart';
import 'money/forms/credit_form_sheet.dart';
import 'money/forms/credit_settle_sheet.dart';
import 'money/forms/envelope_form_sheet.dart';
import 'money/forms/recurring_form_sheet.dart';
import 'money/forms/transaction_form_sheet.dart';
import 'money/money_planning_cards.dart';
import 'money/money_summary_cards.dart';

// Public API kept import-stable for envelopes/budgets/records/home screens,
// quick actions and tests: they import money_screen.dart for these.
export 'money/money_rows.dart' show BudgetRow, EnvelopeCard, TransactionTile;
export 'money/forms/transaction_form_sheet.dart' show TransactionFormSheet;
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
  List<CreditEntry> _credits = [];
  List<ExpiryItem> _items = [];
  bool _loading = true;

  /// Bill-spike transaction ids the user dismissed this session; keeps the
  /// card hidden until a *new* anomaly appears. Cleared when the user
  /// re-enables bill spike alerts in Profile.
  final Set<String> _dismissedSpikeIds = {};

  /// Section ids currently minimized on this tab. Each section in the
  /// light sheet collapses to its header; tapping the header again
  /// expands it. Every section starts minimized, so the sheet opens
  /// as a compact index of headers the user can expand on demand.
  final Set<String> _collapsedSections = {
    'budgets',
    'pace',
    'weekly',
    'categories',
    'top',
    'renewalBreakdown',
    'recurring',
    'envelopes',
    'credit',
    'transactions',
  };

  void _toggleSection(String id) => setState(() {
    if (!_collapsedSections.remove(id)) _collapsedSections.add(id);
  });

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
      _credits = CreditService.instance.activeCredits;
      if (DocumentScannerService.instance.isInitialized) {
        _items = DocumentScannerService.instance.activeItems;
      }
      _loading = false;
    }
    FinanceService.instance.addListener(_reload);
    CreditService.instance.addListener(_reload);
    _alertSub = BudgetAlertService.instance.stream.listen(_showBudgetAlert);
    _reload();
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(1, _scrollController);
    _scrollController.dispose();
    FinanceService.instance.removeListener(_reload);
    CreditService.instance.removeListener(_reload);
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
    await CreditService.instance.init();
    final items = await DocumentScannerService().getAllItems();
    if (!mounted) return;
    setState(() {
      _transactions = FinanceService.instance.activeTransactions;
      _budgets = FinanceService.instance.activeBudgets;
      _envelopes = FinanceService.instance.activeEnvelopes;
      _recurring = FinanceService.instance.activeRecurring;
      _credits = CreditService.instance.activeCredits;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(_transactions, now);
    final spendByCategory = FinanceMath.spendByCategory(_transactions, now);

    // Light canvas (matching the redesigned Home tab); the hero is now a dark
    // ink card floating on top instead of a full-width band.
    final canvas = FinavigTransition.of(
      context,
    ).color(Colors.white, FinavigColors.obsidian);

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: _reload,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroHeader(theme, summary)),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  child: _loading
                      ? const SizedBox(height: 420, child: MoneySkeletonView())
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
                            // 1. At a glance: the month's summary, the
                            //    upcoming renewal fees, the forecast and
                            //    the credit shortcut stack flush as one
                            //    group — no gap between them.
                            _sheetPadding(const MonthlySummaryCard()),
                            _sheetPadding(
                              RenewalBreakdownCard(
                                items: _items,
                                collapsed: _collapsedSections.contains(
                                  'renewalBreakdown',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('renewalBreakdown'),
                              ),
                            ),
                            _sheetPadding(const CashFlowTeaserCard()),
                            // Credit shortcut — relocated out of the
                            // dark hero into the light sheet.
                            _sheetPadding(
                              _CreditShortcutCard(
                                onTap: () => context.push('/credits'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 2. Spending pace, then budget control.
                            _sheetPadding(
                              SpendingPaceCard(
                                summary: summary,
                                collapsed: _collapsedSections.contains('pace'),
                                onToggleSection: () => _toggleSection('pace'),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                collapsed: _collapsedSections.contains(
                                  'budgets',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('budgets'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 3. Planning & history.
                            _sheetPadding(
                              RecurringSection(
                                recurring: _recurring,
                                transactions: _transactions,
                                onAdd: _showRecurringSheet,
                                onEdit: (r) => _showRecurringSheet(existing: r),
                                onDelete: (r) => FinanceService.instance
                                    .deleteRecurring(r.id),
                                onToggle: (r) => FinanceService.instance
                                    .setRecurringActive(r.id, !r.isActive),
                                collapsed: _collapsedSections.contains(
                                  'recurring',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('recurring'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              EnvelopesSection(
                                envelopes: _envelopes,
                                onAdd: _showEnvelopeSheet,
                                // + adds and − withdraws the envelope's
                                // step (plan amount, or AED 50). Both signs
                                // are decided here, per envelope.
                                onAdjust: (e) =>
                                    _adjustEnvelope(e, e.adjustStep),
                                onWithdraw: (e) =>
                                    _adjustEnvelope(e, -e.adjustStep),
                                onDelete: (e) => FinanceService.instance
                                    .deleteEnvelope(e.id),
                                collapsed: _collapsedSections.contains(
                                  'envelopes',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('envelopes'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 4. Credit obligations.
                            _sheetPadding(
                              CreditSection(
                                credits: _credits,
                                onAdd: _showCreditSheet,
                                onEdit: (c) => _showCreditSheet(existing: c),
                                onDelete: (c) =>
                                    CreditService.instance.deleteCredit(c.id),
                                onExtend: _showExtendDeadlineSheet,
                                onSettle: _showSettleCreditSheet,
                                collapsed: _collapsedSections.contains(
                                  'credit',
                                ),
                                onToggleSection: () => _toggleSection('credit'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 5. Transactions — the list most visits come
                            //    for — then the spending analysis that is
                            //    read from it.
                            _sheetPadding(
                              TransactionsSection(
                                transactions: _transactions,
                                collapsed: _collapsedSections.contains(
                                  'transactions',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('transactions'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              WeeklySpendChart(
                                transactions: _transactions,
                                collapsed: _collapsedSections.contains(
                                  'weekly',
                                ),
                                onToggleSection: () => _toggleSection('weekly'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              CategoryBreakdownCard(
                                spendByCategory: spendByCategory,
                                totalExpense: summary.expense,
                                collapsed: _collapsedSections.contains(
                                  'categories',
                                ),
                                onToggleSection: () =>
                                    _toggleSection('categories'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sheetPadding(
                              TopExpensesCard(
                                transactions: _transactions,
                                collapsed: _collapsedSections.contains('top'),
                                onToggleSection: () => _toggleSection('top'),
                              ),
                            ),
                            // Keep the last card scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height:
                                  8 +
                                  MediaQuery.of(context).padding.bottom +
                                  80,
                            ),
                          ],
                        ),
                ),
              ),
              // Canvas filler: extends the background across the rest of the
              // viewport and into overscroll behind the floating nav pill.
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: ColoredBox(color: canvas),
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

  /// Money header, same family as the redesigned Home tab: the title and
  /// quick actions sit on the canvas, and the month net lives in a dark ink
  /// card carrying the live status line and the primary action pills.
  Widget _buildHeroHeader(
    ThemeData theme,
    ({double income, double expense, double net}) summary,
  ) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());
    final fade = FinavigTransition.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Money',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  ),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _MoneyHeroIconButton(
                icon: Icons.auto_fix_high_rounded,
                tooltip: 'Auto-Categorize with AI',
                onTap: _runAutoCategorizationAI,
              ),
              const SizedBox(width: 8),
              _MoneyHeroIconButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'Ask Finavig AI',
                onTap: () async {
                  final result = await AskFinavigSheet.show(context);
                  if (result is AskMoneyResult) {
                    await FinanceService.instance.addTransaction(
                      result.transaction,
                    );
                    final recurring = result.recurringTemplate;
                    if (recurring != null) {
                      await FinanceService.instance.addRecurring(recurring);
                    }
                  }
                  // Documents saved inside the sheet notify listeners; the
                  // recurring side-list is also already updated. `_reload`
                  // would double-fire and rebuild needlessly here.
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
          const SizedBox(height: 16),
          // The month summary is the dark ink card — same language as Home.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: fade.color(FinavigColors.ink, FinavigColors.charcoal),
              borderRadius: BorderRadius.circular(FinavigRadius.card + 4),
              border: Border.all(
                color: fade.color(
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.06),
                ),
              ),
              boxShadow: FinavigShadows.adaptive(
                theme.brightness == Brightness.dark,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                // 3 navigation pills in an equal-width row. Credit
                // moved out of the dark hero into the light sheet
                // below (see _CreditShortcutCard); three across still
                // fits every label thanks to the pill's tightened
                // metrics.
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

  Future<void> _showCreditSheet({CreditEntry? existing}) async {
    final result = await showModalBottomSheet<CreditFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreditFormSheet(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      // The form may have built the principal's Money leg when the user
      // ticked "Also record this in Money".
      await CreditService.instance.addCreditWithDisbursement(
        result.entry,
        disbursement: result.disbursement,
      );
    } else {
      await CreditService.instance.updateCredit(result.entry);
    }
  }

  /// Close a credit obligation, optionally mirroring the repayment into
  /// Money (new record or an existing one the user already logged).
  Future<void> _showSettleCreditSheet(CreditEntry entry) async {
    final result = await showModalBottomSheet<CreditSettlement>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreditSettleSheet(entry: entry),
    );
    if (result == null) return;
    await CreditService.instance.settleCredit(
      entry.id,
      settledAt: result.settledAt,
      transaction: result.newTransaction,
      transactionId: result.linkedTransactionId,
      disbursementTransactionId: result.linkedDisbursementId,
    );
  }

  Future<void> _showExtendDeadlineSheet(CreditEntry entry) async {
    final newDeadline = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreditExtendSheet(entry: entry),
    );
    if (newDeadline == null) return;
    await CreditService.instance.extendDeadline(entry.id, newDeadline);
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

/// Header icon button on the Money tab — a soft accent chip in light mode and
/// a translucent white chip in dark, like the Home and Documents headers. The
/// glyph is the dark ink on the light canvas; in dark mode it flips to white.
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
    final fade = FinavigTransition.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? fade.color(
                FinavigColors.accent.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.12),
              )
            : fade.color(
                FinavigColors.mist,
                Colors.white.withValues(alpha: 0.05),
              ),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              color: enabled
                  ? fade.color(FinavigColors.ink, Colors.white)
                  : fade.color(
                      FinavigColors.textMutedLight,
                      Colors.white.withValues(alpha: 0.35),
                    ),
              size: 17,
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

/// Credit quick-access card at the top of the Money sheet —
/// relocated from the dark hero's pill row so the entry point
/// lives outside the dark section, in the light content area.
class _CreditShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreditShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.handshake_rounded, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credit',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Borrowed, lent & deadlines',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
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
          // Tightened so three pills side by side still fit their
          // longest label ("Transactions") without ellipsizing.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
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
