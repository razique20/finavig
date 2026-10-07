import 'package:flutter/material.dart';

import '../../models/finance.dart';
import '../../theme/app_theme.dart';

/// Per-row widgets for the Money tab. Moved verbatim from money_screen.dart
/// so screens that imported them (budgets, envelopes, records, home, quick
/// actions) can import this module instead of the whole screen file.

// ====================================================================
// Budget row
// ====================================================================

class BudgetRow extends StatelessWidget {
  final CategoryBudget budget;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BudgetRow({
    super.key,
    required this.budget,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = budget.monthlyLimit;
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;
    final barColor = over
        ? Colors.red
        : ratio > 0.8
        ? Colors.orange
        : theme.colorScheme.primary;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(budget.category.icon, size: 18, color: barColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    budget.category.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${MoneyFormat.aed(spent)} / ${MoneyFormat.aed(limit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: over ? Colors.red : theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  tooltip: 'Remove budget',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (over) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Over budget by ${MoneyFormat.aed(spent - limit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Envelope card
// ====================================================================

class EnvelopeCard extends StatelessWidget {
  final SavingsEnvelope envelope;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;

  const EnvelopeCard({
    super.key,
    required this.envelope,
    required this.onAdd,
    required this.onWithdraw,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, size: 18, color: Colors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  envelope.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${MoneyFormat.aed(envelope.savedAmount)} / ${MoneyFormat.aed(envelope.targetAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                tooltip: 'Delete envelope',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: envelope.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (envelope.monthlyContribution > 0)
                Text(
                  '${MoneyFormat.aed(envelope.monthlyContribution)}/mo plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              _pillButton(context, Icons.remove_rounded, onWithdraw),
              const SizedBox(width: 8),
              _pillButton(context, Icons.add_rounded, onAdd),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.teal),
      ),
    );
  }
}

// ====================================================================
// Transaction tile
// ====================================================================

class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.kind == FinanceKind.income;
    final amountColor = isIncome ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.category.icon,
              size: 18,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${transaction.category.displayName} • ${transaction.occurredAt.day}/${transaction.occurredAt.month}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Loan legs appear in the log but are excluded from the
                    // income/expense totals — label them so the difference is
                    // obvious rather than looking like a maths error.
                    if (transaction.isCreditLinked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Credit',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${MoneyFormat.aed(transaction.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Recurring template card
// ====================================================================

class RecurringCard extends StatelessWidget {
  final RecurringTransaction template;
  final int loggedCount;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RecurringCard({
    super.key,
    required this.template,
    required this.loggedCount,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = template.kind == FinanceKind.income;
    final amountColor = isIncome ? Colors.green : Colors.red;

    final nextDue = RecurrenceMath.nextOccurrence(
      template,
      template.frequency,
      DateTime.now(),
    );

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  template.category.icon,
                  size: 18,
                  color: template.isActive
                      ? amountColor
                      : FinavigColors.adaptiveIcon(context, theme.colorScheme.outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    template.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: template.isActive
                          ? null
                          : theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${MoneyFormat.aed(template.amount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: template.isActive
                        ? amountColor
                        : theme.colorScheme.outline,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  tooltip: 'Delete template',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  template.isActive
                      ? Icons.play_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 14,
                  color: FinavigColors.adaptiveIcon(context, theme.colorScheme.outline),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    template.isActive
                        ? '${template.frequency.label} · day ${template.dayOfMonth} · next ${nextDue == null ? '—' : '${nextDue.day}/${nextDue.month}/${nextDue.year}'} · $loggedCount logged'
                        : 'Paused · ${template.frequency.label} · day ${template.dayOfMonth}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onToggle,
                  child: Text(template.isActive ? 'Pause' : 'Resume'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
