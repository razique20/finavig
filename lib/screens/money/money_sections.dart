import 'package:flutter/material.dart';

import '../../models/finance.dart';
import '../../theme/app_theme.dart';
import '../../widgets/indicators/empty_state_illustration.dart';

export '../../widgets/indicators/empty_state_illustration.dart'
    show EmptyStateScene;

/// Section header row: icon + title + optional trailing action.
///
/// Previously a private method on the Money screen state — extracted so each
/// modular section widget owns its own header and rebuilds independently.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  /// When [onToggle] is set the header becomes the minimize/expand
  /// control for its section: tapping it (or the chevron) collapses
  /// the section body, and [collapsed] drives the chevron's orientation.
  final bool collapsed;
  final VoidCallback? onToggle;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        Icon(icon, size: 20, color: FinavigColors.adaptiveIcon(context, theme.colorScheme.outline)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            key: actionKey,
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        if (onToggle != null) SectionCollapseChevron(collapsed: collapsed),
      ],
    );
    if (onToggle == null) return row;
    // Collapsible section: the whole header row toggles the body.
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}

/// Animated chevron on a collapsible section header: points down while
/// the section is minimized (tap to expand) and flips up once expanded.
class SectionCollapseChevron extends StatelessWidget {
  final bool collapsed;

  const SectionCollapseChevron({super.key, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: AnimatedRotation(
        turns: collapsed ? 0 : 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Icon(
          Icons.expand_more_rounded,
          size: 22,
          color: FinavigColors.adaptiveIcon(context, Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

/// Collapsible body for a Money section: fades and clips the content
/// away when [collapsed] so minimizing a section keeps the layout
/// smooth instead of snapping. The content stays laid out (clipped to
/// zero height) so expanding is instant.
class CollapsibleSectionBody extends StatelessWidget {
  final bool collapsed;
  final double spacing;
  final List<Widget> children;

  const CollapsibleSectionBody({
    super.key,
    required this.collapsed,
    this.spacing = 12,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin only matters on the first build; later toggles animate
      // from the current factor to the new end.
      tween: Tween(begin: 0, end: collapsed ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, factor, child) {
        if (factor <= 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing),
          ...children,
        ],
      ),
    );
  }
}

/// Soft empty-state card used across Money sections.
class HintCard extends StatelessWidget {
  final String text;
  final EmptyStateScene scene;

  const HintCard(this.text, {super.key, this.scene = EmptyStateScene.wallet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(scene: scene, size: 88),
          const SizedBox(height: 10),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The standard tinted container most Money analysis cards render inside.
class TintedCardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TintedCardBox({
    super.key,
    this.padding = const EdgeInsets.all(14),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// Divider matching the inset list styling used inside Money cards.
class InsetDivider extends StatelessWidget {
  final double indent;

  const InsetDivider({super.key, this.indent = 56});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: indent,
      color: Theme.of(context).dividerColor,
    );
  }
}

/// Compact "1.2k" money formatter for chart labels.
String shortMoney(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

/// Named amount format alias kept local so section files don't each pull the
/// whole finance model just for a formatter — MoneyFormat lives there anyway.
typedef MoneyText = MoneyFormat;
