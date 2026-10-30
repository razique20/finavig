import 'package:flutter/material.dart';

import '../../models/document_folder.dart';
import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../services/document_folder_service.dart';
import '../../services/document_scanner_service.dart';
import '../../theme/app_theme.dart';
import 'create_folder_dialog.dart';

/// Shows a bottom sheet allowing the user to move [item] into a folder or unassign it.
Future<void> showMoveToFolderSheet(
  BuildContext context,
  ExpiryItem item,
) async {
  final activeCollectionId =
      DocumentCollectionService.instance.activeCollectionId;
  final folders = DocumentFolderService.instance.foldersForCollection(
    activeCollectionId,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return _MoveToFolderContent(item: item, initialFolders: folders);
    },
  );
}

class _MoveToFolderContent extends StatefulWidget {
  final ExpiryItem item;
  final List<DocumentFolder> initialFolders;

  const _MoveToFolderContent({
    required this.item,
    required this.initialFolders,
  });

  @override
  State<_MoveToFolderContent> createState() => _MoveToFolderContentState();
}

class _MoveToFolderContentState extends State<_MoveToFolderContent> {
  late String? _currentFolderId;

  @override
  void initState() {
    super.initState();
    _currentFolderId = widget.item.folderId;
  }

  Future<void> _selectFolder(String? folderId) async {
    setState(() => _currentFolderId = folderId);
    await DocumentScannerService.instance.assignDocumentToFolder(
      widget.item.id,
      folderId,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final activeCollectionId =
        DocumentCollectionService.instance.activeCollectionId;
    final folders = DocumentFolderService.instance.foldersForCollection(
      activeCollectionId,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move to folder',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final newFolder = await showCreateFolderDialog(context);
                      if (newFolder != null) {
                        await _selectFolder(newFolder.id);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Option 1: Unassigned / None
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder_off_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              title: const Text('None (Unassigned)'),
              trailing: (_currentFolderId == null || _currentFolderId!.isEmpty)
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () => _selectFolder(null),
            ),
            // Option 2+: Folder options
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (ctx, idx) {
                  final folder = folders[idx];
                  final isSelected = _currentFolderId == folder.id;

                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: folder.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        folder.iconData,
                        color: folder.color,
                        size: 20,
                      ),
                    ),
                    title: Text(folder.name),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: folder.color)
                        : null,
                    onTap: () => _selectFolder(folder.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
