import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/credit.dart';
import '../../../services/collection_service.dart';

// Form sheet for adding / editing a credit entry (money the user
// borrowed from or lent to someone). Pops with the built
// [CreditEntry]; the caller persists it via CreditService.
class CreditFormSheet extends StatefulWidget {
  final CreditEntry? existing;

  const CreditFormSheet({super.key, this.existing});

  @override
  State<CreditFormSheet> createState() => _CreditFormSheetState();
}

class _CreditFormSheetState extends State<CreditFormSheet> {
  CreditDirection _direction = CreditDirection.borrowed;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  late DateTime _deadline;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _direction = e?.direction ?? CreditDirection.borrowed;
    _nameController.text = e?.counterpartyName ?? '';
    _phoneController.text = e?.counterpartyPhone ?? '';
    _amountController.text = e == null ? '' : e.amount.toStringAsFixed(2);
    // Default new entries to a month out; edits keep their deadline.
    _deadline = e?.deadline ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _submit() {
    if (!_isValid) return;
    final e = widget.existing;
    final entry = CreditEntry(
      id: e?.id ?? const Uuid().v4(),
      collectionId:
          e?.collectionId ??
          DocumentCollectionService.instance.activeCollectionId,
      direction: _direction,
      counterpartyName: _nameController.text.trim(),
      counterpartyPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      currency:
          e?.currency ?? DocumentCollectionService.instance.activeCurrency,
      deadline: _deadline,
      extensionHistory: e?.extensionHistory ?? const [],
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

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
                isEdit ? 'Edit credit entry' : 'Add credit entry',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEdit
                    ? 'Update this obligation — the extension history is kept.'
                    : 'Track money you owe someone, or someone owes you.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CreditDirection>(
                segments: const [
                  ButtonSegment(
                    value: CreditDirection.borrowed,
                    label: Text('I borrowed'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: CreditDirection.lent,
                    label: Text('I lent'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) =>
                    setState(() => _direction = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${_direction.counterpartyRole} name',
                  hintText: _direction == CreditDirection.borrowed
                      ? 'e.g. Ahmed (lent me money)'
                      : 'e.g. Ahmed (owes me money)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: 'For WhatsApp follow-ups',
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
                  labelText:
                      'Amount (${DocumentCollectionService.instance.activeCurrency})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Deadline',
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
                          DateFormat('dd MMM yyyy').format(_deadline),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isValid ? _submit : null,
                child: Text(isEdit ? 'Save changes' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
