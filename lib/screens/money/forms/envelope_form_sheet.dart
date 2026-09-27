import 'package:flutter/material.dart';

import '../../../models/finance.dart';
import '../../../services/collection_service.dart';

// Savings envelope form sheet, moved verbatim from money_screen.dart.

class EnvelopeFormSheet extends StatefulWidget {
  const EnvelopeFormSheet();

  @override
  State<EnvelopeFormSheet> createState() => _EnvelopeFormSheetState();
}

class _EnvelopeFormSheetState extends State<EnvelopeFormSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _monthlyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    final monthly = double.tryParse(_monthlyController.text.trim()) ?? 0;
    if (name.isEmpty || target == null || target <= 0) return;
    Navigator.pop(context, (name, target, monthly));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        // Scrollable so the form also fits small screens.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New savings envelope',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Trade licence renewal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Target amount (${DocumentCollectionService.instance.activeCurrency})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _monthlyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly contribution (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('Create envelope'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mutable spend accumulator for one week in the 6-week chart.
