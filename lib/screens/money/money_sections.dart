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

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
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
      ],
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
    return Divider(height: 1, indent: indent, color: Theme.of(context).dividerColor);
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
