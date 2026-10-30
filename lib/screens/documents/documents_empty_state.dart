import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/indicators/empty_state_illustration.dart';

/// Empty state for the Documents tab's document ledger.
///
/// Displays contextual artwork, guidance, and primary actions for both
/// empty filter searches and initial onboarding states.
class DocumentsEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onAddFirst;
  final VoidCallback? onTryDemo;

  const DocumentsEmptyState({
    super.key,
    this.hasActiveFilters = false,
    this.onClearFilters,
    this.onAddFirst,
    this.onTryDemo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final muted = fade.color(
      FinavigColors.textMutedLight,
      FinavigColors.textMuted,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateIllustration(
              scene: hasActiveFilters
                  ? EmptyStateScene.search
                  : EmptyStateScene.document,
              size: 110,
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters ? 'No documents match' : 'Nothing tracked yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  FinavigColors.textPrimary,
                ),
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                hasActiveFilters
                    ? 'No documents found for your current filter or search criteria.'
                    : 'Scan a trade licence, visa, passport or Ejari to start tracking its expiry.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            if (!hasActiveFilters) ...[
              FilledButton.icon(
                onPressed: onAddFirst,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add first document'),
                style: FilledButton.styleFrom(
                  backgroundColor: fade.color(FinavigColors.ink, Colors.white),
                  foregroundColor: fade.color(Colors.white, FinavigColors.ink),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onTryDemo,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Try a demo document'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ] else ...[
              FilledButton.tonalIcon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear all filters'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
