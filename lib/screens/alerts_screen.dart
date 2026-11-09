import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/finance.dart';
import '../services/alert_preferences_service.dart';
import '../services/anomaly_detection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/pending_transaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_detection_card.dart';

/// Active Alerts page displaying all urgent document expiries, budget threshold
/// breaches, bill spikes, and auto-detected bank transaction alerts.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

enum _AlertFilter { all, expiries, finances, banking }

enum _AlertSeverity { danger, warning, info }

class _AlertItemData {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final _AlertSeverity severity;
  final IconData icon;
  final DateTime timestamp;
  final VoidCallback onTap;
  final String badgeText;

  const _AlertItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.severity,
    required this.icon,
    required this.timestamp,
    required this.onTap,
    required this.badgeText,
  });
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _selectedFilter = _AlertFilter.all;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    DocumentScannerService.instance.addListener(_refresh);
    FinanceService.instance.addListener(_refresh);
    PendingTransactionService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_refresh);
    FinanceService.instance.removeListener(_refresh);
    PendingTransactionService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _handleRefresh() async {
    setState(() => _loading = true);
    try {
      await DocumentScannerService.instance.refresh();
      await FinanceService.instance.refresh();
      await AlertPreferencesService.instance.load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_AlertItemData> _buildAlerts() {
    final alerts = <_AlertItemData>[];
    final now = DateTime.now();

    // ── 1. Document Expiries ─────────────────────────────────────────────────
    final docs = DocumentScannerService.instance
        .getAllItemsSync()
        .where((i) => i.isActive)
        .toList();

    // A. Expired Documents (Urgent Danger)
    for (final item in docs.where((i) => i.isExpired)) {
      final days = now.difference(item.expiresAt).inDays;
      alerts.add(
        _AlertItemData(
          id: 'doc-expired-${item.id}',
          title: item.displayName,
          subtitle:
              'Expired ${days <= 0 ? "today" : "$days day${days == 1 ? "" : "s"} ago"} — renewal required',
          category: 'Expiries',
          severity: _AlertSeverity.danger,
          icon: Icons.error_outline_rounded,
          timestamp: item.expiresAt,
          badgeText: 'EXPIRED',
          onTap: () => context.push('/document/${item.id}'),
        ),
      );
    }

    // B. Expiring within 7 days (Critical Danger)
    for (final item in docs.where((i) => !i.isExpired && i.daysRemaining <= 7)) {
      alerts.add(
        _AlertItemData(
          id: 'doc-crit-${item.id}',
          title: item.displayName,
          subtitle:
              'Expires in ${item.daysRemaining} day${item.daysRemaining == 1 ? "" : "s"} (${DateFormat.MMMd().format(item.expiresAt)})',
          category: 'Expiries',
          severity: _AlertSeverity.danger,
          icon: Icons.alarm_rounded,
          timestamp: item.expiresAt,
          badgeText: '${item.daysRemaining}d LEFT',
          onTap: () => context.push('/document/${item.id}'),
        ),
      );
    }

    // C. Expiring within 30 days (Upcoming Warning)
    for (final item in docs.where(
      (i) => !i.isExpired && i.daysRemaining > 7 && i.daysRemaining <= 30,
    )) {
      alerts.add(
        _AlertItemData(
          id: 'doc-warn-${item.id}',
          title: item.displayName,
          subtitle: 'Expires in ${item.daysRemaining} days — renewal window open',
          category: 'Expiries',
          severity: _AlertSeverity.warning,
          icon: Icons.hourglass_top_rounded,
          timestamp: item.expiresAt,
          badgeText: '${item.daysRemaining}d LEFT',
          onTap: () => context.push('/document/${item.id}'),
        ),
      );
    }

    // ── 2. Budgets & Spending ────────────────────────────────────────────────
    if (AlertPreferencesService.instance.budgetAlertsEnabled) {
      final budgets = FinanceService.instance.activeBudgets;
      if (budgets.isNotEmpty) {
        final spend = FinanceMath.spendByCategory(
          FinanceService.instance.activeTransactions,
          now,
          collectionId: FinanceService.instance.activeCollectionIdSafe,
        );
        final statuses = FinanceMath.budgetStatuses(budgets, spend);
        for (final s in statuses) {
          if (s.status == BudgetAlertLevel.none) continue;
          final pct = (s.ratio * 100).toStringAsFixed(0);
          final exceeded = s.status == BudgetAlertLevel.exceeded;
          alerts.add(
            _AlertItemData(
              id: 'budget-${s.budget.id}',
              title:
                  '${s.budget.category.displayName} Budget ${exceeded ? "Exceeded" : "Alert"}',
              subtitle:
                  '$pct% of monthly limit used (${s.spent.toStringAsFixed(0)} / ${s.budget.monthlyLimit.toStringAsFixed(0)})',
              category: 'Finances',
              severity: exceeded
                  ? _AlertSeverity.danger
                  : _AlertSeverity.warning,
              icon: Icons.account_balance_wallet_rounded,
              timestamp: now,
              badgeText: exceeded ? 'LIMIT EXCEEDED' : '$pct% USED',
              onTap: () => context.push('/budgets'),
            ),
          );
        }
      }
    }

    // ── 3. Bill Spikes & Anomalies ───────────────────────────────────────────
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      final anomalies = AnomalyDetectionService.instance.detectRecentAnomalies(
        FinanceService.instance.activeTransactions,
      );
      for (final a in anomalies) {
        alerts.add(
          _AlertItemData(
            id: 'spike-${a.transaction.id}',
            title: 'Bill Spike: ${a.transaction.title}',
            subtitle: a.message,
            category: 'Finances',
            severity: _AlertSeverity.warning,
            icon: Icons.trending_up_rounded,
            timestamp: a.transaction.occurredAt,
            badgeText: 'UNUSUAL SPEND',
            onTap: () => context.push('/records'),
          ),
        );
      }
    }

    // ── 4. Pending Bank Detection Queue ──────────────────────────────────────
    final pendingTx = PendingTransactionService.instance.pending;
    if (pendingTx.isNotEmpty) {
      alerts.add(
        _AlertItemData(
          id: 'pending-bank-tx',
          title: 'Bank Notifications Detected',
          subtitle:
              '${pendingTx.length} new transaction alert${pendingTx.length == 1 ? "" : "s"} ready for review',
          category: 'Banking',
          severity: _AlertSeverity.info,
          icon: Icons.mark_email_unread_rounded,
          timestamp: now,
          badgeText: '${pendingTx.length} PENDING',
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const PendingTransactionsList(),
            );
          },
        ),
      );
    }

    // Filter by selected tab
    switch (_selectedFilter) {
      case _AlertFilter.all:
        return alerts;
      case _AlertFilter.expiries:
        return alerts.where((a) => a.category == 'Expiries').toList();
      case _AlertFilter.finances:
        return alerts.where((a) => a.category == 'Finances').toList();
      case _AlertFilter.banking:
        return alerts.where((a) => a.category == 'Banking').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);

    final allAlerts = _buildAlerts();
    final dangerCount = allAlerts
        .where((a) => a.severity == _AlertSeverity.danger)
        .length;

    final bg = fade.color(const Color(0xFFF6F7FA), FinavigColors.obsidian);
    final cardBg = fade.color(Colors.white, FinavigColors.charcoal);
    final cardBorder = fade.color(
      const Color(0xFFE5E7EB),
      Colors.white.withValues(alpha: 0.08),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text(
              'Alerts',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if (allAlerts.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dangerCount > 0
                      ? FinavigColors.danger.withValues(alpha: 0.15)
                      : FinavigColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${allAlerts.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: dangerCount > 0
                        ? FinavigColors.danger
                        : FinavigColors.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Alert & Reminder Settings',
            onPressed: () => context.push('/alerts-reminders'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: FinavigColors.accent,
        child: Column(
          children: [
            // ── Category Filter Pills ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      isSelected: _selectedFilter == _AlertFilter.all,
                      onTap: () => setState(() => _selectedFilter = _AlertFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Expiries',
                      isSelected: _selectedFilter == _AlertFilter.expiries,
                      onTap: () => setState(() => _selectedFilter = _AlertFilter.expiries),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Budgets & Bills',
                      isSelected: _selectedFilter == _AlertFilter.finances,
                      onTap: () => setState(() => _selectedFilter = _AlertFilter.finances),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Banking Alerts',
                      isSelected: _selectedFilter == _AlertFilter.banking,
                      onTap: () => setState(() => _selectedFilter = _AlertFilter.banking),
                    ),
                  ],
                ),
              ),
            ),

            // ── Alert List or Empty State ────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : allAlerts.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: allAlerts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final alert = allAlerts[index];
                            return _AlertCard(
                              alert: alert,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      // ── Settings Quick Bar at Bottom ───────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(
            top: BorderSide(color: cardBorder),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Manage notification lead times & toggles',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/alerts-reminders'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final fade = FinavigTransition.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FinavigColors.safe.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FinavigColors.safe.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 42,
                color: FinavigColors.safe,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  FinavigColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No pending renewal deadlines, expired items, or budget alerts at this moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: fade.color(
                  FinavigColors.textSecondaryLight,
                  FinavigColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.push('/alerts-reminders'),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Configure Alert Settings'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? FinavigColors.accent
              : fade.color(
                  Colors.black.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.06),
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AlertItemData alert;
  final Color cardBg;
  final Color cardBorder;

  const _AlertCard({
    required this.alert,
    required this.cardBg,
    required this.cardBorder,
  });

  Color _severityColor() {
    switch (alert.severity) {
      case _AlertSeverity.danger:
        return FinavigColors.danger;
      case _AlertSeverity.warning:
        return FinavigColors.warning;
      case _AlertSeverity.info:
        return FinavigColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final color = _severityColor();

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      elevation: 0,
      child: InkWell(
        onTap: alert.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(alert.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: fade.color(
                                FinavigColors.textPrimaryLight,
                                FinavigColors.textPrimary,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            alert.badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: fade.color(
                          FinavigColors.textSecondaryLight,
                          FinavigColors.textSecondary,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
