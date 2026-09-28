import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expiry_item.dart';
import '../../services/document_scanner_service.dart';
import '../../widgets/dialogs/renew_document_dialog.dart';

/// Opens the per-document action bottom sheet and dispatches the chosen
/// action (renew / update date / assign / delete), reloading via [onChanged]
/// when the document data changes.
Future<void> showDocumentActionSheet(
  BuildContext context,
  ExpiryItem item,
  Future<void> Function() onChanged,
) async {
  final theme = Theme.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.daysRemaining} days left',
                  style: TextStyle(
                    color: item.daysRemaining <= 7
                        ? Colors.red
                        : item.daysRemaining <= 30
                            ? Colors.orange
                            : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.event_available_rounded,
              color: Colors.green,
            ),
            title: const Text('Mark as renewed'),
            subtitle: const Text('Reset the expiry clock'),
            onTap: () => Navigator.pop(ctx, 'renewed'),
          ),
          ListTile(
            leading: const Icon(
              Icons.edit_calendar_rounded,
              color: Colors.blue,
            ),
            title: const Text('Update expiry date'),
            subtitle: const Text('Correct or adjust the date'),
            onTap: () => Navigator.pop(ctx, 'date'),
          ),
          ListTile(
            leading: const Icon(
              Icons.person_add_alt_rounded,
              color: Colors.indigo,
            ),
            title: const Text('Assign to…'),
            subtitle: const Text('Responsible team member'),
            onTap: () => Navigator.pop(ctx, 'assign'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete document'),
            subtitle: const Text('Remove from tracking'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;
  switch (action) {
    case 'renewed':
      await _markRenewed(context, item, onChanged);
    case 'date':
      await _updateDate(context, item, onChanged);
    case 'assign':
      await _assign(context, item, onChanged);
    case 'delete':
      await _confirmDelete(context, item, onChanged);
  }
}

Future<void> _markRenewed(
  BuildContext context,
  ExpiryItem item,
  Future<void> Function() onChanged,
) async {
  // Ask for the new expiry (and an optional re-uploaded file) instead of
  // archiving the document — renewal keeps it tracked.
  final result = await showRenewDocumentDialog(context, item);
  if (result == null || !context.mounted) return;

  try {
    await DocumentScannerService.instance.markAsRenewed(
      item.id,
      newExpiryDate: result.newExpiry,
      fee: result.fee,
      renewedBy: result.renewedBy,
      note: result.note,
    );

    // Persist the replacement file when the user re-uploaded one.
    if (result.replacementFile != null) {
      final storedPath =
          await saveRenewalReplacementFile(item, result.replacementFile!);
      final refreshed = await DocumentScannerService.instance.getItemById(
        item.id,
      );
      if (refreshed != null) {
        await DocumentScannerService.instance.updateItem(
          refreshed.copyWith(
            fileName: result.replacementFile!.name,
            filePath: storedPath ?? refreshed.filePath,
            fileSize: result.replacementFile!.size,
          ),
        );
      }
    }

    await onChanged();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.displayName} renewed — now expires ${ExpiryItem.formatDate(result.newExpiry)} ✓',
        ),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not renew: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _updateDate(
  BuildContext context,
  ExpiryItem item,
  Future<void> Function() onChanged,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: item.expiresAt,
    firstDate: DateTime(DateTime.now().year - 1),
    lastDate: DateTime(DateTime.now().year + 10),
  );
  if (date == null || !context.mounted) return;
  await DocumentScannerService.instance.updateExpiryDate(item.id, date);
  await onChanged();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Expiry updated to ${DateFormat('dd MMM yyyy').format(date)}',
      ),
    ),
  );
}

Future<void> _assign(
  BuildContext context,
  ExpiryItem item,
  Future<void> Function() onChanged,
) async {
  final controller = TextEditingController(text: item.assignedTo ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Assign to'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Team member name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Assign'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await DocumentScannerService.instance.assignTo(item.id, name);
  await onChanged();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Assigned to $name')));
}

Future<void> _confirmDelete(
  BuildContext context,
  ExpiryItem item,
  Future<void> Function() onChanged,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete document?'),
      content: Text(
        '"${item.displayName}" will be removed from tracking. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await DocumentScannerService.instance.removeItem(item.id);
  await onChanged();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('${item.displayName} deleted')));
}
