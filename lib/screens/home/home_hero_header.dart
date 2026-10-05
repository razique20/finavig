import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/expiry_item.dart';
import '../../models/finance.dart';
import '../../models/document_collection.dart';
import '../../services/alert_preferences_service.dart';
import '../../services/anomaly_detection_service.dart';
import '../../services/collection_service.dart';
import '../../services/finance_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Navy gradient hero of the Home tab: greeting + collection switcher,
/// dark-mode quick toggle, notification bell, then the month balance and
/// action pills.
class HomeHeroHeader extends StatelessWidget {
  final DocumentCollection? activeCollection;
  final List<ExpiryItem> items;

  /// The "renewals need attention" count the user dismissed this session —
  /// excluded from the bell badge so it matches the banner.
  final int? dismissedAttentionCount;
  final VoidCallback onCollectionSwitcherTap;
  final VoidCallback onQuickAddRecord;

  const HomeHeroHeader({
    super.key,
    required this.activeCollection,
    required this.items,
    required this.dismissedAttentionCount,
    required this.onCollectionSwitcherTap,
    required this.onQuickAddRecord,
  });

  /// "12 Mar" of the nearest upcoming renewal, or null when none tracked.
  String? _nextRenewalLabel() {
    final now = DateTime.now();
    ExpiryItem? next;
    for (final item in items) {
      if (!item.isActive || item.expiresAt.isBefore(now)) continue;
      if (next == null || item.expiresAt.isBefore(next.expiresAt)) {
        next = item;
      }
    }
    if (next == null) return null;
    return '${next.expiresAt.day} ${_monthAbbrev(next.expiresAt.month)}';
  }

