import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../models/finance.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';

/// Two inline stats under the filter chips: the nearest upcoming document and
/// the total upcoming renewal fees — what the list means at a glance.
///
/// No card here on purpose: the pair sits straight on the canvas, split by a
/// single hairline divider, so the Documents page stays flat and linear.
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
    final fade = FinavigTransition.of(context);
    final due = nextDue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _InlineStat(
              icon: Icons.hourglass_top_rounded,
              color: FinavigColors.orange,
              label: 'Next due',
              value: due == null
                  ? '—'
                  : '${due.displayName} · ${due.daysRemaining}d',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: fade.color(
              FinavigColors.fog,
              Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Expanded(
            child: _InlineStat(
              icon: Icons.payments_rounded,
              color: FinavigColors.teal,
              label: 'Upcoming fees',
              value: totalUpcomingFees > 0
                  ? MoneyFormat.aed(totalUpcomingFees)
                  : '—',
            ),
          ),
        ],
      ),
    );
  }
}

/// One icon + label + value stat, drawn directly on the canvas.
class _InlineStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InlineStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    return Row(
      children: [
        BentoIconTile(
          icon: icon,
          color: color,
          size: 34,
          iconSize: 16,
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
                  color: fade.color(
                    FinavigColors.textMutedLight,
                    FinavigColors.textMuted,
                  ),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  ),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
