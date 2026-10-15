import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/indicators/empty_state_illustration.dart';

/// Empty state for the Documents tab's document ledger.
///
/// A single centered column keeps the "Nothing tracked yet" flow aligned to
/// the middle of the canvas: document icon, the heading and subtitle, then the
/// first-scan and demo CTAs.
class DocumentsEmptyState extends StatelessWidget {
  final bool hasActiveFilters;

  const DocumentsEmptyState({super.key, this.hasActiveFilters = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final muted = fade.color(
      FinavigColors.textMutedLight,
      FinavigColors.textMuted,
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyStateIllustration(
            scene: hasActiveFilters
                ? EmptyStateScene.search
                : EmptyStateScene.document,
            size: 104,
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveFilters ? 'No documents match' : 'Nothing tracked yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: fade.color(
                FinavigColors.textPrimaryLight,
                FinavigColors.textPrimary,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasActiveFilters
                ? 'Try a different filter or clear the search.'
                : 'Scan a trade licence, visa or Ejari to start tracking its expiry.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!hasActiveFilters) ...[
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add first document'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Try a demo document'),
            ),
          ] else
            TextButton(
              onPressed: () {},
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }
}