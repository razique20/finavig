import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/credit.dart';
import '../../../models/finance.dart';
import '../../../services/finance_service.dart';

/// What the settle sheet hands back to its caller.
///
/// The sheet only *builds* the mirrored Money transaction — the caller
/// persists it through `CreditService.settleCredit`, which is what keeps
/// the credit and the ledger in step.
class CreditSettlement {
  final DateTime settledAt;

  /// A newly created repayment leg, when the user chose to log it.
  final FinanceTransaction? newTransaction;

  /// The id of a transaction the user had already logged and pinned here.
  final String? linkedTransactionId;

  /// The id of an already-logged *principal* leg the user reconciled here,
  /// when the loan was entered into Money by hand. Tagging it stops the
  /// amount reading as real income/spending.
  final String? linkedDisbursementId;

  const CreditSettlement({
    required this.settledAt,
    this.newTransaction,
    this.linkedTransactionId,
    this.linkedDisbursementId,
  });

  /// True when the settlement also writes/links something into Money.
  bool get logsInMoney =>
      newTransaction != null ||
      linkedTransactionId != null ||
      linkedDisbursementId != null;
}

/// How the repayment should appear in Money.
enum _MoneyOption { create, attach, skip }

/// Sheet for closing a credit obligation: "Mark settled" (borrowed) or
/// "Money received back" (lent).
///
/// Every step is optional — the user can settle the credit alone, create
/// the matching Money record, or attach one they already logged.
class CreditSettleSheet extends StatefulWidget {
  final CreditEntry entry;

  const CreditSettleSheet({super.key, required this.entry});

  @override
  State<CreditSettleSheet> createState() => _CreditSettleSheetState();
}

