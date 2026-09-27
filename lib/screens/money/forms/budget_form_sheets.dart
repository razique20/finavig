import 'package:flutter/material.dart';

import '../../../models/finance.dart';
import '../../../services/collection_service.dart';

// Overall + category budget form sheets, moved verbatim from
// money_screen.dart.

class OverallBudgetFormSheet extends StatefulWidget {
  final double? currentLimit;

  const OverallBudgetFormSheet({this.currentLimit});

  @override
  State<OverallBudgetFormSheet> createState() =>
      _OverallBudgetFormSheetState();
}

class _OverallBudgetFormSheetState
    extends State<OverallBudgetFormSheet> {
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.currentLimit != null
          ? widget.currentLimit!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    final val = double.tryParse(_limitController.text.trim());
    if (val == null || val <= 0) return;
    Navigator.pop(context, val);
  }

  void _clear() {
    Navigator.pop(context, -1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.currentLimit == null
                  ? 'Set overall monthly budget'
                  : 'Edit overall monthly budget',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set the overall monthly limit across all spending categories. Individual category budgets will be constrained within this amount.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limitController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Total Monthly Budget (${DocumentCollectionService.instance.activeCurrency})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save overall budget'),
            ),
            if (widget.currentLimit != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clear,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Remove overall budget cap'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Budget form sheet
// ====================================================================

class CategoryBudgetFormSheet extends StatefulWidget {
  final CategoryBudget? existing;
  final double? maxAllowedLimit;

  const CategoryBudgetFormSheet({this.existing, this.maxAllowedLimit});

  @override
  State<CategoryBudgetFormSheet> createState() =>
      _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<CategoryBudgetFormSheet> {
  late FinanceCategory _category;
  late final TextEditingController _limitController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category ?? FinanceCategory.other;
    _limitController = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.monthlyLimit.toStringAsFixed(0),
    );
    _limitController.addListener(_validate);
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _limitController.text.trim();
    if (text.isEmpty) {
      if (_errorText != null) setState(() => _errorText = null);
      return;
    }
    final val = double.tryParse(text);
    if (val == null || val <= 0) {
      if (_errorText != 'Enter a valid amount') {
        setState(() => _errorText = 'Enter a valid amount');
      }
      return;
    }

    if (widget.maxAllowedLimit != null &&
        val > widget.maxAllowedLimit! + 0.01) {
      final maxStr = MoneyFormat.aed(
        widget.maxAllowedLimit! < 0 ? 0 : widget.maxAllowedLimit!,
      );
      final msg = widget.maxAllowedLimit! <= 0
          ? 'Overall monthly budget is fully allocated'
          : 'Exceeds remaining monthly budget ($maxStr)';
      if (_errorText != msg) {
        setState(() => _errorText = msg);
      }
    } else {
      if (_errorText != null) setState(() => _errorText = null);
    }
  }

  void _submit() {
    _validate();
    if (_errorText != null) return;
    final limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) return;
    if (widget.maxAllowedLimit != null &&
        limit > widget.maxAllowedLimit! + 0.01)
      return;
    Navigator.pop(context, (_category, limit));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxLimit = widget.maxAllowedLimit;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add budget' : 'Edit budget',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (maxLimit != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: maxLimit <= 0
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      maxLimit <= 0
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: maxLimit <= 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maxLimit <= 0
                            ? 'Overall monthly budget is 100% allocated.'
                            : 'Available from overall monthly budget: ${MoneyFormat.aed(maxLimit)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: maxLimit <= 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monthly limit (${DocumentCollectionService.instance.activeCurrency})',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _errorText != null ? null : _submit,
              child: const Text('Save budget'),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Envelope form sheet
// ====================================================================

