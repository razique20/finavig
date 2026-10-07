import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';

/// Categories grid at the top of the Home content sheet — 8 bento tiles
/// (Documents, Renewals, Envelopes, Records, Forecast, AI Summary,
/// AI Planner, Scan) with the pending-actions counter in the header row.
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
    // Tile colours resolve through the theme transition factor so they
    // cross-fade with the light↔dark animation. Branching on `isDark` here
    // snapped every tile in one frame halfway through the transition — a
    // visible blink.
    final fade = FinavigTransition.of(context);
    final tileBg = fade.color(
      Colors.white,
      FinavigColors.slate.withValues(alpha: 0.5),
    );
    final labelColor = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textSecondary,
    );

    Widget tile(BentoIconTile iconTile, String label, VoidCallback onTap) =>
        Material(
          color: tileBg,
          borderRadius: BorderRadius.circular(FinavigRadius.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconTile,
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Explicit zero: without it the scroll view inherits the shell's
            // extendBody bottom inset (nav-pill height) as implicit sliver
            // padding — a ~120px blank band under the tiles on device.
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [
              tile(
                const BentoIconTile(
                    icon: Icons.description_rounded, color: FinavigColors.violet),
                'Documents',
                () => context.go('/documents'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.calendar_month_rounded,
                    color: FinavigColors.violet),
                'Renewals',
                () => context.push('/expiry-list'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.savings_rounded, color: FinavigColors.violet),
                'Envelopes',
                () => context.push('/envelopes'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.receipt_long_rounded,
                    color: FinavigColors.violet),
                'Records',
                () => context.push('/records'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.trending_up_rounded,
                    color: FinavigColors.violet),
                'Forecast',
                () => context.push('/cash-flow-forecast'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.auto_awesome_rounded,
                    color: FinavigColors.violet),
                'AI Summary',
                () => context.push('/ai-summary'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.flag_rounded, color: FinavigColors.violet),
                'AI Planner',
                () => context.push('/ai-budget-plan'),
              ),
              tile(
                const BentoIconTile(
                    icon: Icons.document_scanner_rounded,
                    color: FinavigColors.violet),
                'Scan',
                () {
                  // Free plan document limit — paywall when the quota is full.
                  unawaited(onScanTap());
                },
              ),
            ],
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
