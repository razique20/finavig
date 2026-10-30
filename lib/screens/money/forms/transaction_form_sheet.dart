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
  final FinanceTransaction? existing;

  const TransactionFormSheet({super.key, this.existing});

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
    final ex = widget.existing;
    if (ex != null) {
      _titleController.text = ex.title;
      _amountController.text = ex.amount % 1 == 0
          ? ex.amount.toInt().toString()
          : ex.amount.toString();
      _kind = ex.kind;
      _category = ex.category;
      if (ex.documentId != null) {
        final docs = DocumentScannerService.instance.getAllItemsSync();
        _linkedDocument = docs.where((d) => d.id == ex.documentId).firstOrNull;
      }
    }
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

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Are you sure you want to delete "${ex.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await FinanceService.instance.deleteTransaction(ex.id);
    if (!mounted) return;
    Navigator.pop(context);
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

    final ex = widget.existing;
    if (ex != null) {
      final updated = ex.copyWith(
        kind: _kind,
        category: _category,
        title: title,
        amount: amount,
        documentId: _linkedDocument?.id,
      );
      await FinanceService.instance.updateTransaction(updated);
      if (!mounted) return;
      Navigator.pop(context, updated);
      return;
    }

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
      // The amount is typed in the active collection's currency (the form
      // label says so) — stamp it, otherwise the model's 'AED' default gets
      // stored and the admin console misreads KWD/SAR rows as AED.
      currency: DocumentCollectionService.instance.activeCurrency,
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
        currency: DocumentCollectionService.instance.activeCurrency,
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
        // Scrollable so the form can never overflow when the keyboard is up
        // (mirrors the recurring-template sheet). Without this the last row
        // (the Save button) gets clipped by the keyboard.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.existing != null ? 'Edit record' : 'Add record',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Delete record',
                      onPressed: _delete,
                    ),
                ],
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
                        color: FinavigColors.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FinavigColors.cyanAccent.withValues(
                            alpha: 0.4,
                          ),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
                const SizedBox(height: 16),
              ],
              if (widget.existing == null) ...[
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
              ] else
                const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.existing != null ? 'Save Changes' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Recurring transaction card + form sheet
// ====================================================================
