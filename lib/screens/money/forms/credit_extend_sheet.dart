import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/credit.dart';

// Sheet for extending a credit entry's deadline. The original
// deadline and every extension are kept on record — the
// repayment-behaviour trail is the input for the future
// credit-giving mechanism. Pops with the new deadline.
class CreditExtendSheet extends StatefulWidget {
  final CreditEntry entry;

  const CreditExtendSheet({super.key, required this.entry});

  @override
  State<CreditExtendSheet> createState() => _CreditExtendSheetState();
}

class _CreditExtendSheetState extends State<CreditExtendSheet> {
  // Default suggestion: a month past the current deadline.
  late DateTime _newDeadline = widget.entry.deadline.add(
    const Duration(days: 30),
  );

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDeadline,
      // Must be strictly after the current deadline — that's what
      // makes it an extension rather than an edit.
      firstDate: widget.entry.deadline.add(const Duration(days: 1)),
      lastDate: widget.entry.deadline.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _newDeadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Extend deadline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.counterpartyName} · '
              '${CreditMath.formatDate(entry.deadline)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _historyTile(
                    icon: Icons.event_rounded,
                    label: 'Original deadline',
                    value: CreditMath.formatDate(entry.originalDeadline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _historyTile(
                    icon: Icons.event_repeat_rounded,
                    label: 'Extensions',
                    value: entry.extensionCount == 0
                        ? 'None yet'
                        : '${entry.extensionCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'New deadline',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_newDeadline),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The original deadline and every extension stay '
                      'on this record — your repayment-behaviour '
                      'history is preserved.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _newDeadline),
              icon: const Icon(Icons.event_repeat_rounded, size: 18),
              label: Text(
                'Extend to ${DateFormat('dd MMM yyyy').format(_newDeadline)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
