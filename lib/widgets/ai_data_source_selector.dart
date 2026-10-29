import 'package:flutter/material.dart';

import '../models/ai_data_source.dart';

/// Shared source selector used before generating AI summaries and plans.
class AiDataSourceSelector extends StatelessWidget {
  const AiDataSourceSelector({
    super.key,
    required this.selectedSources,
    required this.onChanged,
    this.requiredSources = const {},
    this.description = 'Choose which summarized data can inform this response.',
  });

  final Set<AiDataSource> selectedSources;
  final ValueChanged<Set<AiDataSource>> onChanged;
  final Set<AiDataSource> requiredSources;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Data used for this response',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                '$description Only affects the next generated response.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final source in AiDataSource.values)
              CheckboxListTile(
                key: ValueKey('ai-source-${source.name}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(source.label),
                subtitle: Text(
                  requiredSources.contains(source)
                      ? '${source.description} (required for an accurate plan)'
                      : selectedSources.length == 1 &&
                            selectedSources.contains(source)
                      ? '${source.description} (select at least one source)'
                      : source.description,
                ),
                value: selectedSources.contains(source),
                onChanged:
                    requiredSources.contains(source) ||
                        (selectedSources.length == 1 &&
                            selectedSources.contains(source))
                    ? null
                    : (checked) {
                        final next = Set<AiDataSource>.of(selectedSources);
                        if (checked == true) {
                          next.add(source);
                        } else {
                          next.remove(source);
                        }
                        onChanged(next);
                      },
              ),
          ],
        ),
      ),
    );
  }
}
