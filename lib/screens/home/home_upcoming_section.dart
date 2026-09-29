import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/demo_document_service.dart';

import '../../models/expiry_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/indicators/empty_state_illustration.dart';

/// "Next renewals · N" section of the Home tab — the 3 nearest upcoming
/// documents with the full list behind "View all" (Expiry List screen).
class HomeUpcomingSection extends StatelessWidget {
  final List<ExpiryItem> upcomingItems;

  const HomeUpcomingSection({super.key, required this.upcomingItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = upcomingItems;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next renewals · ${upcoming.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (upcoming.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/expiry-list'),
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const HomeEmptyState()
          else
            ...upcoming
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: HomeUpcomingTile(item: item),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Empty state for the upcoming-renewals section.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(scene: EmptyStateScene.document, size: 104),
          const SizedBox(height: 12),
          Text(
            'Nothing tracked yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a trade licence, visa or Ejari to start tracking its expiry.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await DemoDocumentService.instance.addDemoDocument();
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Try a demo document'),
          ),
        ],
      ),
    );
  }
}

/// One upcoming-renewal row: doc-type icon, name, expiry date and a
/// colour-coded days-remaining counter (red ≤7d, amber ≤30d, green beyond).
class HomeUpcomingTile extends StatelessWidget {
  final ExpiryItem item;

  const HomeUpcomingTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = item.daysRemaining <= 7;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/document/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCritical
                      ? Colors.red.withOpacity(0.12)
                      : theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    item.docType.icon,
                    color: isCritical ? Colors.red : theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.docType.displayName} • ${item.expiresAt.day}/${item.expiresAt.month}/${item.expiresAt.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.daysRemaining}d',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCritical
                      ? FinavigColors.danger
                      : item.daysRemaining <= 30
                          ? FinavigColors.warning
                          : FinavigColors.safe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
