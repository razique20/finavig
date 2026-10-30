import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Compact, canvas-colored icon button shared by the main tab headers.
class CanvasIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const CanvasIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final radius = BorderRadius.circular(14);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? fade.color(
                      FinavigColors.textPrimaryLight,
                      FinavigColors.textPrimary,
                    )
                  : fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass icon button used inside the navy hero headers (dark-mode
/// toggle on Home, Ask Finavig AI / search on Documents, sign out on
/// Profile) — one implementation shared by all tabs.
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

/// Outlined / filled action pill inside the hero headers (Record/Budget on
/// Home, Filter/Sort/Add on Documents). At most one of [filled]/[outlined]
/// may be true; both default to outlined styling when neither is set.
class HeroActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool outlined;
  final VoidCallback onTap;

  /// Screen-reader / long-press label. Essential for the icon-only pill
  /// (empty [label]), where the meaning is otherwise invisible.
  final String? tooltip;

  const HeroActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.outlined = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    assert(!(filled && outlined));
    final Color bg;
    final Color fg;
    final BorderSide side;
    if (filled) {
      bg = Colors.white;
      fg = FinavigColors.ink;
      side = BorderSide.none;
    } else {
      bg = Colors.white.withValues(alpha: 0.10);
      fg = Colors.white;
      side = BorderSide(color: Colors.white.withValues(alpha: 0.22));
    }

    final pill = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: side,
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 14 : 18,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip, child: pill);
  }
}
