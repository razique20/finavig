import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/demo_document_service.dart';
import '../services/document_scanner_service.dart';
import '../services/tab_scroll_registry.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/shimmer_skeleton.dart';
import 'documents/document_action_sheets.dart';
import 'documents/document_card.dart';
import 'documents/documents_filters.dart';
import 'documents/documents_hero_header.dart';
import 'documents/documents_insights_section.dart';

/// Documents tab (Tier 1): the full expiry-tracking workspace.
///
/// Same anatomy as the redesigned Home tab: a navy hero header carrying the
/// greeting, a live count, and the primary actions; below it a rounded
/// content sheet with the search field, filter chips, compact insight tiles,
/// and the document cards. The heavy lifting lives in `lib/screens/documents/`
/// modules so each section rebuilds independently.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  // Root scrollable of this tab — registered so a bottom-nav tap scrolls
  // the tab back to the top (see TabScrollRegistry).
  final ScrollController _scrollController = ScrollController();

  List<ExpiryItem> _items = [];
  bool _loading = true;
  String _query = '';
  DocFilter _filter = DocFilter.all;
  DocSort _sort = DocSort.dueDate;
  DocumentTypeMeta? _typeFilter;

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(2, _scrollController);
    if (DocumentScannerService.instance.isInitialized) {
      _items = DocumentScannerService.instance.activeItems;
      _loading = false;
    }
    _loadData();
    DocumentScannerService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(2, _scrollController);
    _scrollController.dispose();
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadData();
  }

  Future<void> _loadData() async {
    // Include expired documents so the "Expired" filter and the header can
    // show documents that already lapsed.
    final items = await DocumentScannerService().getAllItems(
      includeExpired: true,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
      _prewarmThumbnails();
    }
  }

  /// Pre-warms downsampled thumbnails for the first image attachments so
  /// scrolling between scans never stalls on the first decode. Bounded to
  /// keep IO and memory predictable; further rows warm on detail open.
  void _prewarmThumbnails() {
    const maxPrewarms = 24;
    var warmed = 0;
    for (final item in _items) {
      if (warmed >= maxPrewarms) break;
      final path = item.filePath;
      if (path == null || path.isEmpty) continue;
      final isNetwork =
          path.startsWith('http://') || path.startsWith('https://');
      final lower = path.toLowerCase();
      final isImage =
          lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp') ||
          lower.contains('.gif') ||
          lower.contains('.heic');
      if (!isImage) continue;
      unawaited(
        prewarmAttachmentImage(
          context,
          path,
          isNetwork: isNetwork,
          targetWidth: 96,
        ),
      );
      warmed++;
    }
  }

  List<ExpiryItem> get _filtered {
    final now = DateTime.now();
    final list = _items.where((i) {
      if (!i.isActive && !i.isExpired) return false;
      if (_query.isNotEmpty &&
          !i.displayName.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_typeFilter != null && i.docType.key != _typeFilter!.key) {
        return false;
      }
      switch (_filter) {
        case DocFilter.all:
          return true;
        case DocFilter.critical:
          return i.daysRemaining <= 7;
        case DocFilter.upcoming:
          return i.daysRemaining > 7 && i.daysRemaining <= 30;
        case DocFilter.later:
          return i.daysRemaining > 30;
        case DocFilter.expired:
          return i.expiresAt.isBefore(now) || i.daysRemaining < 0;
      }
    }).toList();

    switch (_sort) {
      case DocSort.dueDate:
        list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      case DocSort.urgency:
        list.sort((a, b) {
          final byPriority = b.urgency.priority.compareTo(a.urgency.priority);
          if (byPriority != 0) return byPriority;
          return a.expiresAt.compareTo(b.expiresAt);
        });
      case DocSort.name:
        list.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ),
        );
      case DocSort.fee:
        list.sort((a, b) {
          final aFee = a.renewalFee ?? 0;
          final bFee = b.renewalFee ?? 0;
          if (bFee != aFee) return bFee.compareTo(aFee);
          return a.expiresAt.compareTo(b.expiresAt);
        });
    }
    return list;
  }

  /// Nearest upcoming document — shown in the insights tiles.
  ExpiryItem? get _nextDue {
    final now = DateTime.now();
    final active =
        _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return active.isEmpty ? null : active.first;
  }

  double get _totalUpcomingFees {
    final now = DateTime.now();
    return _items
        .where(
          (i) =>
              i.isActive && i.expiresAt.isAfter(now) && (i.renewalFee ?? 0) > 0,
        )
        .fold(0.0, (sum, i) => sum + i.renewalFee!);
  }

  bool get _hasActiveFilters =>
      _filter != DocFilter.all || _typeFilter != null || _query.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _filter = DocFilter.all;
      _typeFilter = null;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      // Same backdrop colors as the redesigned Home tab.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: DocumentsHeroHeader(
                  items: _items,
                  urgency: urgency,
                  visibleCount: filtered.length,
                  hasActiveFilters: _hasActiveFilters,
                  onFilterTap: _showTypeFilterSheet,
                  onSortTap: _showSortSheet,
                  onAddTap: _openScanner,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? DocumentsSkeletonView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            // Inline search field, styled like the tiles.
                            DocumentsSearchField(
                              query: _query,
                              onChanged: (v) => setState(() => _query = v),
                            ),
                            const SizedBox(height: 12),
                            // Status filter chips.
                            DocumentsStatusChips(
                              selected: _filter,
                              allCount: _items
                                  .where((i) => i.isActive || i.isExpired)
                                  .length,
                              criticalCount: urgency.criticalCount,
                              upcomingCount: urgency.highCount,
                              laterCount:
                                  urgency.mediumCount + urgency.lowCount,
                              expiredCount: _items
                                  .where((i) => !i.isActive && i.isExpired)
                                  .length,
                              onSelected: (f) => setState(() => _filter = f),
                            ),
                            // Active-filter summary: visible only when it
                            // matters, so the sheet never shows a phantom gap.
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 8),
                              DocumentsActiveFiltersRow(
                                query: _query,
                                typeFilter: _typeFilter,
                                filter: _filter,
                                onClear: _clearFilters,
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Insight tiles: what the list means at a glance.
                            DocumentsInsightsSection(
                              nextDue: _nextDue,
                              totalUpcomingFees: _totalUpcomingFees,
                            ),
                            const SizedBox(height: 16),
                            // Document list.
                            _buildDocumentList(theme, filtered),
                            // Keep the last card scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height: 8 +
                                  MediaQuery.of(context).padding.bottom +
                                  80,
                            ),
                          ],
                        ),
                ),
              ),
              // White filler: extends the sheet across the rest of the
              // viewport when content is short, and into overscroll —
              // the navy backdrop never peeks out below the content,
              // behind the floating nav pill.
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: ColoredBox(color: theme.colorScheme.surface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Document list — compact cards, tinted left accent by urgency
  // ------------------------------------------------------------------

  Widget _buildDocumentList(ThemeData theme, List<ExpiryItem> filtered) {
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEmptyState(theme),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final item in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DocumentCard(
                item: item,
                onTap: () async {
                  await context.push('/document/${item.id}');
                  await _loadData();
                },
                onAction: () async {
                  await showDocumentActionSheet(
                    context,
                    item,
                    _loadData,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(
            scene: _hasActiveFilters
                ? EmptyStateScene.search
                : EmptyStateScene.document,
            size: 104,
          ),
          const SizedBox(height: 12),
          Text(
            _hasActiveFilters ? 'No documents match' : 'Nothing tracked yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasActiveFilters
                ? 'Try a different filter or clear the search.'
                : 'Scan a trade licence, visa or Ejari to start tracking its expiry.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!_hasActiveFilters) ...[
            FilledButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add first document'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _addDemoDocument,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Try a demo document'),
            ),
          ] else
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  /// Open the scan flow after enforcing the free-tier document limit.
  Future<void> _openScanner() async {
    if (!await enforceDocumentLimit(context)) return;
    if (mounted) await context.push('/scan');
  }

  /// First-run helper: insert one labelled demo document so the user can
  /// explore alerts and the urgency ladder without scanning anything.
  Future<void> _addDemoDocument() async {
    if (!await enforceDocumentLimit(context)) return;
    await DemoDocumentService.instance.addDemoDocument();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo document added — explore alerts & reminders, remove it anytime.',
        ),
      ),
    );
  }

  Future<void> _showTypeFilterSheet() async {
    final value = await showDocumentsTypeFilterSheet(context);
    if (value == null || !mounted) return;
    setState(() {
      _typeFilter = value == '__all__'
          ? null
          : DocumentTypeRegistry.instance.typesForPicker
              .where((t) => t.key == value)
              .firstOrNull;
    });
  }

  Future<void> _showSortSheet() async {
    final value = await showDocumentsSortSheet(context, _sort);
    if (value is DocSort && mounted) setState(() => _sort = value);
  }
}