  static String _monthAbbrev(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(
      FinanceService.instance.activeTransactions,
      now,
    );
    final nextRenewal = _nextRenewalLabel();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Left: collection avatar + switcher.
              InkWell(
                onTap: onCollectionSwitcherTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          activeCollection?.icon ?? Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                activeCollection?.name ?? 'Personal',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 16,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Dark mode toggle.
              HeroIconButton(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                onTap: () async {
                  final mode = ThemeService.instance.mode;
                  await ThemeService.instance.setMode(
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
              const SizedBox(width: 8),
              HomeNotificationBell(
                items: items,
                dismissedAttentionCount: dismissedAttentionCount,
              ),
            ],
          ),
          const SizedBox(height: 22),
          // Balance block.
          Text(
            'Net this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Flexible: inside a Row the FittedBox would otherwise get
              // unbounded width and never scale down — long balances
              // overflowed the hero on narrow screens.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    MoneyFormat.aed(summary.net),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              if (summary.income > 0 || summary.expense > 0) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DocumentCollectionService.instance.activeCurrency,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyFormat.aed(summary.income)} in · ${MoneyFormat.aed(summary.expense)} out'
            '${nextRenewal == null ? '' : ' · next: $nextRenewal'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // Action pills.
          Row(
            children: [
              HeroActionPill(
                icon: Icons.south_west_rounded,
                label: 'Record',
                outlined: true,
                onTap: onQuickAddRecord,
              ),
              const SizedBox(width: 10),
              HeroActionPill(
                icon: Icons.north_east_rounded,
                label: 'Budget',
                filled: true,
                onTap: () => context.push('/budgets'),
              ),
              const SizedBox(width: 10),
              HeroActionPill(
                icon: Icons.more_horiz_rounded,
                label: '',
                outlined: true,
                tooltip: 'Switch collection',
                onTap: onCollectionSwitcherTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Notification bell with live alert count (expired documents, upcoming
/// renewals, bill spikes, budget alerts). Opens the alert list sheet on tap.
class HomeNotificationBell extends StatelessWidget {
  final List<ExpiryItem> items;

  /// The "renewals need attention" count the user dismissed this session —
  /// excluded from the badge so the bell matches the banner.
  final int? dismissedAttentionCount;

  const HomeNotificationBell({
    super.key,
    required this.items,
    required this.dismissedAttentionCount,
  });

  int get _count {
    final expired = items.where((i) => i.isActive && i.isExpired).length;
    final pending = items
        .where(
          (i) =>
              i.isActive &&
              !i.isExpired &&
              i.daysRemaining <= 30 &&
              i.daysRemaining != dismissedAttentionCount,
        )
        .length;
    var spikes = 0;
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      spikes = AnomalyDetectionService.instance
          .detectRecentAnomalies(FinanceService.instance.activeTransactions)
          .length;
    }
    return expired + pending + spikes;
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: 'Alerts & notifications',
          child: Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _showNotificationsSheet(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: FinavigColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: FinavigColors.ink, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Bottom sheet listing every current notification: documents needing
  /// attention (upcoming + expired), bill spikes, and budget alerts.
  void _showNotificationsSheet(BuildContext context) {
    final now = DateTime.now();
    final rows = <Widget>[];

    // --- Upcoming renewals (within 30 days) ---
    final pending = items
        .where((i) => i.isActive && !i.isExpired && i.daysRemaining <= 30)
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    for (final item in pending) {
      rows.add(
        _NotificationRow(
          icon: Icons.hourglass_top_rounded,
          color: item.daysRemaining <= 7
              ? FinavigColors.danger
              : FinavigColors.warning,
          title: item.displayName,
          subtitle:
              'Expires in ${item.daysRemaining} day${item.daysRemaining == 1 ? '' : 's'} — renew soon',
          onTap: () => context.go('/documents'),
        ),
      );
    }

    // --- Expired documents ---
    for (final item in items.where((i) => i.isActive && i.isExpired)) {
      final days = now.difference(item.expiresAt).inDays;
      rows.add(
        _NotificationRow(
          icon: Icons.error_outline_rounded,
          color: FinavigColors.danger,
          title: item.displayName,
          subtitle:
              'Expired ${days <= 0 ? 'today' : '$days day${days == 1 ? '' : 's'} ago'} — act now',
          onTap: () => context.go('/documents'),
        ),
      );
    }

    // --- Bill spikes ---
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      for (final anomaly
          in AnomalyDetectionService.instance.detectRecentAnomalies(
        FinanceService.instance.activeTransactions,
      )) {
        rows.add(
          _NotificationRow(
            icon: Icons.trending_up_rounded,
            color: FinavigColors.warning,
            title: 'Bill spike: ${anomaly.transaction.title}',
            subtitle: anomaly.message,
            onTap: () => context.go('/money'),
          ),
        );
      }
    }

    // --- Budget alerts ---
    if (AlertPreferencesService.instance.budgetAlertsEnabled) {
      final budgets = FinanceService.instance.activeBudgets;
      if (budgets.isNotEmpty) {
        final spend = FinanceMath.spendByCategory(
          FinanceService.instance.activeTransactions,
          DateTime.now(),
          collectionId: FinanceService.instance.activeCollectionIdSafe,
        );
        final statuses = FinanceMath.budgetStatuses(budgets, spend);
        for (final s in statuses) {
          if (s.status == BudgetAlertLevel.none) continue;
          final pct = (s.ratio * 100).toStringAsFixed(0);
          final exceeded = s.status == BudgetAlertLevel.exceeded;
          rows.add(
            _NotificationRow(
              icon: Icons.account_balance_wallet_rounded,
              color: exceeded ? FinavigColors.danger : FinavigColors.warning,
              title:
                  '${exceeded ? "Budget exceeded" : "Close to budget"} — ${s.budget.category.displayName}',
              subtitle: '$pct% of the monthly budget used this month.',
              onTap: () => context.go('/money'),
            ),
          );
        }
      }
    }

    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 40,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You are all caught up',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No alerts right now.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  // Lazy builder over the prebuilt alert rows: the sheet's
                  // height is bounded, so only the visible rows lay out.
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rows.length,
                    itemBuilder: (_, index) => rows[index],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable row inside the notifications sheet.
class _NotificationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
