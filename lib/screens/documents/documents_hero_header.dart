import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../services/urgency_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs/ask_finavig_sheet.dart';
import '../../widgets/hero_widgets.dart';

/// Header of the Documents tab, sitting directly on the light/airy canvas.
///
/// Compact layout: title row with inline-expandable search, a live status line,
/// and the Filter / Sort / Add action pills. When [isSearching] is true the
/// title row transforms into a search text field with a cancel button.
///
/// The Filter pill shows a small dot indicator when [activeFilterCount] > 0
/// so the user knows non-default filters are active even after the sheet
/// is dismissed.
class DocumentsHeroHeader extends StatelessWidget {
  final List<ExpiryItem> items;
  final UrgencySnapshot urgency;
  final int visibleCount;
  final bool hasActiveFilters;

  /// Whether the inline search field is currently expanded.
  final bool isSearching;

  /// Current inline search query text.
  final String query;

  /// Called when the user types in the inline search field.
  final ValueChanged<String> onQueryChanged;

  /// Toggle the inline search field open or closed.
  final VoidCallback onSearchToggle;

  /// Number of non-default filters active (status ≠ All, type ≠ null).
  final int activeFilterCount;

  final VoidCallback onFilterTap;
  final VoidCallback onSortTap;
  final Future<void> Function() onAddTap;

  /// Called when the user taps "Clear" to reset all filters.
  final VoidCallback? onClearFilters;

  const DocumentsHeroHeader({
    super.key,
    required this.items,
    required this.urgency,
    required this.visibleCount,
    required this.hasActiveFilters,
    required this.isSearching,
    required this.query,
    required this.onQueryChanged,
    required this.onSearchToggle,
    required this.activeFilterCount,
    required this.onFilterTap,
    required this.onSortTap,
    required this.onAddTap,
    this.onClearFilters,
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Row / Inline Search ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: isSearching
                ? _buildSearchRow(context, theme, fade)
                : _buildTitleRow(context, theme, fade),
          ),

          if (!isSearching) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: fade.color(
                        FinavigColors.textSecondaryLight,
                        FinavigColors.textSecondary,
                      ),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasActiveFilters && onClearFilters != null)
                  TextButton(
                    onPressed: onClearFilters,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          // Action pills: filter + sort, then the primary Add pill.
          Row(
            children: [
              _FilterPill(activeCount: activeFilterCount, onTap: onFilterTap),
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

  /// Default: title + AI + search icon.
  Widget _buildTitleRow(
    BuildContext context,
    ThemeData theme,
    FinavigTransition fade,
  ) {
    return Row(
      key: const ValueKey('title'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DOCUMENT VAULT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Documents',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  FinavigColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        // Ask Finavig AI: universal voice/text add (money or docs).
        CanvasIconButton(
          icon: Icons.auto_awesome_rounded,
          tooltip: 'Ask Finavig AI',
          onTap: () => AskFinavigSheet.show(context),
        ),
        const SizedBox(width: 8),
        CanvasIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search documents',
          onTap: onSearchToggle,
        ),
      ],
    );
  }

  /// Expanded: inline search field with cancel.
  Widget _buildSearchRow(
    BuildContext context,
    ThemeData theme,
    FinavigTransition fade,
  ) {
    final radius = BorderRadius.circular(16);
    return Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              autofocus: true,
              onChanged: onQueryChanged,
              style: TextStyle(
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  FinavigColors.textPrimary,
                ),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search documents…',
                hintStyle: TextStyle(
                  color: fade.color(
                    FinavigColors.textMutedLight,
                    FinavigColors.textMuted,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
                ),
                filled: true,
                fillColor: fade.color(FinavigColors.cloud, FinavigColors.slate),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: fade.color(
                      FinavigColors.fog,
                      FinavigColors.slateLight,
                    ),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: fade.color(
                      FinavigColors.fog,
                      FinavigColors.slateLight,
                    ),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSearchToggle,
          child: Text(
            'Cancel',
            style: TextStyle(
              color: fade.color(
                FinavigColors.textPrimaryLight,
                FinavigColors.textPrimary,
              ),
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter pill with a dot indicator when filters are active.
class _FilterPill extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterPill({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final bg = fade.color(FinavigColors.cloud, FinavigColors.slate);
    final fg = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );
    final side = BorderSide(
      color: fade.color(FinavigColors.fog, FinavigColors.slateLight),
      width: 1,
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_rounded, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E8BC0), Color(0xFF1B5A8A)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill action on the Documents canvas: a hairline-outlined chip by default,
/// or a solid gradient chip when [filled].
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
    final foreground = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );

    if (filled) {
      // Primary Action Pill ("Add"): Luxury logo-blue gradient
      return Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E8BC0), Color(0xFF1B5A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E8BC0).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Default Pill ("Sort"): subtle canvas-colored control.
    return Material(
      color: fade.color(FinavigColors.cloud, FinavigColors.slate),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: fade.color(FinavigColors.fog, FinavigColors.slateLight),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
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
