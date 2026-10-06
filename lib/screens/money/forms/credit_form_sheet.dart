import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/credit.dart';
import '../../../models/finance.dart';
import '../../../services/collection_service.dart';

/// What the credit form hands back: the built [CreditEntry] plus, when the
/// user opted in, the Money transaction mirroring the principal. The sheet
/// only builds the leg — the caller persists both via
/// `CreditService.addCreditWithDisbursement`.
class CreditFormResult {
  final CreditEntry entry;
  final FinanceTransaction? disbursement;

  const CreditFormResult({required this.entry, this.disbursement});
}

// Form sheet for adding / editing a credit entry (money the user
// borrowed from or lent to someone). Pops with a [CreditFormResult];
// the caller persists it via CreditService.
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
  final _descriptionController = TextEditingController();
  late DateTime _startDate;
  late DateTime _deadline;

  /// Opt-in: mirror the principal into Money as income (borrowed) or
  /// expense (lent). Default off — a loan isn't earnings or spending.
  bool _logInMoney = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _direction = e?.direction ?? CreditDirection.borrowed;
    _nameController.text = e?.counterpartyName ?? '';
    _phoneController.text = e?.counterpartyPhone ?? '';
    _amountController.text = e == null ? '' : e.amount.toStringAsFixed(2);
    _descriptionController.text = e?.description ?? '';
    // New entries default the borrow/lend date to today and the
    // deadline to a month out; edits keep their existing dates.
    _startDate = e?.startDate ?? DateTime.now();
    _deadline = e?.deadline ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
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
      startDate: _startDate,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      extensionHistory: e?.extensionHistory ?? const [],
      createdAt: e?.createdAt ?? DateTime.now(),
    );

    // Origin sync is opt-in and new-entry only: editing an obligation must
    // not retroactively create a second cash movement.
    FinanceTransaction? disbursement;
    if (e == null && _logInMoney) {
      disbursement = FinanceTransaction(
        id: const Uuid().v4(),
        collectionId: entry.collectionId,
        kind: _direction == CreditDirection.borrowed
            ? FinanceKind.income
            : FinanceKind.expense,
        category: FinanceCategory.other,
        title: _direction == CreditDirection.borrowed
            ? 'Borrowed from ${entry.counterpartyName}'
            : 'Lent to ${entry.counterpartyName}',
        amount: entry.amount,
        currency: entry.currency,
        occurredAt: _startDate,
        creditId: entry.id,
        creditLeg: CreditLeg.disbursement,
      );
    }

    Navigator.pop(
      context,
      CreditFormResult(entry: entry, disbursement: disbursement),
    );
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
                // Rebuild so the Save button enables as soon as the form is
                // valid (validity is derived in build()).
                onChanged: (_) => setState(() {}),
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      'Amount (${DocumentCollectionService.instance.activeCurrency})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: _direction == CreditDirection.borrowed
                      ? 'e.g. Borrowed for car repair'
                      : 'e.g. Lent for a deposit',
                  counterText: '',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _pickStartDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _direction.startDateFieldLabel,
                    helperText: _direction == CreditDirection.borrowed
                        ? 'When you received the money'
                        : 'When you handed over the money',
                    border: const OutlineInputBorder(),
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
                          DateFormat('dd MMM yyyy').format(_startDate),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
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
              if (!isEdit)
                CheckboxListTile(
                  value: _logInMoney,
                  onChanged: (v) =>
                      setState(() => _logInMoney = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also record this in Money'),
                  subtitle: Text(
                    _direction == CreditDirection.borrowed
                        ? 'Logged as income — cash you received'
                        : 'Logged as expense — cash you paid out',
                  ),
                ),
              const SizedBox(height: 16),
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
