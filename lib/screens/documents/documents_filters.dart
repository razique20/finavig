import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/gcc_country.dart';
import '../../services/collection_service.dart';
import '../../theme/app_theme.dart';

/// Status filter buckets for the Documents tab.
enum DocFilter { all, critical, upcoming, later, expired }

/// Sort orders for the Documents tab.
enum DocSort { dueDate, urgency, name, fee }

extension DocSortX on DocSort {
  String get label {
    switch (this) {
      case DocSort.dueDate:
        return 'Due date';
      case DocSort.urgency:
        return 'Urgency';
      case DocSort.name:
        return 'Name';
      case DocSort.fee:
        return 'Renewal fee';
    }
  }

  IconData get icon {
    switch (this) {
      case DocSort.dueDate:
        return Icons.event_rounded;
      case DocSort.urgency:
        return Icons.event_busy_rounded;
      case DocSort.name:
        return Icons.sort_by_alpha_rounded;
      case DocSort.fee:
        return Icons.payments_rounded;
    }
  }
}

/// Inline search field at the top of the Documents workspace — a soft pill
/// on the canvas, matching the chip language of the rest of the page.
class DocumentsSearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const DocumentsSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final radius = BorderRadius.circular(24);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
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
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: fade.color(
                      FinavigColors.textSecondaryLight,
                      FinavigColors.textSecondary,
                    ),
                  ),
                  onPressed: () => onChanged(''),
                ),
          filled: true,
          fillColor: fade.color(
            FinavigColors.cloud,
            FinavigColors.slate.withValues(alpha: 0.55),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: fade.color(FinavigColors.ink, Colors.white),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of status filter chips (All / Critical / ≤30 days /
/// Later / Expired) with live counts.
class DocumentsStatusChips extends StatelessWidget {
  final DocFilter selected;
  final int allCount;
  final int criticalCount;
  final int upcomingCount;
  final int laterCount;
  final int expiredCount;
  final ValueChanged<DocFilter> onSelected;

  const DocumentsStatusChips({
    super.key,
    required this.selected,
    required this.allCount,
    required this.criticalCount,
    required this.upcomingCount,
    required this.laterCount,
    required this.expiredCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(theme, fade, 'All', DocFilter.all, allCount),
          _chip(theme, fade, 'Critical', DocFilter.critical, criticalCount),
          _chip(theme, fade, '≤30 days', DocFilter.upcoming, upcomingCount),
          _chip(theme, fade, 'Later', DocFilter.later, laterCount),
          _chip(theme, fade, 'Expired', DocFilter.expired, expiredCount),
        ],
      ),
    );
  }

  /// Pill chip: solid ink (light) / solid white (dark) while selected, and a
  /// hairline-outlined ghost otherwise — the same chip language as the
  /// header pills, so a selected filter always reads as the strongest mark.
  Widget _chip(
    ThemeData theme,
    FinavigTransition fade,
    String label,
    DocFilter filter,
    int count,
  ) {
    final isSelected = selected == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected
                ? fade.color(Colors.white, FinavigColors.ink)
                : fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(filter),
        showCheckmark: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: Colors.transparent,
        selectedColor: fade.color(FinavigColors.ink, Colors.white),
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : fade.color(
                    FinavigColors.fog,
                    Colors.white.withValues(alpha: 0.14),
                  ),
          ),
        ),
      ),
    );
  }
}

/// One-line summary of the active filters, with a clear action.
class DocumentsActiveFiltersRow extends StatelessWidget {
  final String query;
  final DocumentTypeMeta? typeFilter;
  final DocFilter filter;
  final String? folderName;
  final GccCountry? country;
  final VoidCallback onClear;

  const DocumentsActiveFiltersRow({
    super.key,
    required this.query,
    required this.typeFilter,
    required this.filter,
    this.folderName,
    this.country,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final activeCountry =
        country ?? DocumentCollectionService.instance.activeCountry;
    final accent = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );
    final parts = <String>[
      if (folderName != null) '📁 $folderName',
      if (query.isNotEmpty) '"${query.trim()}"',
      if (typeFilter != null) typeFilter!.localizedDisplayName(activeCountry),
      if (filter != DocFilter.all)
        switch (filter) {
          DocFilter.all => '',
          DocFilter.critical => 'Critical',
          DocFilter.upcoming => '≤30 days',
          DocFilter.later => 'Later',
          DocFilter.expired => 'Expired',
        },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 14,
            color: fade.color(
              FinavigColors.textMutedLight,
              FinavigColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered: ${parts.where((p) => p.isNotEmpty).join(' · ')}',
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
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the unified document filter sheet.
class DocumentsFilterResult {
  final DocFilter status;
  final DocumentTypeMeta? type;

  const DocumentsFilterResult({required this.status, this.type});
}

Widget _sheetStatusChip(
  ThemeData theme,
  FinavigTransition fade,
  String label,
  DocFilter filter,
  int count,
  DocFilter selected,
  ValueChanged<DocFilter> onSelected,
) {
  final isSelected = selected == filter;
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          color: isSelected
              ? fade.color(Colors.white, FinavigColors.ink)
              : fade.color(
                  FinavigColors.textSecondaryLight,
                  FinavigColors.textSecondary,
                ),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(filter),
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: Colors.transparent,
      selectedColor: fade.color(FinavigColors.ink, Colors.white),
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : fade.color(
                  FinavigColors.fog,
                  Colors.white.withValues(alpha: 0.14),
                ),
        ),
      ),
    ),
  );
}

