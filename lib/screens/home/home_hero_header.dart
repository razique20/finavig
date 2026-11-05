import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/expiry_item.dart';
import '../../models/finance.dart';
import '../../models/document_collection.dart';
import '../../services/alert_preferences_service.dart';
import '../../services/anomaly_detection_service.dart';
import '../../services/collection_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/finance_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Header of the Home tab on the light, airy canvas: a greeting + collection
/// switcher chip, the dark-mode toggle and the notification bell, then a
/// gradient "Net this month" balance card carrying the quick actions.
class HomeHeroHeader extends StatelessWidget {
  final DocumentCollection? activeCollection;
  final List<ExpiryItem> items;

  /// The "renewals need attention" count the user dismissed this session —
  /// excluded from the bell badge so it matches the banner.
  final int? dismissedAttentionCount;
  final VoidCallback onCollectionSwitcherTap;

  const HomeHeroHeader({
    super.key,
    required this.activeCollection,
    required this.items,
    required this.dismissedAttentionCount,
    required this.onCollectionSwitcherTap,
  });

  /// "12 Mar" of the nearest upcoming renewal, or null when none tracked.
  String? _nextRenewalLabel() {
    final next = _nextUpcomingItem();
    if (next == null) return null;
    return '${next.expiresAt.day} ${_monthAbbrev(next.expiresAt.month)}';
  }

  /// The nearest upcoming active renewal item, or null when none tracked.
  ExpiryItem? _nextUpcomingItem() {
    final now = DateTime.now();
    ExpiryItem? next;
    for (final item in items) {
      if (!item.isActive || item.expiresAt.isBefore(now)) continue;
      if (next == null || item.expiresAt.isBefore(next.expiresAt)) {
        next = item;
      }
    }
    return next;
  }

