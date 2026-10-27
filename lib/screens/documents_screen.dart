import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/document_folder.dart';
import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/subscription_tier.dart';
import '../services/collection_service.dart';
import '../services/demo_document_service.dart';
import '../services/document_folder_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/tab_scroll_registry.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/create_folder_dialog.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/documents/folder_list_tile.dart';
import '../widgets/shimmer_skeleton.dart';
import 'documents/document_action_sheets.dart';
import 'documents/documents_empty_state.dart';
import 'documents/document_card.dart';
import 'documents/documents_filters.dart';
import 'documents/documents_hero_header.dart';

/// Documents tab (Tier 1): the full expiry-tracking workspace.
///
/// One flat, airy canvas (no hero band, no rounded content sheet): the header
/// carries the live count and the primary actions, then the search field,
/// filter chips, inline insight stats and the document ledger follow straight
/// down the page. Each document is a row divided by hairlines rather than a
/// white card, so this tab reads as a linear workspace instead of a stack of
/// panels. The heavy lifting lives in `lib/screens/documents/` modules so each
/// section rebuilds independently.
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
  bool _isSearching = false;
  String _query = '';
  DocFilter _filter = DocFilter.all;
  DocSort _sort = DocSort.dueDate;
  DocumentTypeMeta? _typeFilter;
  DocumentFolder? _openFolder;

  /// Latest resolved folder from cache, or null if root or folder was deleted.
  DocumentFolder? get _currentFolder {
    if (_openFolder == null) return null;
    return DocumentFolderService.instance.folderById(_openFolder!.id);
  }

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
    DocumentFolderService.instance.addListener(_onServiceChanged);
    DocumentCollectionService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(2, _scrollController);
    _scrollController.dispose();
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    DocumentFolderService.instance.removeListener(_onServiceChanged);
    DocumentCollectionService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadData();
  }

  Future<void> _loadData() async {
    await DocumentFolderService.instance.init();
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
    final current = _currentFolder;
    final list = _items.where((i) {
      if (!i.isActive && !i.isExpired) return false;
      if (current != null) {
        if (i.folderId != current.id) return false;
      }
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

  bool get _hasActiveFilters =>
      _filter != DocFilter.all || _typeFilter != null || _query.isNotEmpty;

  int get _activeFilterCount =>
      (_filter != DocFilter.all ? 1 : 0) + (_typeFilter != null ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _filter = DocFilter.all;
      _typeFilter = null;
      _query = '';
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);
    final filtered = _filtered;
    final folder = _currentFolder;
    final inFolder = folder != null;
    final activeFolders =
        DocumentFolderService.instance.activeCollectionFolders;

    // Light canvas (matching the redesigned Home, Money and Settings tabs) —
    // the whole tab is drawn directly on it, with no rounded content sheet.
    final canvas = FinavigTransition.of(
      context,
    ).color(FinavigColors.snowWhite, FinavigColors.obsidian);

    return PopScope(
      canPop: !inFolder,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (inFolder) {
          setState(() => _openFolder = null);
        }
      },
      child: Scaffold(
        backgroundColor: canvas,
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
                    isSearching: _isSearching,
                    query: _query,
                    onQueryChanged: (q) => setState(() => _query = q),
                    onSearchToggle: () => setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _query = '';
                    }),
                    activeFilterCount: _activeFilterCount,
                    onFilterTap: () => _showFilterSheet(urgency),
                    onSortTap: _showSortSheet,
                    onAddTap: _openScanner,
                    onClearFilters: _clearFilters,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _loading
                      ? const SizedBox(
                          height: 420,
                          child: DocumentsSkeletonView(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (inFolder) ...[
                              // ── Drill-down Mode (inside a folder) ──
                              _buildFolderBreadcrumbHeader(
                                theme,
                                folder,
                                filtered.length,
                              ),
                              const SizedBox(height: 12),
                              _buildDocumentList(theme, filtered),
                            ] else ...[
                              // ── Root View ──
                              if (_hasActiveFilters) ...[
                                const SizedBox(height: 8),
                                DocumentsActiveFiltersRow(
                                  query: _query,
                                  typeFilter: _typeFilter,
                                  filter: _filter,
                                  folderName: _currentFolder?.name,
                                  country: DocumentCollectionService
                                      .instance.activeCountry,
                                  onClear: _clearFilters,
                                ),
                                const SizedBox(height: 10),
                              ] else ...[
                                const SizedBox(height: 6),
                              ],

                              // When search or filter is active: show direct flat results
                              if (_hasActiveFilters) ...[
                                _buildSectionHeader(
                                  theme,
                                  'Search results',
                                  count: filtered.length,
                                ),
                                _buildDocumentList(theme, filtered),
                              ] else ...[
                                // Normal root state: Folders first (if plan supports or folders exist)
                                if (EntitlementService.instance.allowsCustomFolders ||
                                    activeFolders.isNotEmpty) ...[
                                  _buildFoldersSection(theme, activeFolders),
                                  const SizedBox(height: 18),
                                ],
                                Builder(
                                  builder: (ctx) {
                                    final unassigned = _items
                                        .where((i) =>
                                            (i.folderId == null ||
                                                i.folderId!.isEmpty) &&
                                            (i.isActive || i.isExpired))
                                        .toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionHeader(
                                          theme,
                                          activeFolders.isNotEmpty
                                              ? 'Unassigned'
                                              : 'Tracked',
                                          count: activeFolders.isNotEmpty
                                              ? unassigned.length
                                              : null,
                                        ),
                                        _buildDocumentList(
                                          theme,
                                          activeFolders.isNotEmpty
                                              ? unassigned
                                              : filtered,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
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
                // Canvas filler: extends the background across the rest of the
                // viewport when content is short, and into overscroll — nothing
                // else ever peeks out behind the floating nav pill.
                SliverFillRemaining(
                  hasScrollBody: false,
                  fillOverscroll: true,
                  child: ColoredBox(color: canvas),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Folder UI Components
  // ------------------------------------------------------------------

  Widget _buildFolderBreadcrumbHeader(
    ThemeData theme,
    DocumentFolder folder,
    int count,
  ) {
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: folder.color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: folder.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() => _openFolder = null),
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? FinavigColors.slate : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: folder.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(folder.iconData, color: folder.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count documents',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              ),
            ),
            onPressed: () => _showFolderOptions(context, folder),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateFolder() async {
    final entitlements = EntitlementService.instance;
    final isFree = entitlements.tier == SubscriptionTier.free;
    final maxFolders = entitlements.limits.maxFolders;
    final currentCount =
        DocumentFolderService.instance.activeCollectionFolders.length;
    final atLimit = maxFolders != null && currentCount >= maxFolders;

    if (isFree) {
      await showUpgradeDialog(context, EntitlementFeature.documentFolders);
    } else if (atLimit) {
      await showUpgradeDialog(
        context,
        EntitlementFeature.documentFolders,
        requestedTier: SubscriptionTier.business,
      );
    } else {
      final created = await showCreateFolderDialog(context);
      if (created != null && mounted) {
        setState(() => _openFolder = created);
      }
    }
  }

  Widget _buildFoldersSection(
    ThemeData theme,
    List<DocumentFolder> folders,
  ) {
    final fade = FinavigTransition.of(context);
    final dividerColor = fade.color(
      FinavigColors.fog,
      Colors.white.withValues(alpha: 0.08),
    );

    final entitlements = EntitlementService.instance;
    final isFree = entitlements.tier == SubscriptionTier.free;
    final maxFolders = entitlements.limits.maxFolders;
    final atLimit = maxFolders != null && folders.length >= maxFolders;
    final isLocked = isFree || atLimit;

    final newFolderLink = GestureDetector(
      onTap: _handleCreateFolder,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked
                  ? Icons.lock_outline_rounded
                  : Icons.create_new_folder_outlined,
              size: 14,
              color: isLocked
                  ? Colors.amber.shade700
                  : fade.color(
                      FinavigColors.textPrimaryLight,
                      FinavigColors.textPrimary,
                    ),
            ),
            const SizedBox(width: 4),
            Text(
              'New folder',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isLocked
                    ? Colors.amber.shade700
                    : fade.color(
                        FinavigColors.textPrimaryLight,
                        FinavigColors.textPrimary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          'Folders',
          count: folders.isNotEmpty ? folders.length : null,
          trailing: newFolderLink,
        ),
        for (final folder in folders) ...[
          FolderListTile(
            folder: folder,
            items: _items
                .where((i) =>
                    i.folderId == folder.id && (i.isActive || i.isExpired))
                .toList(),
            onTap: () => setState(() => _openFolder = folder),
            onAction: () => _showFolderOptions(context, folder),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title, {
    int? count,
    Widget? trailing,
  }) {
    final fade = FinavigTransition.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textMuted,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  void _showFolderOptions(BuildContext context, DocumentFolder folder) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: fade.color(Colors.white, FinavigColors.charcoal),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: folder.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(folder.iconData, color: folder.color, size: 20),
                ),
                title: Text(
                  folder.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Folder options'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit folder'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showEditFolderDialog(context, folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete folder',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDeleteFolder(context, folder);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteFolder(BuildContext context, DocumentFolder folder) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text(
          'Documents inside this folder will NOT be deleted. They will simply be moved to Unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_openFolder?.id == folder.id) {
                setState(() => _openFolder = null);
              }
              await DocumentFolderService.instance.deleteFolder(folder.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Document list — a hairline-divided ledger, deliberately card-free
  // ------------------------------------------------------------------

  Widget _buildDocumentList(ThemeData theme, List<ExpiryItem> filtered) {
    if (filtered.isEmpty) {
      if (_currentFolder != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 48,
                  color: theme.colorScheme.outline.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'This folder is empty',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Assign documents to "${_currentFolder!.name}" from the document menu (⋯)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FinavigTransition.of(context).color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEmptyState(theme),
      );
    }

    final dividerColor = FinavigTransition.of(
      context,
    ).color(FinavigColors.fog, Colors.white.withValues(alpha: 0.08));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final entry in filtered.asMap().entries) ...[
            if (entry.key > 0)
              Divider(height: 1, thickness: 1, color: dividerColor),
            DocumentCard(
              item: entry.value,
              onTap: () async {
                await context.push('/document/${entry.value.id}');
                await _loadData();
              },
              onAction: () async {
                await showDocumentActionSheet(context, entry.value, _loadData);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return DocumentsEmptyState(
      hasActiveFilters: _hasActiveFilters,
      onClearFilters: _clearFilters,
      onAddFirst: _openScanner,
      onTryDemo: _addDemoDocument,
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

  Future<void> _showFilterSheet(UrgencySnapshot urgency) async {
    final activeCountry = DocumentCollectionService.instance.activeCountry;
    final res = await showDocumentsFilterSheet(
      context: context,
      currentStatus: _filter,
      currentType: _typeFilter,
      country: activeCountry,
      allCount: _items.where((i) => i.isActive || i.isExpired).length,
      criticalCount: urgency.criticalCount,
      upcomingCount: urgency.highCount,
      laterCount: urgency.mediumCount + urgency.lowCount,
      expiredCount: _items.where((i) => !i.isActive && i.isExpired).length,
    );
    if (res != null && mounted) {
      setState(() {
        _filter = res.status;
        _typeFilter = res.type;
      });
    }
  }

  Future<void> _showSortSheet() async {
    final value = await showDocumentsSortSheet(context, _sort);
    if (value is DocSort && mounted) setState(() => _sort = value);
  }
}