/// Opens the unified filter bottom sheet (Status + Document Type).
/// Resolves to [DocumentsFilterResult] when applied, or null when dismissed.
Future<DocumentsFilterResult?> showDocumentsFilterSheet({
  required BuildContext context,
  required DocFilter currentStatus,
  required DocumentTypeMeta? currentType,
  GccCountry? country,
  int allCount = 0,
  int criticalCount = 0,
  int upcomingCount = 0,
  int laterCount = 0,
  int expiredCount = 0,
}) {
  final theme = Theme.of(context);
  final fade = FinavigTransition.of(context);
  final activeCountry =
      country ?? DocumentCollectionService.instance.activeCountry;

  var selectedStatus = currentStatus;
  DocumentTypeMeta? selectedType = currentType;

  return showModalBottomSheet<DocumentsFilterResult>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final hasActive =
            selectedStatus != DocFilter.all || selectedType != null;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Filter documents',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      if (hasActive)
                        GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              selectedStatus = DocFilter.all;
                              selectedType = null;
                            });
                          },
                          child: Text(
                            'Reset',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shrinkWrap: true,
                    children: [
                      // Status Section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Text(
                          'STATUS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _sheetStatusChip(
                              theme,
                              fade,
                              'All',
                              DocFilter.all,
                              allCount,
                              selectedStatus,
                              (f) => setSheetState(() => selectedStatus = f),
                            ),
                            _sheetStatusChip(
                              theme,
                              fade,
                              'Critical',
                              DocFilter.critical,
                              criticalCount,
                              selectedStatus,
                              (f) => setSheetState(() => selectedStatus = f),
                            ),
                            _sheetStatusChip(
                              theme,
                              fade,
                              '≤30 days',
                              DocFilter.upcoming,
                              upcomingCount,
                              selectedStatus,
                              (f) => setSheetState(() => selectedStatus = f),
                            ),
                            _sheetStatusChip(
                              theme,
                              fade,
                              'Later',
                              DocFilter.later,
                              laterCount,
                              selectedStatus,
                              (f) => setSheetState(() => selectedStatus = f),
                            ),
                            _sheetStatusChip(
                              theme,
                              fade,
                              'Expired',
                              DocFilter.expired,
                              expiredCount,
                              selectedStatus,
                              (f) => setSheetState(() => selectedStatus = f),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Type Section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'DOCUMENT TYPE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fade.color(
                                  FinavigColors.textMutedLight,
                                  FinavigColors.textMuted,
                                ),
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: fade.color(
                                  FinavigColors.cloud,
                                  FinavigColors.slate.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${activeCountry.flag} ${activeCountry.displayName}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: fade.color(
                                    FinavigColors.textSecondaryLight,
                                    FinavigColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.apps_rounded),
                        title: const Text('All types'),
                        trailing: selectedType == null
                            ? Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => setSheetState(() => selectedType = null),
                      ),
                      for (final t
                          in DocumentTypeRegistry.instance.typesForPicker)
                        Builder(
                          builder: (ctx) {
                            final localizedName = t.localizedDisplayName(
                              activeCountry,
                            );
                            final alias = t.builtinEnum?.localizedPickerAlias(
                              activeCountry,
                            );
                            final subtitle =
                                (alias != null &&
                                    alias != localizedName &&
                                    alias != t.displayName)
                                ? alias
                                : null;

                            return ListTile(
                              leading: Icon(t.icon, color: t.primaryColor),
                              title: Text(localizedName),
                              subtitle: subtitle != null
                                  ? Text(
                                      subtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: fade.color(
                                              FinavigColors.textMutedLight,
                                              FinavigColors.textMuted,
                                            ),
                                          ),
                                    )
                                  : null,
                              trailing: selectedType?.key == t.key
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () =>
                                  setSheetState(() => selectedType = t),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                        DocumentsFilterResult(
                          status: selectedStatus,
                          type: selectedType,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fade.color(
                        FinavigColors.ink,
                        Colors.white,
                      ),
                      foregroundColor: fade.color(
                        Colors.white,
                        FinavigColors.ink,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Opens the document-type filter bottom sheet. Resolves to the selected
/// type key, `'__all__'`, or null when dismissed.
Future<String?> showDocumentsTypeFilterSheet(
  BuildContext context, [
  GccCountry? country,
]) {
  final theme = Theme.of(context);
  final activeCountry =
      country ?? DocumentCollectionService.instance.activeCountry;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Document type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              // Lazy builder: only the visible type rows are built & laid out.
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:
                    DocumentTypeRegistry.instance.typesForPicker.length + 1,
                itemBuilder: (sheetContext, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.apps_rounded),
                      title: const Text('All types'),
                      onTap: () => Navigator.pop(sheetContext, '__all__'),
                    );
                  }
                  final t =
                      DocumentTypeRegistry.instance.typesForPicker[index - 1];
                  return ListTile(
                    leading: Icon(t.icon, color: t.primaryColor),
                    title: Text(t.localizedDisplayName(activeCountry)),
                    onTap: () => Navigator.pop(sheetContext, t.key),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Opens the sort-order bottom sheet. Resolves to the chosen [DocSort] or
/// null when dismissed.
Future<DocSort?> showDocumentsSortSheet(BuildContext context, DocSort current) {
  final theme = Theme.of(context);
  return showModalBottomSheet<DocSort>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sort by',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final s in DocSort.values)
            ListTile(
              leading: Icon(
                s.icon,
                color: current == s
                    ? theme.colorScheme.primary
                    : FinavigColors.adaptiveIcon(
                        context,
                        theme.colorScheme.outline,
                      ),
              ),
              title: Text(s.label),
              trailing: current == s
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(sheetContext, s),
            ),
        ],
      ),
    ),
  );
}
