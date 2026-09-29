import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/expiry_item.dart';
import '../../services/urgency_engine.dart';
import '../../widgets/hero_widgets.dart';
import '../../widgets/dialogs/ask_finavig_sheet.dart';

/// Compact navy hero of the Documents tab: title, Ask Finavig AI + global
/// search buttons, a live status line that doubles as filter feedback
/// ("2 expired · 12 of 30 shown"), and the Filter/Sort/Add action pills.
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
    final pending = urgency.pendingActions.length;
    final expired = items.where((i) => i.isActive && i.isExpired).length;

    // Compact hero (deliberately smaller than Home's): one status line that
    // doubles as the filter feedback — "shown" only appears while filters
    // narrow the list.
    final statusPart = expired > 0
        ? '$expired expired'
        : pending > 0
            ? '$pending need attention'
            : 'All on track';
    final scopePart = hasActiveFilters
        ? '$visibleCount of ${items.length} shown'
        : '${items.length} tracked';
    final subtitle = '$statusPart · $scopePart';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Documents',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Ask Finavig AI: universal voice/text add (money or docs).
              HeroIconButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'Ask FV AI',
                onTap: () => AskFinavigSheet.show(context),
              ),
              const SizedBox(width: 8),
              HeroIconButton(
                icon: Icons.saved_search_rounded,
                tooltip: 'Search all documents',
                onTap: () => context.push('/search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Single-line live status + scope.
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Action pills: filter + sort, mirroring Home's Record/Budget row.
          Row(
            children: [
              HeroActionPill(
                icon: Icons.filter_alt_rounded,
                label: 'Filter',
                outlined: true,
                onTap: onFilterTap,
              ),
              const SizedBox(width: 10),
              HeroActionPill(
                icon: Icons.sort_rounded,
                label: 'Sort',
                outlined: true,
                onTap: onSortTap,
              ),
              const Spacer(),
              HeroActionPill(
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
