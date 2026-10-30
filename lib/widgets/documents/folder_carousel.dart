import 'package:flutter/material.dart';

import '../../models/document_folder.dart';
import '../../models/expiry_item.dart';
import '../../models/subscription_tier.dart';
import '../../services/document_folder_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/create_folder_dialog.dart';
import '../dialogs/upgrade_dialog.dart';

/// Special sentinel ID for filtering documents that do not belong to any folder.
const String unorganizedFolderId = '__unorganized__';

/// Horizontal carousel of folder chips displayed at the top of the Documents screen.
///
/// Supports 1-tap filtering, creating folders, editing, and safe deletion.
class FolderCarousel extends StatelessWidget {
  final List<DocumentFolder> folders;
  final List<ExpiryItem> items;
  final String? selectedFolderId;
  final ValueChanged<String?> onFolderSelected;

  const FolderCarousel({
    super.key,
    required this.folders,
    required this.items,
    required this.selectedFolderId,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entitlements = EntitlementService.instance;
    final isFree = entitlements.tier == SubscriptionTier.free;
    final folderLimit = entitlements.limits.maxFolders;
    final atLimit = folderLimit != null && folders.length >= folderLimit;

    // Count unorganized documents (those without a folderId)
    final unorganizedCount = items
        .where((i) => i.folderId == null || i.folderId!.isEmpty)
        .length;
    final hasFolders = folders.isNotEmpty;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. "All Documents" Chip
          _FilterPill(
            label: 'All',
            count: items.length,
            icon: Icons.grid_view_rounded,
            isSelected: selectedFolderId == null,
            color: theme.colorScheme.primary,
            onTap: () => onFolderSelected(null),
          ),
          const SizedBox(width: 8),

          // 2. Custom Folders
          for (final folder in folders) ...[
            Builder(
              builder: (ctx) {
                final count = items
                    .where((i) => i.folderId == folder.id)
                    .length;
                final isSelected = selectedFolderId == folder.id;

                return _FilterPill(
                  label: folder.name,
                  count: count,
                  icon: folder.iconData,
                  color: folder.color,
                  isSelected: isSelected,
                  onTap: () => onFolderSelected(isSelected ? null : folder.id),
                  onLongPress: () => _showFolderOptions(context, folder),
                );
              },
            ),
            const SizedBox(width: 8),
          ],

          // 3. "Unorganized" Chip (visible only if folders exist and there are unassigned items)
          if (hasFolders && unorganizedCount > 0) ...[
            _FilterPill(
              label: 'Unassigned',
              count: unorganizedCount,
              icon: Icons.folder_open_rounded,
              color: fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              ),
              isSelected: selectedFolderId == unorganizedFolderId,
              onTap: () => onFolderSelected(
                selectedFolderId == unorganizedFolderId
                    ? null
                    : unorganizedFolderId,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 4. "+ New Folder" / Upsell Chip
          InkWell(
            onTap: () async {
              if (isFree) {
                await showUpgradeDialog(
                  context,
                  EntitlementFeature.documentFolders,
                );
              } else if (atLimit) {
                await showUpgradeDialog(
                  context,
                  EntitlementFeature.documentFolders,
                  requestedTier: SubscriptionTier.business,
                );
              } else {
                final created = await showCreateFolderDialog(context);
                if (created != null) {
                  onFolderSelected(created.id);
                }
              }
            },
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? FinavigColors.slate : FinavigColors.cloud,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFree || atLimit
                        ? Icons.lock_outline_rounded
                        : Icons.add_rounded,
                    size: 16,
                    color: (isFree || atLimit)
                        ? Colors.amber.shade700
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isFree
                        ? 'Folder'
                        : atLimit
                        ? 'Folder ($folderLimit/$folderLimit)'
                        : 'New folder',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (isFree || atLimit)
                          ? Colors.amber.shade700
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(BuildContext context, DocumentFolder folder) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: fade.color(Colors.white, FinavigColors.charcoal),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
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
                  _confirmDelete(context, folder);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, DocumentFolder folder) {
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
              if (selectedFolderId == folder.id) {
                onFolderSelected(null);
              }
              await DocumentFolderService.instance.deleteFolder(folder.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.28 : 0.15)
              : (isDark ? FinavigColors.slate : FinavigColors.cloud),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.18),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : color)
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.22)
                    : theme.colorScheme.outline.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.white : color)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
