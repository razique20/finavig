import 'package:flutter/material.dart';

import '../../models/finance.dart';
import '../../theme/app_theme.dart';
import 'money_rows.dart';
import 'money_sections.dart';

/// Re-exported so the slim Money screen and dependent screens keep one import
/// path for the row widgets that used to live in money_screen.dart.
export 'money_rows.dart';

/// Budgets section: overall budget card + per-category budget rows.
///
/// Memoization: per-row [BudgetRowCard]s are const-compatible; the section
/// itself rebuilds only when the parent passes new inputs.
class BudgetsSection extends StatelessWidget {
  final List<CategoryBudget> budgets;
  final Map<FinanceCategory, double> spendByCategory;
  final double? overallBudget;
  final VoidCallback onAddCategory;
  final void Function(CategoryBudget) onEditCategory;
  final void Function(CategoryBudget) onDeleteCategory;
  final VoidCallback onEditOverall;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const BudgetsSection({
    super.key,
    required this.budgets,
    required this.spendByCategory,
    required this.overallBudget,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onEditOverall,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAllocated = FinanceMath.totalBudgetAllocated(budgets);
    final isOverAllocated =
        overallBudget != null && totalAllocated > overallBudget!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.speed_rounded,
          title: 'Monthly budgets',
          actionLabel: 'Add category',
          onAction: onAddCategory,
          collapsed: collapsed,
          onToggle: onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isOverAllocated
                      ? theme.colorScheme.error
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              color: isOverAllocated
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 20,
                          color: isOverAllocated
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Overall Monthly Budget',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onEditOverall,
                          icon: Icon(
                            overallBudget == null
                                ? Icons.add_rounded
                                : Icons.edit_rounded,
                            size: 16,
                          ),
                          label: Text(
                            overallBudget == null ? 'Set budget' : 'Edit',
                          ),
                        ),
                      ],
                    ),
                    if (overallBudget != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        MoneyFormat.aed(overallBudget!),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Allocated: ${MoneyFormat.aed(totalAllocated)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isOverAllocated
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isOverAllocated
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          Text(
                            isOverAllocated
                                ? 'Over: ${MoneyFormat.aed(totalAllocated - overallBudget!)}'
                                : 'Remaining: ${MoneyFormat.aed(overallBudget! - totalAllocated)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isOverAllocated
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (totalAllocated / overallBudget!).clamp(
                            0.0,
                            1.0,
                          ),
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: isOverAllocated
                              ? theme.colorScheme.error
                              : (totalAllocated == overallBudget
                                    ? Colors.orange
                                    : theme.colorScheme.primary),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'No overall monthly budget set. Tap "Set budget" to set a total monthly spending limit across all categories.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (budgets.isEmpty)
              HintCard(
                overallBudget != null
                    ? 'No category budgets added yet. Tap "Add category" to allocate your monthly budget.'
                    : 'Set a monthly limit for any category to see progress here.',
                scene: EmptyStateScene.growth,
              )
            else
              ...budgets.map((budget) {
                final spent = spendByCategory[budget.category] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BudgetRow(
                    budget: budget,
                    spent: spent,
                    onEdit: () => onEditCategory(budget),
                    onDelete: () => onDeleteCategory(budget),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

/// Recurring transactions section.
class RecurringSection extends StatelessWidget {
  final List<RecurringTransaction> recurring;
  final List<FinanceTransaction> transactions;
  final VoidCallback onAdd;
  final void Function(RecurringTransaction) onEdit;
  final void Function(RecurringTransaction) onDelete;
  final void Function(RecurringTransaction) onToggle;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const RecurringSection({
    super.key,
    required this.recurring,
    required this.transactions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.event_repeat_rounded,
          title: 'Recurring',
          actionLabel: 'Add',
          actionKey: const Key('recurring-add'),
          onAction: onAdd,
          collapsed: collapsed,
          onToggle: onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            const SizedBox(height: 12),
            if (recurring.isEmpty)
              const HintCard(
                'Mark rent, salaries or software as monthly and they are auto-logged here — no manual repeats.',
                scene: EmptyStateScene.document,
              )
            else
              ...recurring.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RecurringCard(
                    template: r,
                    loggedCount: transactions
                        .where(
                          (t) =>
                              t.note != null &&
                              t.note!.contains('recurring template'),
                        )
                        .length,
                    onToggle: () => onToggle(r),
                    onEdit: () => onEdit(r),
                    onDelete: () => onDelete(r),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Savings envelopes section.
class EnvelopesSection extends StatelessWidget {
  final List<SavingsEnvelope> envelopes;
  final VoidCallback onAdd;
  final void Function(SavingsEnvelope) onAdjust;
  final void Function(SavingsEnvelope) onWithdraw;
  final void Function(SavingsEnvelope) onDelete;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const EnvelopesSection({
    super.key,
    required this.envelopes,
    required this.onAdd,
    required this.onAdjust,
    required this.onWithdraw,
    required this.onDelete,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.savings_rounded,
          title: 'Savings envelopes',
          actionLabel: 'Add',
          onAction: onAdd,
          collapsed: collapsed,
          onToggle: onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            const SizedBox(height: 12),
            if (envelopes.isEmpty)
              const HintCard(
                'Set aside money for big renewals — tracked only, no real money moves.',
                scene: EmptyStateScene.wallet,
              )
            else
              ...envelopes.map(
                (envelope) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EnvelopeCard(
                    envelope: envelope,
                    // + adds and − withdraws: two distinct callbacks so the
                    // card's two buttons can never collapse to one action.
                    onAdd: () => onAdjust(envelope),
                    onWithdraw: () => onWithdraw(envelope),
                    onDelete: () => onDelete(envelope),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Transactions section — the list that matters most for frame rates.
///
/// Performance notes:
/// * Sort + take(20) is memoized per list identity in state, so scrolling or
///   theme changes never re-sort hundreds of transactions.
/// * Rows are wrapped in RepaintBoundary so a tile's ink ripple doesn't
///   repaint its neighbours.
class TransactionsSection extends StatefulWidget {
  final List<FinanceTransaction> transactions;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const TransactionsSection({
    super.key,
    required this.transactions,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  State<TransactionsSection> createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends State<TransactionsSection> {
  List<FinanceTransaction>? _cachedRecent;
  List<FinanceTransaction>? _cachedSource;

  List<FinanceTransaction> _recent() {
    if (_cachedRecent != null &&
        identical(_cachedSource, widget.transactions)) {
      return _cachedRecent!;
    }
    final sorted = [...widget.transactions]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recent = sorted.take(20).toList();
    _cachedSource = widget.transactions;
    _cachedRecent = recent;
    return recent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = _recent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.receipt_long_rounded,
          title: 'Transactions',
          collapsed: widget.collapsed,
          onToggle: widget.onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: widget.collapsed,
          children: [
            const SizedBox(height: 12),
            if (recent.isEmpty)
              const HintCard(
                'No records yet. Add your first expense or income.',
                scene: EmptyStateScene.wallet,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) InsetDivider(indent: 56),
                      RepaintBoundary(
                        child: TransactionTile(transaction: recent[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
