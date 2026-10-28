import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';

/// Categories section of the Home tab — a clean, airy shortcuts grid
/// with an interactive collapse/expand toggle and a prominent Scan action.
///
/// Gives users the power to minimize the shortcuts to a simple, clean,
/// uncluttered layout or expand them to access all sub-features at a glance.
class HomeCategoriesGrid extends StatefulWidget {
  final int pendingActionsCount;
  final Future<void> Function() onScanTap;

  const HomeCategoriesGrid({
    super.key,
    required this.pendingActionsCount,
    required this.onScanTap,
  });

  @override
  State<HomeCategoriesGrid> createState() => _HomeCategoriesGridState();
}

class _HomeCategoriesGridState extends State<HomeCategoriesGrid> {
  static const String _prefKey = 'home_categories_collapsed';
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isCollapsed = prefs.getBool(_prefKey) ?? false;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final next = !_isCollapsed;
    setState(() => _isCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = widget.pendingActionsCount;
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

    /// One compact bento tile inside the unified Inset Hub:
    Widget tile({
      required IconData icon,
      required Color accent,
      required String label,
      required VoidCallback onTap,
    }) =>
        Material(
          color: tileBg,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BentoIconTile(
                    icon: icon,
                    color: accent,
                    size: 38,
                    iconSize: 19,
                    radius: 12,
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

    Widget row(List<Widget> tiles) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
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
              if (pending > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
              ],
              const Spacer(),
              // Interactive collapse/expand toggle to make the middle section
              // simple, clean, and blank on demand.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleCollapse,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCollapsed ? 'Show' : 'Hide',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _isCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 12),
            // Unified Apple & Mercury style Inset Hub card housing all 6 shortcuts
            Container(
              decoration: BoxDecoration(
                color: fade.color(
                  Colors.white.withValues(alpha: 0.6),
                  FinavigColors.slate.withValues(alpha: 0.25),
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: fade.color(
                    Colors.black.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.06),
                  ),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  row([
                    tile(
                      icon: Icons.description_rounded,
                      accent: FinavigColors.logoBlue,
                      label: 'Documents',
                      onTap: () => context.go('/documents'),
                    ),
                    tile(
                      icon: Icons.calendar_month_rounded,
                      accent: FinavigColors.logoRed,
                      label: 'Renewals',
                      onTap: () => context.push('/expiry-list'),
                    ),
                    tile(
                      icon: Icons.savings_rounded,
                      accent: FinavigColors.logoGreen,
                      label: 'Envelopes',
                      onTap: () => context.push('/envelopes'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  row([
                    tile(
                      icon: Icons.receipt_long_rounded,
                      accent: FinavigColors.logoGold,
                      label: 'Records',
                      onTap: () => context.push('/records'),
                    ),
                    tile(
                      icon: Icons.trending_up_rounded,
                      accent: FinavigColors.logoBlue,
                      label: 'Forecast',
                      onTap: () => context.push('/cash-flow-forecast'),
                    ),
                    tile(
                      icon: Icons.flag_rounded,
                      accent: FinavigColors.logoGreen,
                      label: 'AI Planner',
                      onTap: () => context.push('/ai-budget-plan'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
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
                  unawaited(widget.onScanTap());
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