  static String _monthAbbrev(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(
      FinanceService.instance.activeTransactions,
      now,
    );
    final nextRenewal = _nextRenewalLabel();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Left: greeting + collection switcher chip.
              Expanded(
                child: Material(
                  color: fade.color(Colors.white, FinavigColors.charcoal),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onCollectionSwitcherTap,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          // Profile / collection chip.
                          Material(
                            color: fade.color(
                              FinavigColors.accent.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.12),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                activeCollection?.icon ?? Icons.person_rounded,
                                color: fade.color(
                                  FinavigColors.ink,
                                  Colors.white,
                                ),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        activeCollection?.name ?? 'Personal',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: 16,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CanvasIconButton(
                icon: theme.brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_outlined,
                tooltip: theme.brightness == Brightness.dark
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onTap: () async {
                  final mode = ThemeService.instance.mode;
                  await ThemeService.instance.setMode(
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
              const SizedBox(width: 10),
              HomeNotificationBell(
                items: items,
                dismissedAttentionCount: dismissedAttentionCount,
              ),
              // Refresh button - top right corner of the header
              const SizedBox(width: 6),
              CanvasIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh data from cloud',
                onTap: () async {
                  // Trigger a full refresh of documents and finance data
                  await DocumentScannerService.instance.refresh();
                  await DocumentCollectionService.instance.reset();
                  await FinanceService.instance.refresh();
                },
              ),
              const SizedBox(width: 6),
              CanvasIconButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'AI Financial Pulse',
                onTap: () => context.push('/ai-summary'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Modern Open Cockpit (card-free hero directly on the canvas)
          _HomeOpenCockpit(
            summary: summary,
            items: items,
            activeCurrency: DocumentCollectionService.instance.activeCurrency,
            nextRenewalLabel: nextRenewal,
            nextItem: _nextUpcomingItem(),
            onOpenRenewals: () => context.push('/expiry-list'),
          ),
        ],
      ),
    );
  }
}

/// Claude & ChatGPT signature search discovery pill.
class HomeSearchPill extends StatelessWidget {
  const HomeSearchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    return Material(
      color: fade.color(Colors.white, FinavigColors.charcoal),
      borderRadius: BorderRadius.circular(24),
      elevation: fade.value(1.0, 0.0),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: () => context.push('/search'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: fade.color(
                FinavigColors.ink.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.08),
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search documents, tags, expenses…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textSecondary,
                    ),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/expiry-list'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: fade.color(
                      FinavigColors.cloud,
                      FinavigColors.slate,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern Open Cockpit hero element (card-free, directly integrated on canvas).
/// Provides real-time financial pulse, net cashflow hierarchy, and a future-ready
/// live Renewal Readiness & Liability strip for embedded payments and auto-renew.
class _HomeOpenCockpit extends StatelessWidget {
  final ({double income, double expense, double net}) summary;
  final List<ExpiryItem> items;
  final String activeCurrency;
  final String? nextRenewalLabel;
  final ExpiryItem? nextItem;
  final VoidCallback onOpenRenewals;

  const _HomeOpenCockpit({
    required this.summary,
    required this.items,
    required this.activeCurrency,
    required this.nextRenewalLabel,
    required this.nextItem,
    required this.onOpenRenewals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    final activeDocs = items.where((i) => i.isActive).length;
    final urgentDocs = items
        .where((i) => i.isActive && i.daysRemaining <= 30)
        .length;

    // Premium elevated card surface smoothly interpolating with theme transitions
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            fade.color(Colors.white, const Color(0xFF191B22)),
            fade.color(const Color(0xFFF8F9FC), const Color(0xFF13151A)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: fade.value(0.04, 0.0)),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: fade.value(0.02, 0.0)),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top status badge: Pulse indicator + Active Currency ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fade.color(
                FinavigColors.accent.withValues(alpha: 0.08),
                FinavigColors.accentBright.withValues(alpha: 0.15),
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: fade.color(
                  FinavigColors.accent.withValues(alpha: 0.16),
                  FinavigColors.accentBright.withValues(alpha: 0.25),
                ),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: urgentDocs > 0
                        ? FinavigColors.caution
                        : FinavigColors.safe,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'FINANCIAL PULSE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fade.color(
                      FinavigColors.accent,
                      FinavigColors.accentBright,
                    ),
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: fade.color(
                      FinavigColors.accent.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.4),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  activeCurrency,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fade.color(
                      FinavigColors.textSecondaryLight,
                      FinavigColors.textSecondary,
                    ),
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Main balance metric ──
          Text(
            'Net this month',
            style: theme.textTheme.labelMedium?.copyWith(
              color: fade.color(
                FinavigColors.textSecondaryLight,
                FinavigColors.textSecondary,
              ),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormat.aed(summary.net),
              style: theme.textTheme.displayLarge?.copyWith(
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  Colors.white,
                ),
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cashflow stream pills: Inflow & Outflow ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: FinavigColors.safe.withValues(
                    alpha: fade.value(0.10, 0.16),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_downward_rounded,
                      size: 12,
                      color: FinavigColors.safe,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${MoneyFormat.aed(summary.income)} in',
                      style: const TextStyle(
                        color: FinavigColors.safe,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: FinavigColors.danger.withValues(
                    alpha: fade.value(0.10, 0.16),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: FinavigColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${MoneyFormat.aed(summary.expense)} out',
                      style: const TextStyle(
                        color: FinavigColors.danger,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Divider ──
          Container(
            height: 1,
            decoration: BoxDecoration(
              color: fade.color(
                Colors.black.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Renewal Readiness Strip (integrated in card) ──
          Material(
            color: fade.color(
              const Color(0xFFF5F6F8),
              FinavigColors.slate,
            ),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpenRenewals,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Status badge / icon indicator
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: urgentDocs > 0
                            ? FinavigColors.warning.withValues(
                                alpha: fade.value(0.14, 0.22),
                              )
                            : activeDocs > 0
                                ? FinavigColors.safe.withValues(
                                    alpha: fade.value(0.14, 0.22),
                                  )
                                : fade.color(
                                    FinavigColors.mist,
                                    FinavigColors.slate,
                                  ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        urgentDocs > 0
                            ? Icons.warning_amber_rounded
                            : activeDocs > 0
                                ? Icons.verified_outlined
                                : Icons.description_outlined,
                        size: 17,
                        color: urgentDocs > 0
                            ? FinavigColors.warning
                            : activeDocs > 0
                                ? FinavigColors.safe
                                : fade.color(
                                    FinavigColors.textMutedLight,
                                    FinavigColors.textMuted,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Readiness text & details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'RENEWAL READINESS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: fade.color(
                                    FinavigColors.textMutedLight,
                                    FinavigColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (urgentDocs > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FinavigColors.danger.withValues(
                                      alpha: fade.value(0.15, 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$urgentDocs due soon',
                                    style: const TextStyle(
                                      color: FinavigColors.danger,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else if (activeDocs > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FinavigColors.safe.withValues(
                                      alpha: fade.value(0.15, 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Current',
                                    style: TextStyle(
                                      color: FinavigColors.safe,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nextItem != null
                                ? '${nextItem!.displayName} · in ${nextItem!.daysRemaining}d (${nextRenewalLabel ?? ''})'
                                : activeDocs > 0
                                    ? '$activeDocs active documents · No imminent renewals'
                                    : 'No documents tracked · Tap to view ledger',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: fade.color(
                                FinavigColors.textPrimaryLight,
                                Colors.white,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick stats row showing Spending, Budget usage, and Document count.
/// Used above the Categories grid on the home page.
class HomeQuickStats extends StatelessWidget {
  final String spending;
  final int budgetPct;
  final int docCount;

  const HomeQuickStats({
    super.key,
    required this.spending,
    required this.budgetPct,
    required this.docCount,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final tileBg = fade.color(
      Colors.white,
      FinavigColors.slate.withValues(alpha: 0.5),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickStatTile(
              icon: Icons.trending_up_rounded,
              label: 'Spending',
              value: spending,
              accent: FinavigColors.logoBlue,
              bg: tileBg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickStatTile(
              icon: Icons.flag_outlined,
              label: 'Plans',
              value: '$budgetPct%',
              accent: FinavigColors.logoGold,
              bg: tileBg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickStatTile(
              icon: Icons.description_outlined,
              label: 'Docs',
              value: '$docCount',
              accent: FinavigColors.logoGreen,
              bg: tileBg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single stat tile in the quick stats row.
class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color bg;

  const _QuickStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/ai-summary'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI Summary card — dark blue with sparkle icon, summary preview,
/// and a link to the full AI Executive Summary screen.
/// Can be used below the categories grid on the home page.
class AiSummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  final String spending;
  final int budgetPct;
  final int docCount;

  const AiSummaryCard({
    super.key,
    required this.onTap,
    required this.spending,
    required this.budgetPct,
    required this.docCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    // Dark blue gradient card.
    final cardColor = fade.color(
      const Color(0xFF1B5A8A), // logo-blue deep
      const Color(0xFF132D5A), // dark logo-navy
    );

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(FinavigRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: sparkle icon + label + chevron.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FinavigColors.accentBright.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: FinavigColors.accentBright,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Your spending, budgets & documents',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Divider line.
              Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 16),
              // Quick insights grid: 3 small stat tiles.
              Row(
                children: [
                  Expanded(
                    child: _AiSummaryStat(
                      icon: Icons.trending_up_rounded,
                      label: 'Spending',
                      value: spending,
                      acclColor: FinavigColors.logoBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiSummaryStat(
                      icon: Icons.flag_outlined,
                      label: 'Plans',
                      value: '$budgetPct%',
                      acclColor: FinavigColors.logoGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AiSummaryStat(
                      icon: Icons.description_outlined,
                      label: 'Docs',
                      value: '$docCount',
                      acclColor: FinavigColors.logoGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One small stat tile inside the AI summary card.
class _AiSummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color acclColor;

  const _AiSummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.acclColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 14, color: acclColor),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
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
    final fade = FinavigTransition.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CanvasIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Alerts & notifications',
          onTap: () => _showNotificationsSheet(context),
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
                border: Border.all(
                  color: fade.color(
                    FinavigColors.snowWhite,
                    FinavigColors.obsidian,
                  ),
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
    final pending =
        items
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
                        color: FinavigColors.adaptiveIcon(
                          context,
                          theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
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
        backgroundColor: color.withValues(alpha: 0.15),
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
