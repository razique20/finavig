import 'package:flutter/material.dart';

import '../../models/document_type.dart';
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

/// Inline search field used at the top of the Documents content sheet.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(
          color: isDark
              ? FinavigColors.textPrimary
              : FinavigColors.textPrimaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search documents…',
          hintStyle: TextStyle(
            color: isDark
                ? FinavigColors.textMuted
                : FinavigColors.textMutedLight,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark
                ? FinavigColors.textSecondary
                : FinavigColors.textSecondaryLight,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark
                        ? FinavigColors.textSecondary
                        : FinavigColors.textSecondaryLight,
                  ),
                  onPressed: () => onChanged(''),
                ),
          filled: true,
          fillColor: isDark
              ? FinavigColors.slate.withOpacity(0.55)
              : FinavigColors.cloud,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.field),
            borderSide: BorderSide.none,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(theme, 'All', DocFilter.all, allCount),
          _chip(theme, 'Critical', DocFilter.critical, criticalCount),
          _chip(theme, '≤30 days', DocFilter.upcoming, upcomingCount),
          _chip(theme, 'Later', DocFilter.later, laterCount),
          _chip(theme, 'Expired', DocFilter.expired, expiredCount),
        ],
      ),
    );
  }

  Widget _chip(
    ThemeData theme,
    String label,
    DocFilter filter,
    int count,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = selected == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected
                ? (isDark
                    ? FinavigColors.cyanSecondary
                    : FinavigColors.navyPrimary)
                : (isDark
                    ? FinavigColors.textSecondary
                    : FinavigColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(filter),
        showCheckmark: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: isDark ? FinavigColors.slate : FinavigColors.cloud,
        selectedColor: isDark
            ? FinavigColors.navyPrimary.withOpacity(0.4)
            : FinavigColors.navyPrimary.withOpacity(0.12),
        side: BorderSide(
          color: isSelected
              ? (isDark
                  ? FinavigColors.cyanSecondary
                  : FinavigColors.navyPrimary)
              : (isDark
                  ? FinavigColors.slateLight.withOpacity(0.3)
                  : FinavigColors.fog),
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
  final VoidCallback onClear;

  const DocumentsActiveFiltersRow({
    super.key,
    required this.query,
    required this.typeFilter,
    required this.filter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (query.isNotEmpty) '"${query.trim()}"',
      if (typeFilter != null) typeFilter!.displayName,
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
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered: ${parts.where((p) => p.isNotEmpty).join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the document-type filter bottom sheet. Resolves to the selected
/// type key, `'__all__'`, or null when dismissed.
Future<String?> showDocumentsTypeFilterSheet(BuildContext context) {
  final theme = Theme.of(context);
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
                color: theme.colorScheme.outline.withOpacity(0.3),
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
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.apps_rounded),
                    title: const Text('All types'),
                    onTap: () => Navigator.pop(sheetContext, '__all__'),
                  ),
                  for (final t in DocumentTypeRegistry.instance.typesForPicker)
                    ListTile(
                      leading: Icon(t.icon, color: t.primaryColor),
                      title: Text(t.displayName),
                      onTap: () => Navigator.pop(sheetContext, t.key),
                    ),
                ],
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
              color: theme.colorScheme.outline.withOpacity(0.3),
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
                    : theme.colorScheme.outline,
              ),
              title: Text(s.label),
              trailing: current == s
                  ? Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(sheetContext, s),
            ),
        ],
      ),
    ),
  );
}
