import 'package:flutter/material.dart';

import '../../models/document_folder.dart';
import '../../services/collection_service.dart';
import '../../services/document_folder_service.dart';
import '../../theme/app_theme.dart';
import 'upgrade_dialog.dart';

/// Opens the modal dialog to create a new document folder in the active collection.
/// Automatically verifies the user's tier entitlement and shows the paywall if needed.
Future<DocumentFolder?> showCreateFolderDialog(BuildContext context) async {
  final allowed = await enforceFolderLimit(context);
  if (!allowed) return null;

  if (!context.mounted) return null;
  return showDialog<DocumentFolder>(
    context: context,
    builder: (ctx) => const _FolderFormDialog(),
  );
}

/// Opens the modal dialog to edit an existing folder.
Future<void> showEditFolderDialog(
  BuildContext context,
  DocumentFolder folder,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _FolderFormDialog(existingFolder: folder),
  );
}

class _FolderFormDialog extends StatefulWidget {
  final DocumentFolder? existingFolder;

  const _FolderFormDialog({this.existingFolder});

  @override
  State<_FolderFormDialog> createState() => _FolderFormDialogState();
}

class _FolderFormDialogState extends State<_FolderFormDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  late String _selectedIconKey;
  late int _selectedColor;
  bool _saving = false;

  bool get _isEditing => widget.existingFolder != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingFolder?.name ?? '',
    );
    _selectedIconKey = widget.existingFolder?.iconKey ?? 'folder';
    _selectedColor =
        widget.existingFolder?.colorValue ?? DocumentFolder.presetColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);
    final name = _nameController.text.trim();

    try {
      if (_isEditing) {
        await DocumentFolderService.instance.updateFolder(
          widget.existingFolder!.id,
          name: name,
          iconKey: _selectedIconKey,
          colorValue: _selectedColor,
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        final activeCollectionId =
            DocumentCollectionService.instance.activeCollectionId;
        final folder = await DocumentFolderService.instance.createFolder(
          collectionId: activeCollectionId,
          name: name,
          iconKey: _selectedIconKey,
          colorValue: _selectedColor,
        );
        if (mounted) Navigator.of(context).pop(folder);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save folder: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: fade.color(Colors.white, FinavigColors.charcoal),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(_selectedColor).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        DocumentFolder.availableIcons[_selectedIconKey]?.$1 ??
                            Icons.folder_rounded,
                        color: Color(_selectedColor),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit folder' : 'New folder',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _isEditing
                                ? 'Update folder name, icon or color'
                                : 'Group related documents together',
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
                  ],
                ),
                const SizedBox(height: 20),

                // Name Input
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Folder name',
                    hintText: 'e.g. Family Passports, Vehicles, Leases',
                    prefixIcon: const Icon(
                      Icons.drive_file_rename_outline_rounded,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? FinavigColors.slate
                        : FinavigColors.cloud,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Color(_selectedColor),
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Please enter a folder name';
                    if (trimmed.length > 30)
                      return 'Name cannot exceed 30 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Icon Picker
                Text(
                  'Choose icon',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: DocumentFolder.availableIcons.entries.map((entry) {
                    final isSelected = _selectedIconKey == entry.key;
                    return InkWell(
                      onTap: () => setState(() => _selectedIconKey = entry.key),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor).withValues(alpha: 0.18)
                              : (isDark
                                    ? FinavigColors.slate
                                    : FinavigColors.cloud),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Color(_selectedColor)
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.15,
                                  ),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          entry.value.$1,
                          size: 22,
                          color: isSelected
                              ? Color(_selectedColor)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Color Accent Picker
                Text(
                  'Color accent',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fade.color(
                      FinavigColors.textMutedLight,
                      FinavigColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: DocumentFolder.presetColors.map((colorHex) {
                    final isSelected = _selectedColor == colorHex;
                    return InkWell(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      borderRadius: BorderRadius.circular(100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorHex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(
                                      colorHex,
                                    ).withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 26),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: fade.color(
                            FinavigColors.textMutedLight,
                            FinavigColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(_selectedColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Create folder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
