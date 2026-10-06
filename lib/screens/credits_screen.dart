import 'package:flutter/material.dart';

import '../models/credit.dart';
import '../services/credit_service.dart';
import '../theme/app_theme.dart';
import 'money/credit_section.dart';
import 'money/forms/credit_extend_sheet.dart';
import 'money/forms/credit_form_sheet.dart';

/// Credit obligations page opened from the Money tab: money
/// borrowed from — or lent to — someone, with deadline
/// tracking, preserved extension history and WhatsApp
/// follow-ups, without the rest of the Money tab.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<CreditEntry> _credits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    CreditService.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    CreditService.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    await CreditService.instance.init();
    if (!mounted) return;
    setState(() {
      _credits = CreditService.instance.activeCredits;
      _loading = false;
    });
  }

  Future<void> _showCreditSheet({CreditEntry? existing}) async {
    final result = await showModalBottomSheet<CreditEntry>(
      context: context,
      // Scrollable + keyboard-aware sheet (matches the Money tab's
      // call site), so the form lifts above the keyboard.
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreditFormSheet(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await CreditService.instance.addCredit(result);
    } else {
      await CreditService.instance.updateCredit(result);
    }
  }

  Future<void> _showExtendSheet(CreditEntry entry) async {
    final newDeadline = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreditExtendSheet(entry: entry),
    );
    if (newDeadline == null) return;
    await CreditService.instance.extendDeadline(entry.id, newDeadline);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Credit')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'credits_add',
        onPressed: () => _showCreditSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: FinavigColors.ink,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverToBoxAdapter(
                      child: CreditSection(
                        credits: _credits,
                        onAdd: () => _showCreditSheet(),
                        onEdit: (c) => _showCreditSheet(existing: c),
                        onDelete: (c) =>
                            CreditService.instance.deleteCredit(c.id),
                        onExtend: _showExtendSheet,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
