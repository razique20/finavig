import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';

/// Categories section of the Home tab — a bento grid over the light canvas:
/// six compact tiles, three per row, each with a colourful icon chip, then a
/// full-width AI Summary feature tile and a full-width Scan call-to-action.
class HomeCategoriesGrid extends StatelessWidget {
  final int pendingActionsCount;
  final Future<void> Function() onScanTap;

  const HomeCategoriesGrid({
    super.key,
    required this.pendingActionsCount,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = pendingActionsCount;
    // Resolved through the theme transition factor so the tiles cross-fade
    // with the light↔dark animation instead of snapping halfway through it.
    final fade = FinavigTransition.of(context);
    final tileBg = fade.color(
      Colors.white,
      FinavigColors.slate.withValues(alpha: 0.5),
    );
    final labelColor = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textSecondary,
    );

    /// One compact bento tile: icon chip, title, one-line subtitle. Grows to
    /// the row's height via [IntrinsicHeight] so the row stays flush.
    Widget tile({
      required IconData icon,
      required Color accent,
      required String label,
      required String subtitle,
      required VoidCallback onTap,
    }) =>
        Material(
          color: tileBg,
          borderRadius: BorderRadius.circular(FinavigRadius.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BentoIconTile(
                    icon: icon,
                    color: accent,
                    size: 38,
                    iconSize: 19,
                    radius: 12,
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

    Widget row(List<Widget> tiles) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (pending > 0)
                Text(
                  '$pending need attention',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: FinavigColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          row([
            tile(
              icon: Icons.description_rounded,
              accent: FinavigColors.violet,
              label: 'Documents',
              subtitle: 'Files',
              onTap: () => context.go('/documents'),
            ),
            tile(
              icon: Icons.calendar_month_rounded,
              accent: FinavigColors.amber,
              label: 'Renewals',
              subtitle: 'Expiries',
              onTap: () => context.push('/expiry-list'),
            ),
            tile(
              icon: Icons.savings_rounded,
              accent: FinavigColors.teal,
              label: 'Envelopes',
              subtitle: 'Savings',
              onTap: () => context.push('/envelopes'),
            ),
          ]),
          const SizedBox(height: 10),
          row([
            tile(
              icon: Icons.receipt_long_rounded,
              accent: FinavigColors.blue,
              label: 'Records',
              subtitle: 'Ledger',
              onTap: () => context.push('/records'),
            ),
            tile(
              icon: Icons.trending_up_rounded,
              accent: FinavigColors.sky,
              label: 'Forecast',
              subtitle: '90 days',
              onTap: () => context.push('/cash-flow-forecast'),
            ),
            tile(
              icon: Icons.flag_rounded,
              accent: FinavigColors.lilac,
              label: 'AI Planner',
              subtitle: 'AI budget',
              onTap: () => context.push('/ai-budget-plan'),
            ),
          ]),
          const SizedBox(height: 10),
          // Full-width feature tile: AI Summary.
          Material(
            color: fade.color(
              FinavigColors.lilac.withValues(alpha: 0.10),
              FinavigColors.lilac.withValues(alpha: 0.18),
            ),
            borderRadius: BorderRadius.circular(FinavigRadius.tile),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/ai-summary'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const BentoIconTile(
                      icon: Icons.auto_awesome_rounded,
                      color: FinavigColors.lilac,
                      size: 38,
                      iconSize: 19,
                      radius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Summary',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Executive summary of your documents',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Full-width primary CTA: Scan.
          Material(
            borderRadius: BorderRadius.circular(FinavigRadius.tile),
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    fade.color(const Color(0xFF2563EB), const Color(0xFF1D4ED8)),
                    fade.color(const Color(0xFF1E3A8A), const Color(0xFF111C3F)),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: InkWell(
                onTap: () {
                  // Free plan document limit — paywall when the quota is full.
                  unawaited(onScanTap());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Add a document to track its expiry',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience helper wiring the grid's Scan tile to the entitlement-gated
/// scanner flow (free-tier document limit — paywall when the quota is full).
Future<void> openGatedScanner(BuildContext context) async {
  if (!await enforceDocumentLimit(context)) return;
  if (context.mounted) await context.push('/scan');
}
