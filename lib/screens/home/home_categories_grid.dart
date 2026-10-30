import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';

/// Compact, horizontally scrollable category shortcuts and primary actions
/// for the Home tab.
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

    /// One compact shortcut tile.
    Widget tile({
      required IconData icon,
      required Color accent,
      required String label,
      required VoidCallback onTap,
    }) => Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BentoIconTile(
                icon: icon,
                color: accent,
                size: 32,
                iconSize: 17,
                radius: 10,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: FinavigColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pending need attention',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: FinavigColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SingleChildScrollView(
            key: const ValueKey('home-category-scroller'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                tile(
                  icon: Icons.description_rounded,
                  accent: FinavigColors.logoBlue,
                  label: 'Documents',
                  onTap: () => context.go('/documents'),
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.calendar_month_rounded,
                  accent: FinavigColors.logoRed,
                  label: 'Renewals',
                  onTap: () => context.push('/expiry-list'),
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.savings_rounded,
                  accent: FinavigColors.logoGreen,
                  label: 'Envelopes',
                  onTap: () => context.push('/envelopes'),
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.receipt_long_rounded,
                  accent: FinavigColors.logoGold,
                  label: 'Records',
                  onTap: () => context.push('/records'),
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.trending_up_rounded,
                  accent: FinavigColors.logoBlue,
                  label: 'Forecast',
                  onTap: () => context.push('/cash-flow-forecast'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            key: const ValueKey('home-ai-plan-link'),
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/ai-budget-plan'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    BentoIconTile(
                      icon: Icons.auto_awesome_rounded,
                      color: FinavigColors.logoGreen,
                      size: 32,
                      iconSize: 17,
                      radius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Budget Plan',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Full-width primary CTA: Scan.
          Material(
            borderRadius: BorderRadius.circular(FinavigRadius.tile),
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    fade.color(
                      const Color(0xFF2E8BC0),
                      const Color(0xFF2671A8),
                    ),
                    fade.color(
                      const Color(0xFF1B5A8A),
                      const Color(0xFF0E3A5C),
                    ),
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
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Add a document to track its expiry',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
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
                        size: 22,
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