class _CreditSettleSheetState extends State<CreditSettleSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  late DateTime _settledAt;
  FinanceCategory _category = FinanceCategory.other;
  _MoneyOption _moneyOption = _MoneyOption.create;
  String? _attachedId;

  /// An already-logged principal leg the user chose to reconcile, if any.
  /// Null means the principal is left as-is (or was never logged).
  String? _principalId;

  /// The direction of the mirrored repayment leg: repaying what we owed is
  /// an expense; money coming back to us is income.
  FinanceKind get _repaymentKind =>
      widget.entry.direction == CreditDirection.borrowed
          ? FinanceKind.expense
          : FinanceKind.income;

  /// The direction of the *original* movement: borrowing brought money in,
  /// lending sent it out.
  FinanceKind get _principalKind =>
      widget.entry.direction == CreditDirection.borrowed
          ? FinanceKind.income
          : FinanceKind.expense;

  /// Already-logged transactions that could be this repayment.
  List<FinanceTransaction> get _candidates {
    final kind = _repaymentKind;
    return FinanceService.instance.activeTransactions
        .where((t) => t.kind == kind && !t.isCreditLinked)
        .toList();
  }

  /// Hand-logged transactions that could be the loan's principal. Empty when
  /// the principal is already linked (origin sync did it) so the section
  /// stays out of the way.
  List<FinanceTransaction> get _principalCandidates {
    if (widget.entry.disbursementTransactionId != null) return const [];
    final kind = _principalKind;
    return FinanceService.instance.activeTransactions
        .where((t) => t.kind == kind && !t.isCreditLinked)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _amountController.text = e.amount.toStringAsFixed(2);
    _titleController.text = e.direction == CreditDirection.borrowed
        ? 'Repaid ${e.counterpartyName}'
        : '${e.counterpartyName} repaid me';
    _settledAt = DateTime.now();

    // Preselect the principal when exactly one hand-logged record matches the
    // credit's amount — a strong signal it is this loan, and the user still
    // sees (and can clear) the selection before saving.
    final matches = _principalCandidates
        .where((t) => (t.amount - e.amount).abs() < 0.005)
        .toList();
    if (matches.length == 1) _principalId = matches.single.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _isValid {
    switch (_moneyOption) {
      case _MoneyOption.create:
        return (double.tryParse(_amountController.text.trim()) ?? 0) > 0 &&
            _titleController.text.trim().isNotEmpty;
      case _MoneyOption.attach:
        return _attachedId != null;
      case _MoneyOption.skip:
        return true;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _settledAt,
      firstDate: widget.entry.startDate.subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _settledAt = picked);
  }

  void _submit() {
    if (!_isValid) return;

    FinanceTransaction? created;
    String? linkedId;

    switch (_moneyOption) {
      case _MoneyOption.create:
        created = FinanceTransaction(
          id: const Uuid().v4(),
          collectionId: widget.entry.collectionId,
          kind: _repaymentKind,
          category: _category,
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          currency: widget.entry.currency,
          occurredAt: _settledAt,
          creditId: widget.entry.id,
          creditLeg: CreditLeg.settlement,
        );
      case _MoneyOption.attach:
        linkedId = _attachedId;
      case _MoneyOption.skip:
        break;
    }

    Navigator.pop(
      context,
      CreditSettlement(
        settledAt: _settledAt,
        newTransaction: created,
        linkedTransactionId: linkedId,
        linkedDisbursementId: _principalId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    final borrowed = e.direction == CreditDirection.borrowed;

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
                borrowed ? 'Mark as repaid' : 'Money received back',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Closing this obligation removes it from your outstanding '
                'credit totals. Deadline history is kept.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: borrowed ? 'Date repaid' : 'Date received',
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
                          DateFormat('dd MMM yyyy').format(_settledAt),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_principalCandidates.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  borrowed ? 'Money you received' : 'Money you paid out',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  borrowed
                      ? 'The loan amount you logged in Money when you '
                          'borrowed. Linking it keeps it out of your income.'
                      : 'The amount you logged in Money when you lent it. '
                          'Linking it keeps it out of your spending.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 10),
                for (final t in _principalCandidates.take(8)) ...[
                  _OptionTile(
                    selected: _principalId == t.id,
                    title: t.title,
                    subtitle:
                        '${MoneyFormat.format(t.amount, symbol: '${t.currency} ')}'
                        ' · ${DateFormat('dd MMM').format(t.occurredAt)}',
                    onTap: () => setState(
                      () => _principalId = _principalId == t.id ? null : t.id,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 18),
              Text(
                'Record in Money',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                borrowed
                    ? 'This was money leaving your account — logged as an '
                        'expense.'
                    : 'This was money arriving — logged as income.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 10),
              _OptionTile(
                selected: _moneyOption == _MoneyOption.create,
                title: 'Create a new record',
                subtitle: borrowed
                    ? 'Expense · Repaid ${e.counterpartyName}'
                    : 'Income · ${e.counterpartyName} repaid me',
                onTap: () => setState(() => _moneyOption = _MoneyOption.create),
              ),
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                _OptionTile(
                  selected: _moneyOption == _MoneyOption.attach,
                  title: 'Attach one I already logged',
                  subtitle: '${_candidates.length} matching '
                      '${_candidates.length == 1 ? 'record' : 'records'}',
                  onTap: () => setState(() {
                    _moneyOption = _MoneyOption.attach;
                    _attachedId ??= _candidates.first.id;
                  }),
                ),
              ],
              const SizedBox(height: 8),
              _OptionTile(
                selected: _moneyOption == _MoneyOption.skip,
                title: 'Only settle the credit',
                subtitle: 'Nothing is written to Money',
                onTap: () => setState(() => _moneyOption = _MoneyOption.skip),
              ),
              if (_moneyOption == _MoneyOption.create) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount (${e.currency})',
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
                  items: [
                    for (final c in FinanceCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.displayName)),
                  ],
                  onChanged: (v) =>
                      setState(() => _category = v ?? FinanceCategory.other),
                ),
              ],
              if (_moneyOption == _MoneyOption.attach) ...[
                const SizedBox(height: 10),
                for (final t in _candidates.take(8)) ...[
                  _OptionTile(
                    selected: _attachedId == t.id,
                    title: t.title,
                    subtitle:
                        '${MoneyFormat.format(t.amount, symbol: '${t.currency} ')}'
                        ' · ${DateFormat('dd MMM').format(t.occurredAt)}',
                    onTap: () => setState(() => _attachedId = t.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isValid ? _submit : null,
                child: Text(borrowed ? 'Mark as repaid' : 'Mark as received'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single selectable row in the settle sheet (radio without the
/// deprecated `RadioListTile.groupValue` API).
class _OptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
