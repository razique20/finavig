import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/expiry_item.dart';
import '../../models/subscription_tier.dart';
import '../../services/companion_document_factory.dart';
import '../../services/companion_suggestion_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import 'upgrade_dialog.dart';


/// Bottom sheet shown after a document is added, suggesting related document
/// types from the same UAE companion pool that the user does not track yet.
///
/// Returns the list of types the user chose to add (empty when dismissed).
class CompanionSuggestionSheet extends StatefulWidget {
  /// The type of the document the user just added.
  final DocumentType addedType;

  /// Name shown in the header, e.g. the new document's title.
  final String addedName;

  /// Doc-type keys of the user's currently tracked documents.
  final Set<String> trackedTypeKeys;

  /// The root navigator context that presented this sheet.
  ///
  /// Stored so the sheet’s dismissal controls can always close the modal
  /// reliably, even when the sheet is opened on top of another sheet/dialog.
  final BuildContext rootNavigatorContext;

  const CompanionSuggestionSheet({
    super.key,
    required this.addedType,
    required this.addedName,
    required this.trackedTypeKeys,
    required this.rootNavigatorContext,
  });

  /// Opens the sheet and returns the picked types (empty list on dismiss).
  ///
  /// The returned [context] is the root navigator context that actually owns
  /// the modal, so the sheet’s dismissal buttons can always pop the right
  /// stack even when the sheet is opened on top of another modal/overlay.
  static Future<List<DocumentType>> show(
    BuildContext context, {
    required DocumentType addedType,
    required String addedName,
    required Set<String> trackedTypeKeys,
  }) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final picked = await showModalBottomSheet<List<DocumentType>>(
      context: rootNavigator.context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => CompanionSuggestionSheet(
        addedType: addedType,
        addedName: addedName,
        trackedTypeKeys: trackedTypeKeys,
        rootNavigatorContext: rootNavigator.context,
      ),
    );
    return picked ?? const [];
  }

  /// Evaluates whether [newItem] has companion document suggestions available,
  /// and if so, shows the [CompanionSuggestionSheet] bottom modal on the root navigator.
  static Future<void> maybeSuggestCompanions(
    BuildContext context,
    ExpiryItem newItem,
  ) async {
    if (newItem.docType.builtinEnum == null) return;
    try {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final tracked = await DocumentScannerService.instance.getAllItems();
      final suggestions = CompanionSuggestionService.instance.suggestionsFor(
        newItem.docType.builtinEnum!,
        tracked.map((i) => i.docType.key).toSet(),
      );
      if (suggestions.isEmpty) return;

      // The root navigator owns this sheet. Use its current context for all
      // post-selection UI so dismissal/pickouts cannot walk into a stale overlay.
      final addedType = newItem.docType.builtinEnum!;
      final addedName = newItem.displayName;
      final trackedTypeKeys =
          tracked.map((i) => i.docType.key).toSet();

      // Surface a pending companion cue before the modal is shown, so the
      // header badge/dot reflects that a suggestion is waiting for the user.
      PendingCompanionAlertService.instance.signal(
        PendingCompanionAlert(
          addedType: addedType,
          addedName: addedName,
          suggestions: suggestions,
          createdAt: DateTime.now(),
        ),
      );

      final picked = await show(
        rootNavigator.context,
        addedType: addedType,
        addedName: addedName,
        trackedTypeKeys: trackedTypeKeys,
      );
      if (picked.isEmpty) return;

      var added = 0;
      for (final type in picked) {
        // Track 1 gate: stop (and paywall) when the Free document quota is
        // exhausted mid-batch.
        final used = await EntitlementService.instance.documentsInUse();
        if (!EntitlementService.instance.canAddDocuments(used)) {
          if (!rootNavigator.mounted) break;
          await showUpgradeDialog(
            rootNavigator.context,
            EntitlementFeature.moreDocuments,
          );
          break;
        }
        await DocumentScannerService.instance.addItem(
          buildCompanionItem(
            type: type,
            collectionId: newItem.collectionId,
            anchoredToName: newItem.displayName,
          ),
        );
        added++;
      }

      if (added > 0 && rootNavigator.mounted) {
          final messenger = ScaffoldMessenger.maybeOf(rootNavigator.context);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(
                '$added related document${added == 1 ? '' : 's'} added ✓',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
    } finally {
      // Clear the pending cue whenever the suggestion flow resolves:
      // either the user picked something (added > 0), or the sheet was
      // dismissed without adding anything.
      PendingCompanionAlertService.instance.clear();
    }
  }

  @override
  State<CompanionSuggestionSheet> createState() =>
      _CompanionSuggestionSheetState();
}

class _CompanionSuggestionSheetState extends State<CompanionSuggestionSheet> {
  final Set<DocumentType> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = CompanionSuggestionService.instance.suggestionsFor(
      widget.addedType,
      widget.trackedTypeKeys,
    );

    // Nothing to suggest — do not show an empty sheet.
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final pools = suggestions.map((s) => s.poolName).toSet();
    final fade = FinavigTransition.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle at top
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fade.color(
                    const Color(0xFFE2E5EC),
                    Colors.white.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: lightbulb icon + question + hint.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add related documents?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Businesses tracking a ${_typeName(widget.addedType)} '
                        'usually also track:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lazy builder over a flattened pool-header/item index: only the
            // visible portion of the suggestion list is built.
            Flexible(
              child: Builder(
                builder: (_) {
                  final flat = <Widget>[];
                  for (final poolName in pools) {
                    flat.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(
                          poolName.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    );
                    for (final s in suggestions.where(
                      (s) => s.poolName == poolName,
                    )) {
                      flat.add(
                        _SuggestionTile(
                          suggestion: s,
                          selected: _selected.contains(s.type),
                          onToggle: () => setState(() {
                            if (!_selected.remove(s.type)) {
                              _selected.add(s.type);
                            }
                          }),
                        ),
                      );
                    }
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: flat.length,
                    itemBuilder: (_, index) => flat[index],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Action row: cancel or add the selected companions.
            //
            // Both branches return a List<DocumentType> so the pop matches the
            // modal's typed result (ModalBottomSheetRoute<List<DocumentType>>).
            // Popping with the untyped empty list was throwing a route-result
            // type mismatch and could leave the sheet looking “frozen”.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(
                        widget.rootNavigatorContext,
                        rootNavigator: true,
                      ).pop(<DocumentType>[]);
                    },
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(
                          widget.rootNavigatorContext,
                          rootNavigator: true,
                        ).pop(_selected.toList()),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      _selected.isEmpty
                          ? 'Add selected'
                          : 'Add ${_selected.length} document'
                              '${_selected.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  String _typeName(DocumentType type) =>
      DocumentTypeRegistry.instance.byEnum(type).displayName.toLowerCase();
}

/// One tappable suggestion row with the type's icon/color, name and reason.
class _SuggestionTile extends StatelessWidget {
  final CompanionSuggestion suggestion;
  final bool selected;
  final VoidCallback onToggle;

  const _SuggestionTile({
    required this.suggestion,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = suggestion.meta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? meta.primaryColor
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? meta.primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: meta.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, color: meta.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? meta.primaryColor
                    : FinavigColors.adaptiveIcon(
                        context,
                        theme.colorScheme.outline,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
