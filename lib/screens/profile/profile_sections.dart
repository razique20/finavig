import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/bento_icon_tile.dart';

/// Shared building blocks for the Profile (Settings) screen — the flat list
/// rows of the new airy layout, plus the grouped card rows reused inside the
/// bottom sheets (collections, subscription, security, AI).

/// Accent-tinted card background for the grouped sheet cards — a soft pastel
/// wash in light mode that deepens in dark mode. Interpolated through
/// [FinavigTransition] so it cross-fades with the theme animation.
Color profileAccentBg(BuildContext context, Color accent) =>
    FinavigTransition.of(context).color(
      accent.withValues(alpha: 0.07),
      accent.withValues(alpha: 0.15),
    );

/// A vertical stack of [ProfileListRow]s with even breathing room.
class ProfileList extends StatelessWidget {
  final List<Widget> children;

  const ProfileList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One full-width settings row — a white (or dark) rounded card with a leading
/// outline icon, a title, an optional current value and a trailing arrow.
/// The flat list anatomy of the redesigned Settings page.
class ProfileListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Danger rows (delete account) paint their icon and title red.
  final bool danger;

  const ProfileListRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = danger
        ? FinavigColors.danger
        : fade.color(FinavigColors.textPrimaryLight, FinavigColors.textPrimary);

    return Container(
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(FinavigRadius.card),
        boxShadow: FinavigShadows.adaptive(isDark),
        border: Border.all(
          color: fade.color(Colors.transparent, Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FinavigRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FinavigRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                trailing ??
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
    );
  }
}

/// A grouped settings card (used inside the bottom sheets): an accent-marked
/// title row over a rounded, accent-tinted column of rows.
class ProfileSectionGroup extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;

  /// Accent that tints the card and its title marker.
  final Color accent;

  const ProfileSectionGroup({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.accent = FinavigColors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final tileBg = profileAccentBg(context, accent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
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
                      color: fade.color(
                        Colors.black.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.06),
                      ),
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
/// and a trailing widget — the grouped-row anatomy reused inside the sheets.
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
    final fade = FinavigTransition.of(context);
    final accent = iconColor ?? FinavigColors.indigo;

    return Material(
      color: highlighted
          ? theme.colorScheme.primary
              .withValues(alpha: fade.value(0.05, 0.14))
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
    final fade = FinavigTransition.of(context);
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
            backgroundColor: fade.color(
              Colors.black.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.08),
            ),
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
