import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
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
    // Resolved through the theme transition factor so the tiles cross-fade
    // with the light↔dark animation instead of snapping halfway through it.
    final fade = FinavigTransition.of(context);

    final tileBg = fade.color(
      Colors.white,
      FinavigColors.slate.withValues(alpha: 0.5),
    );

    /// Modern squircle bento shortcut: elevated card surface with a soft-tinted
    /// squircle icon container on top and concise label beneath.
    Widget tile({
      required IconData icon,
      required Color accent,
      required String label,
      required VoidCallback onTap,
    }) {
      return Material(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 74,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Squircle icon container with tint matching feature accent
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: fade.value(0.11, 0.16)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 22,
                        color: fade.color(FinavigColors.logoBlue, Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fade.color(
                        FinavigColors.textPrimaryLight,
                        FinavigColors.textSecondary,
                      ),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: -0.1,
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            key: const ValueKey('home-category-scroller'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                tile(
                  icon: Icons.auto_awesome_outlined,
                  accent: FinavigColors.lilac,
                  label: 'AI Plan',
                  onTap: () => context.push('/ai-budget-plan'),
                ),
                tile(
                  icon: Icons.document_scanner_outlined,
                  accent: const Color(0xFF0EA5E9),
                  label: 'Scan',
                  onTap: () {
                    unawaited(onScanTap());
                  },
                ),
                tile(
                  icon: Icons.description_outlined,
                  accent: FinavigColors.logoBlue,
                  label: 'Documents',
                  onTap: () => context.go('/documents'),
                ),
                tile(
                  icon: Icons.event_outlined,
                  accent: FinavigColors.logoRed,
                  label: 'Renewals',
                  onTap: () => context.push('/expiry-list'),
                ),
                tile(
                  icon: Icons.mail_outline_rounded,
                  accent: FinavigColors.logoGreen,
                  label: 'Envelopes',
                  onTap: () => context.push('/envelopes'),
                ),
                tile(
                  icon: Icons.receipt_long_outlined,
                  accent: FinavigColors.logoGold,
                  label: 'Records',
                  onTap: () => context.push('/records'),
                ),
                tile(
                  icon: Icons.insights_outlined,
                  accent: const Color(0xFF6366F1),
                  label: 'Forecast',
                  onTap: () => context.push('/cash-flow-forecast'),
                ),
              ],
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