import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/expiry_item.dart';
import '../../services/urgency_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs/ask_finavig_sheet.dart';

/// Header of the Documents tab, sitting directly on the light/airy canvas:
/// the title, the Ask Finavig AI + search chip buttons, a live status line
/// that doubles as filter feedback ("2 expired · 12 of 30 shown"), and the
/// Filter / Sort / Add action pills.
///
/// Deliberately card-free: the Documents page reads as one flat, linear
/// workspace — no hero band, no rounded content sheet, no white panels.
class DocumentsHeroHeader extends StatelessWidget {
  final List<ExpiryItem> items;
  final UrgencySnapshot urgency;
  final int visibleCount;
  final bool hasActiveFilters;
  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;
  final Future<void> Function() onAddTap;

  const DocumentsHeroHeader({
    super.key,
    required this.items,
    required this.urgency,
    required this.visibleCount,
    required this.hasActiveFilters,
    required this.onFilterTap,
    required this.onSortTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final pending = urgency.pendingActions.length;
    final expired = items.where((i) => i.isActive && i.isExpired).length;

    // One status line that doubles as filter feedback — "shown" only appears
    // while filters narrow the list. The leading dot carries the urgency.
    final statusPart = expired > 0
        ? '$expired expired'
        : pending > 0
        ? '$pending need attention'
        : 'All on track';
    final scopePart = hasActiveFilters
        ? '$visibleCount of ${items.length} shown'
        : '${items.length} tracked';
    final subtitle = '$statusPart · $scopePart';
    final statusColor = expired > 0
        ? FinavigColors.danger
        : pending > 0
        ? FinavigColors.warning
        : FinavigColors.safe;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Documents',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  ),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Ask Finavig AI: universal voice/text add (money or docs).
              _CanvasIconButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'Ask Finavig AI',
                onTap: () => AskFinavigSheet.show(context),
              ),
              const SizedBox(width: 8),
              _CanvasIconButton(
                icon: Icons.saved_search_rounded,
                tooltip: 'Search all documents',
                onTap: () => context.push('/search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Single-line live status + scope.
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fade.color(
                      FinavigColors.textSecondaryLight,
                      FinavigColors.textSecondary,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action pills: filter + sort, then the primary Add pill.
          Row(
            children: [
              _CanvasPill(
                icon: Icons.filter_alt_rounded,
                label: 'Filter',
                onTap: onFilterTap,
              ),
              const SizedBox(width: 8),
              _CanvasPill(
                icon: Icons.sort_rounded,
                label: 'Sort',
                onTap: onSortTap,
              ),
              const Spacer(),
              _CanvasPill(
                icon: Icons.add_rounded,
                label: 'Add',
                filled: true,
                onTap: () => onAddTap(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Documents header action button — a soft accent chip in light mode and a
/// translucent white chip in dark, like the Home and Money headers. The glyph
/// is the dark ink on the light canvas; in dark mode it flips to white.
class _CanvasIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CanvasIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fade.color(
          FinavigColors.accent.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 17,
              color: fade.color(FinavigColors.ink, Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill action on the Documents canvas: a hairline-outlined chip by default,
/// or a solid ink (light) / solid white (dark) chip when [filled].
class _CanvasPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _CanvasPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final bg = filled
        ? fade.color(FinavigColors.ink, Colors.white)
        : fade.color(Colors.white, Colors.white.withValues(alpha: 0.06));
    final fg = filled
        ? fade.color(Colors.white, FinavigColors.ink)
        : fade.color(FinavigColors.textPrimaryLight, Colors.white);
    final side = filled
        ? BorderSide.none
        : BorderSide(
            color: fade.color(
              FinavigColors.fog,
              Colors.white.withValues(alpha: 0.14),
            ),
          );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
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
          ),
        ),
      ),
    );
  }
}
