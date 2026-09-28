import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../models/finance.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';

/// Two insight tiles under the filter chips: the nearest upcoming document
/// and the total upcoming renewal fees — what the list means at a glance.
class DocumentsInsightsSection extends StatelessWidget {
  final ExpiryItem? nextDue;
  final double totalUpcomingFees;

  const DocumentsInsightsSection({
    super.key,
    required this.nextDue,
    required this.totalUpcomingFees,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileBg =
        isDark ? FinavigColors.slate.withOpacity(0.5) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _InsightTile(
              theme: theme,
              tileBg: tileBg,
              icon: Icons.hourglass_top_rounded,
              label: 'Next due',
              value: nextDue == null
                  ? '—'
                  : '${nextDue!.displayName} · ${nextDue!.daysRemaining}d',
              iconColor: FinavigColors.orange,
              tint: FinavigColors.orangeTint,
              onDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InsightTile(
              theme: theme,
              tileBg: tileBg,
              icon: Icons.payments_rounded,
              label: 'Upcoming fees',
              value:
                  totalUpcomingFees > 0 ? MoneyFormat.aed(totalUpcomingFees) : '—',
              iconColor: FinavigColors.teal,
              tint: FinavigColors.tealTint,
              onDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final ThemeData theme;
  final Color tileBg;
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? tint;
  final bool onDark;

  const _InsightTile({
    required this.theme,
    required this.tileBg,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.tint,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(FinavigRadius.card),
      ),
      child: Row(
        children: [
          BentoIconTile(
            icon: icon,
            color: iconColor,
            tint: onDark ? tint?.withOpacity(0.16) : tint,
            size: 36,
            iconSize: 17,
            radius: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
