import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/finance.dart';
import '../../models/expiry_item.dart';
import '../../models/subscription_tier.dart';
import '../../services/alert_preferences_service.dart';
import '../../services/anomaly_detection_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';
import 'money_sections.dart';

/// Bill-spike anomaly card. Dismissed ids are passed in so the widget stays
/// stateless; the parent owns dismissal state.
class BillSpikeAlertsCard extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final Set<String> dismissedIds;
  final void Function(Set<String> ids) onDismiss;

  const BillSpikeAlertsCard({
    super.key,
    required this.transactions,
    required this.dismissedIds,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Master switch: user turned bill spike alerts off in Profile.
    if (!AlertPreferencesService.instance.billSpikesEnabled) {
      return const SizedBox.shrink();
    }

    final anomalies = AnomalyDetectionService.instance
        .detectRecentAnomalies(transactions, recentDays: 30)
        .where((a) => !dismissedIds.contains(a.transaction.id))
        .toList();
    if (anomalies.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.card),
      ),
      color: isDark ? const Color(0xFF2A2110) : FinavigColors.amberTint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FinavigColors.warning.withOpacity(
                      isDark ? 0.2 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: FinavigColors.warning,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bill Spike Alert${anomalies.length > 1 ? "s" : ""}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.amberAccent
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FinavigColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${anomalies.length} Spike${anomalies.length > 1 ? "s" : ""}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: FinavigColors.warning,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'Dismiss alert',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onDismiss(
                      anomalies.map((a) => a.transaction.id).toSet(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < anomalies.length; i++) ...[
              if (i > 0) const Divider(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anomalies[i].transaction.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          anomalies[i].message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      anomalies[i].severity.badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cash-flow forecast card (Track 1 gated). A plain tap-through
/// strip — the forecast has its own page, so the card carries no
/// detail of its own: tapping it opens the forecast, or the upgrade
/// dialog on Free.
class CashFlowTeaserCard extends StatelessWidget {
  const CashFlowTeaserCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Track 1 gate: the 90-day forecast is a Plus feature. On Free the card
    // taps open the upgrade dialog instead of the screen.
    final forecastLocked = !EntitlementService.instance.allows(
      EntitlementFeature.cashFlowForecast,
    );

    return Card(
      // Flush with the neighbouring at-a-glance cards.
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (forecastLocked) {
            await showUpgradeDialog(
              context,
              EntitlementFeature.cashFlowForecast,
            );
            return;
          }
          await context.push('/cash-flow-forecast');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FinavigColors.violetAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.candlestick_chart_rounded,
                  color: FinavigColors.violetAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Cash-Flow Forecast',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spending pace strip: avg/day, projected month-end, safe-to-spend/day.
class SpendingPaceCard extends StatelessWidget {
  final ({double income, double expense, double net}) summary;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const SpendingPaceCard({
    super.key,
    required this.summary,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyPace = summary.expense / now.day;
    final projected = dailyPace * daysInMonth;
    final remainingDays = daysInMonth - now.day;
    final affordableDaily = remainingDays > 0 && summary.net > 0
        ? summary.net / remainingDays
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header sits outside the tinted box, like every other Money
        // section, so its collapse chevron lines up with theirs.
        _paceHeader(
          theme,
          now,
          daysInMonth,
          collapsed: collapsed,
          onToggleSection: onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            const SizedBox(height: 12),
            TintedCardBox(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _paceColumn(
                          theme,
                          'Avg / day',
                          MoneyFormat.aed(dailyPace),
                        ),
                      ),
                      Expanded(
                        child: _paceColumn(
                          theme,
                          'Projected month-end',
                          MoneyFormat.aed(projected),
                          color: summary.net < 0 ? Colors.red : Colors.teal,
                        ),
                      ),
                      Expanded(
                        child: _paceColumn(
                          theme,
                          'Safe to spend / day',
                          summary.net > 0
                              ? MoneyFormat.aed(affordableDaily)
                              : '—',
                          color: summary.net > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (summary.net < 0 && remainingDays > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You are spending more than you earn this month — consider cutting back for the remaining $remainingDays days.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Header row of the spending-pace card: icon + title, with a
  /// minimize/expand chevron when [onToggleSection] is provided.
  Widget _paceHeader(
    ThemeData theme,
    DateTime now,
    int daysInMonth, {
    required bool collapsed,
    VoidCallback? onToggleSection,
  }) {
    final row = Row(
      children: [
        Icon(Icons.speed_rounded, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Spending pace · day ${now.day} of $daysInMonth',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onToggleSection != null)
          SectionCollapseChevron(collapsed: collapsed),
      ],
    );
    if (onToggleSection == null) return row;
    return InkWell(
      onTap: onToggleSection,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }

  Widget _paceColumn(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FittedBox: long labels scale down instead of overflowing on
        // narrow screens.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Weekly spend chart (last 6 weeks, simple bars) with per-bucket
/// RepaintBoundaries so scrolling never repaints the whole chart.
class WeeklySpendChart extends StatefulWidget {
  final List<FinanceTransaction> transactions;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const WeeklySpendChart({
    super.key,
    required this.transactions,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  State<WeeklySpendChart> createState() => _WeeklySpendChartState();
}

class _WeeklySpendChartState extends State<WeeklySpendChart> {
  List<_WeekBucket>? _cachedBuckets;
  List<FinanceTransaction>? _cachedSource;

  // Recompute buckets only when the transaction list identity changes —
  // not on every theme/scroll-driven rebuild.
  List<_WeekBucket> _buckets() {
    if (_cachedBuckets != null &&
        identical(_cachedSource, widget.transactions)) {
      return _cachedBuckets!;
    }
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final mondayDate = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day,
    );

    final buckets = List<_WeekBucket>.generate(6, (i) {
      final start = mondayDate.subtract(Duration(days: (5 - i) * 7));
      return _WeekBucket(start, start.add(const Duration(days: 7)));
    });

    for (final t in widget.transactions) {
      // Loan legs mirror a credit obligation — not spending; keeping them
      // out here keeps the chart consistent with the summary totals.
      if (t.isCreditLinked) continue;
      if (t.kind != FinanceKind.expense) continue;
      for (final b in buckets) {
        if (!t.occurredAt.isBefore(b.start) && t.occurredAt.isBefore(b.end)) {
          b.spend += t.amount;
        }
      }
    }

    _cachedSource = widget.transactions;
    _cachedBuckets = buckets;
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _buckets();
    final maxSpend = buckets
        .map((b) => b.spend)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.bar_chart_rounded,
          title: 'Last 6 weeks',
          collapsed: widget.collapsed,
          onToggle: widget.onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: widget.collapsed,
          children: [
            const SizedBox(height: 12),
            TintedCardBox(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final b in buckets) ...[
                          Expanded(
                            child: RepaintBoundary(
                              child: _WeekBar(bucket: b, maxSpend: maxSpend),
                            ),
                          ),
                          if (b != buckets.last) const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final b in buckets) ...[
                        Expanded(
                          child: Text(
                            '${b.start.day}/${b.start.month}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        if (b != buckets.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One bar in the weekly chart — isolated repaint unit.
class _WeekBar extends StatelessWidget {
  final _WeekBucket bucket;
  final double maxSpend;

  const _WeekBar({required this.bucket, required this.maxSpend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (bucket.spend > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              shortMoney(bucket.spend),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        Container(
          height: maxSpend <= 0 ? 4 : 8 + (bucket.spend / maxSpend) * 84,
          width: 22,
          decoration: BoxDecoration(
            color: bucket.spend > 0
                ? theme.colorScheme.primary.withOpacity(0.75)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _WeekBucket {
  final DateTime start;
  final DateTime end;
  double spend = 0.0;

  _WeekBucket(this.start, this.end);
}

/// Category breakdown with share bars.
class CategoryBreakdownCard extends StatelessWidget {
  final Map<FinanceCategory, double> spendByCategory;
  final double totalExpense;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const CategoryBreakdownCard({
    super.key,
    required this.spendByCategory,
    required this.totalExpense,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = spendByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.pie_chart_rounded,
          title: 'Where money goes',
          collapsed: collapsed,
          onToggle: onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: collapsed,
          children: [
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const HintCard(
                'Add expenses to see a breakdown by category.',
                scene: EmptyStateScene.growth,
              )
            else
              TintedCardBox(
                child: Column(
                  children: [
                    for (final e in entries) ...[
                      Row(
                        children: [
                          Icon(
                            e.key.icon,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key.displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${(e.value / (totalExpense <= 0 ? 1 : totalExpense) * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            MoneyFormat.aed(e.value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: totalExpense <= 0
                              ? 0
                              : (e.value / totalExpense).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Top expenses this month.
class TopExpensesCard extends StatefulWidget {
  final List<FinanceTransaction> transactions;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const TopExpensesCard({
    super.key,
    required this.transactions,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  State<TopExpensesCard> createState() => _TopExpensesCardState();
}

class _TopExpensesCardState extends State<TopExpensesCard> {
  List<FinanceTransaction>? _cachedTop;
  List<FinanceTransaction>? _cachedSource;

  List<FinanceTransaction> _top() {
    if (_cachedTop != null && identical(_cachedSource, widget.transactions)) {
      return _cachedTop!;
    }
    final now = DateTime.now();
    final expenses =
        widget.transactions
            .where(
              (t) =>
                  // Loan legs are not real spending (see summaryForMonth).
                  !t.isCreditLinked &&
                  t.kind == FinanceKind.expense &&
                  t.occurredAt.year == now.year &&
                  t.occurredAt.month == now.month,
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = expenses.take(5).toList();

    _cachedSource = widget.transactions;
    _cachedTop = top;
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = _top();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.local_fire_department_rounded,
          title: 'Biggest expenses',
          collapsed: widget.collapsed,
          onToggle: widget.onToggleSection,
        ),
        CollapsibleSectionBody(
          collapsed: widget.collapsed,
          children: [
            const SizedBox(height: 12),
            if (top.isEmpty)
              const HintCard(
                'No expenses recorded this month yet.',
                scene: EmptyStateScene.growth,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) InsetDivider(indent: 52),
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#${i + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          top[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${top[i].category.displayName} • ${top[i].occurredAt.day}/${top[i].occurredAt.month}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        trailing: Text(
                          MoneyFormat.aed(top[i].amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Renewal breakdown — which documents drive the outlook.
class RenewalBreakdownCard extends StatefulWidget {
  final List<ExpiryItem> items;
  final bool collapsed;
  final VoidCallback? onToggleSection;

  const RenewalBreakdownCard({
    super.key,
    required this.items,
    this.collapsed = false,
    this.onToggleSection,
  });

  @override
  State<RenewalBreakdownCard> createState() => _RenewalBreakdownCardState();
}

class _RenewalBreakdownCardState extends State<RenewalBreakdownCard> {
  List<ExpiryItem>? _cachedUpcoming;
  List<ExpiryItem>? _cachedSource;

  List<ExpiryItem> _upcoming() {
    if (_cachedUpcoming != null && identical(_cachedSource, widget.items)) {
      return _cachedUpcoming!;
    }
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 90));
    final upcoming =
        widget.items
            .where(
              (i) =>
                  i.isActive &&
                  i.expiresAt.isAfter(now) &&
                  i.expiresAt.isBefore(cutoff) &&
                  (i.renewalFee ?? 0) > 0,
            )
            .toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    _cachedSource = widget.items;
    _cachedUpcoming = upcoming;
    return upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = _upcoming();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Padding(
      // The "at a glance" group stacks flush, so this section owns the
      // breathing room that sets the renewals list apart. Empty state
      // returns above, so the gap never leaves dead space behind.
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.event_repeat_rounded,
            title: 'Upcoming renewals',
            collapsed: widget.collapsed,
            onToggle: widget.onToggleSection,
          ),
          CollapsibleSectionBody(
            collapsed: widget.collapsed,
            children: [
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var idx = 0; idx < upcoming.length; idx++) ...[
                      if (idx > 0) InsetDivider(indent: 56),
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: upcoming[idx].docType.primaryColor.withOpacity(
                              0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            upcoming[idx].docType.icon,
                            size: 18,
                            // White on the dark canvas; the chip tint keeps the
                            // document type's colour coding.
                            color: FinavigColors.adaptiveIcon(
                              context,
                              upcoming[idx].docType.primaryColor,
                            ),
                          ),
                        ),
                        title: Text(
                          upcoming[idx].displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Due ${ExpiryItem.formatDate(upcoming[idx].expiresAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        trailing: Text(
                          MoneyFormat.aed(upcoming[idx].renewalFee!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
