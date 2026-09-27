import 'package:flutter/material.dart';

import '../../../models/expiry_item.dart';
import '../../../models/finance.dart';
import '../../../services/collection_service.dart';
import '../../../services/document_scanner_service.dart';
import '../../../theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../../../services/finance_service.dart';
import '../../../services/smart_category_engine.dart';

// Form sheet for logging a transaction, moved verbatim from
// money_screen.dart (it was getting too heavy). Public API unchanged.

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet();

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  FinanceKind _kind = FinanceKind.expense;
  FinanceCategory _category = FinanceCategory.other;
  bool _repeatMonthly = false;
  ExpiryItem? _linkedDocument;
  CategoryPrediction? _aiPrediction;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  /// Active, non-expired documents offered as the payment's linked document.
  List<ExpiryItem> _activeDocuments() =>
      DocumentScannerService.instance
          .getAllItemsSync()
          .where((i) => i.isActive && !i.isExpired)
          .toList()
        ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    final text = _titleController.text.trim();
    if (text.isEmpty) {
      setState(() => _aiPrediction = null);
    } else {
      final pred = SmartCategoryEngine.instance.predict(text, kind: _kind);
      setState(() {
        _aiPrediction = pred;
        if (pred.isHighConfidence && _category == FinanceCategory.other) {
          _category = pred.category;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();
    if (title.isEmpty || amount == null || amount <= 0) return;

    final now = DateTime.now();
    final activeCollectionId =
        DocumentCollectionService.instance.activeCollectionId;
    final transaction = FinanceTransaction(
      id: const Uuid().v4(),
      collectionId: activeCollectionId,
      kind: _kind,
      category: _category,
      title: title,
      amount: amount,
      occurredAt: now,
      documentId: _linkedDocument?.id,
    );

    if (_repeatMonthly) {
      // Also create a monthly template so future periods log themselves.
      final template = RecurringTransaction(
        id: const Uuid().v4(),
        collectionId: '', // scoped to the active collection on add
        kind: _kind,
        category: _category,
        title: title,
        amount: amount,
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: now.day,
        startDate: DateTime(now.year, now.month, 1),
      );
      FinanceService.instance.addRecurring(template);
    }

    // Soft duplicate guard: same title + amount + day already logged in this
    // collection → ask before saving. "Save anyway" keeps the record (a
    // second same-day payment of the same amount is legitimate).
    final duplicate = FinanceMath.findDuplicateTransaction(
      FinanceService.instance.activeTransactions,
      transaction,
    );
    if (duplicate != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.copy_all_rounded),
          title: const Text('Possible duplicate'),
          content: Text(
            '"${duplicate.title}" for ${MoneyFormat.aed(duplicate.amount)} '
            'is already logged for ${duplicate.occurredAt.day}/${duplicate.occurredAt.month}. '
            'Save this record anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;
    Navigator.pop(context, transaction);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add record',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
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
                hintText: 'e.g. Trade licence renewal',
                border: OutlineInputBorder(),
              ),
            ),
            if (_aiPrediction != null && _aiPrediction!.isHighConfidence) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () =>
                      setState(() => _category = _aiPrediction!.category),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FinavigColors.cyanAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FinavigColors.cyanAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: FinavigColors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Suggested: ${_aiPrediction!.category.displayName} (${(_aiPrediction!.confidence * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: FinavigColors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            if (_kind == FinanceKind.expense) ...[
              DropdownButtonFormField<ExpiryItem?>(
                initialValue: _linkedDocument,
                decoration: const InputDecoration(
                  labelText: 'Linked document (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._activeDocuments().map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(
                        d.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (d) => setState(() => _linkedDocument = d),
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _repeatMonthly,
              onChanged: (v) => setState(() => _repeatMonthly = v),
              title: const Text('Repeat monthly'),
              subtitle: Text(
                'Also create a monthly template — auto-logs this amount every month from now on.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Recurring transaction card + form sheet
// ====================================================================

