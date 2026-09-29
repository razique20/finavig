import 'package:flutter/material.dart';

import '../../../models/finance.dart';
import '../../../services/collection_service.dart';
import 'package:uuid/uuid.dart';

// Recurring template form sheet, moved verbatim from money_screen.dart.
// Exposed as RecurringFormSheet (was private _RecurringFormSheet) so the
// slim Money screen shell can open it from the recurring section.

class RecurringFormSheet extends StatefulWidget {
  final RecurringTransaction? existing;

  const RecurringFormSheet({this.existing});

  @override
  State<RecurringFormSheet> createState() => RecurringFormSheetState();
}

class RecurringFormSheetState extends State<RecurringFormSheet> {
  late FinanceKind _kind;
  late FinanceCategory _category;
  late RecurrenceFrequency _frequency;
  late int _dayOfMonth;
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  DateTime? _endDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? FinanceKind.expense;
    _category = existing?.category ?? FinanceCategory.rent;
    _frequency = existing?.frequency ?? RecurrenceFrequency.monthly;
    _dayOfMonth = existing?.dayOfMonth ?? DateTime.now().day;
    _endDate = existing?.endDate;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();
    if (title.isEmpty || amount == null || amount <= 0) return;

    final existing = widget.existing;
    final now = DateTime.now();
    Navigator.pop(
      context,
      RecurringTransaction(
        id: existing?.id ?? const Uuid().v4(),
        collectionId: existing?.collectionId ?? '',
        kind: _kind,
        category: _category,
        title: title,
        amount: amount,
        currency: existing?.currency ?? DocumentCollectionService.instance.activeCurrency,
        frequency: _frequency,
        dayOfMonth: _dayOfMonth,
        startDate: existing?.startDate ?? DateTime(now.year, now.month, 1),
        endDate: _endDate,
        isActive: existing?.isActive ?? true,
        lastLoggedAt: existing?.lastLoggedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit recurring' : 'New recurring transaction',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Finavig auto-logs this amount on the chosen day — rent, salaries, subscriptions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<FinanceKind>(
                segments: const [
                  ButtonSegment(
                    value: FinanceKind.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.call_made_rounded),
                  ),
                  ButtonSegment(
                    value: FinanceKind.income,
                    label: Text('Income'),
                    icon: Icon(Icons.call_received_rounded),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) =>
                    setState(() => _kind = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Office rent — Deira',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${DocumentCollectionService.instance.activeCurrency})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FinanceCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: FinanceCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(c.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (c) =>
                    setState(() => _category = c ?? FinanceCategory.other),
              ),
              const SizedBox(height: 12),
              SegmentedButton<RecurrenceFrequency>(
                segments: RecurrenceFrequency.values
                    .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                    .toList(),
                selected: {_frequency},
                onSelectionChanged: (selection) =>
                    setState(() => _frequency = selection.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: const InputDecoration(
                  labelText: 'Day of month',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Day ${i + 1}'),
                  ),
                ).toList(),
                onChanged: (d) => setState(() => _dayOfMonth = d ?? 1),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.event_available_rounded),
                title: const Text('End date (optional)'),
                subtitle: Text(
                  _endDate == null
                      ? 'Repeats forever'
                      : 'Until ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                ),
                trailing: _endDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _endDate ??
                        DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Save changes' : 'Create template'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Overall Budget form sheet
// ====================================================================

