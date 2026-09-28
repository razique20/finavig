import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';

/// Shared building blocks for the Profile (Settings) screen — extracted from
/// `profile_screen.dart` so each section widget owns its pieces and rebuilds
/// independently. Same anatomy as `money_sections.dart`.

/// Tile background color: white in light mode, translucent slate in dark.
Color profileTileBg(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return isDark ? FinavigColors.slate.withOpacity(0.5) : Colors.white;
}

/// A grouped settings card: title row (like "My Collections") over a rounded
/// tile-background column of rows, matching the sheet's tile style.
class ProfileSectionGroup extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;

  const ProfileSectionGroup({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = profileTileBg(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(FinavigRadius.card),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 50,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.05),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable settings row: tinted circular icon, title, optional subtitle,
/// and a trailing widget — the same row anatomy as the notification rows.
class ProfileSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  const ProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = iconColor ?? FinavigColors.indigo;

    return Material(
      color: highlighted
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.14 : 0.05)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(FinavigRadius.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FinavigRadius.tile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              BentoIconTile(
                icon: icon,
                color: accent,
                size: 38,
                iconSize: 18,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Plan usage meter: label + "used / max" (or "used · unlimited"), with a
/// thin progress bar — documents/workspaces at a glance.
class ProfileUsageMeter extends StatelessWidget {
  final String label;
  final int used;
  final int? max;

  const ProfileUsageMeter({
    super.key,
    required this.label,
    required this.used,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratio = max == null || max == 0 ? 0.0 : (used / max!).clamp(0.0, 1.0);
    final barColor = max == null
        ? FinavigColors.safe
        : ratio >= 1.0
            ? FinavigColors.danger
            : ratio >= 0.8
                ? FinavigColors.warning
                : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Text(
              max == null ? '$used · unlimited' : '$used / $max',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: max == null ? 1.0 : ratio,
            minHeight: 5,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Colored notice row used inside the subscription card (plan-expiry
/// countdown, expired-plan warning).
class ProfilePlanNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const ProfilePlanNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a date as "12 Sep 2026" — shared by the subscription card.
String formatProfileDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
