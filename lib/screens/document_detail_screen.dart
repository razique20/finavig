import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../utils/error_messages.dart';
import '../services/finance_service.dart';
import '../services/document_scanner_service.dart';
import '../services/collection_service.dart';
import '../services/entitlement_service.dart';
import '../services/notification_service.dart';
import '../services/rating_prompt_service.dart';
import '../widgets/attachment_thumbnail.dart';
import '../widgets/dialogs/renew_document_dialog.dart';
import '../widgets/viewers/full_screen_image_viewer.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  ExpiryItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    // Find item by ID directly across all cached documents
    final item = await DocumentScannerService.instance.getItemById(
      widget.documentId,
    );
    if (mounted) {
      setState(() {
        _item = item;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fade = FinavigTransition.of(context);
    final canvas = fade.color(FinavigColors.snowWhite, FinavigColors.obsidian);

    if (_loading) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          backgroundColor: canvas,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/documents'),
          ),
          title: const Text('Loading...'),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.secondary,
          ),
        ),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          backgroundColor: canvas,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/documents'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: FinavigColors.adaptiveIcon(context, Colors.grey),
              ),
              const SizedBox(height: 16),
              Text('Document not found', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'This document may have been removed or expired.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/documents'),
                child: const Text('Back to documents'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final urgency = item.urgency;
    final daysRemaining = item.daysRemaining;
    final expiresAt = item.expiresAt;

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/documents'),
        ),
        title: Text(
          item.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editDocument(context, item),
            tooltip: 'Edit document',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) =>
                _handleMenuAction(context, value, item),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit document'),
              ),
              const PopupMenuItem(
                value: 'renew',
                child: Text('Mark as renewed'),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Text('Share details'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export report'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove document'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: fade.color(Colors.white, FinavigColors.charcoal),
          border: Border(
            top: BorderSide(
              color: fade.color(
                Colors.black.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.06),
              ),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markAsRenewed(context, item),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Mark as Renewed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinavigColors.safe,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => _scheduleReminders(context, item),
              icon: Icon(
                item.reminderStatus > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: item.reminderStatus > 0
                  ? 'Reminders active — tap to reschedule'
                  : 'Schedule reminders',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              onPressed: () => _shareDocumentFile(context, item),
              icon: Icon(
                Icons.share_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Share document',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card with Department Logo
            _buildHeaderCard(theme, item, urgency, expiresAt, daysRemaining),

            // Warning box (when relevant)
            if (!item.isExpired) ...[
              const SizedBox(height: 14),
              _buildWarningCard(theme, item),
            ],

            // Attached file card (if any)
            if (item.fileName != null || item.filePath != null) ...[
              const SizedBox(height: 14),
              _buildAttachedFileCard(theme, item),
            ],

            const SizedBox(height: 16),

            // Unified Document details card (compact 2-column specifications)
            _buildInfoGrid(theme, item),

            const SizedBox(height: 16),

            // Urgency timeline & alerts ladder with inline custom alerts trigger
            _buildUrgencyPath(theme, item),

            // Renewal history timeline (only rendered if past renewals exist)
            if (item.renewalHistory != null && item.renewalHistory!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRenewalHistoryTimeline(theme, item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    ExpiryItem item,
    UrgencyLevel urgency,
    DateTime expiresAt,
    int daysRemaining,
  ) {
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeCountry = DocumentCollectionService.instance.activeCountry;
    final localizedDocType = item.docType.localizedDisplayName(activeCountry);
    final isOverdue = daysRemaining < 0;
    final urgencyColor = FinavigColors.urgencyColor(daysRemaining);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(18),
        boxShadow: FinavigShadows.adaptive(isDark),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DepartmentLogo(item: item, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: fade.color(
                              FinavigColors.accent.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.10),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            localizedDocType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fade.color(
                                FinavigColors.accent,
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (item.location != null && item.location!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: fade.color(
                                Colors.black.withValues(alpha: 0.04),
                                Colors.white.withValues(alpha: 0.06),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.location!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fade.color(
                                  FinavigColors.textSecondaryLight,
                                  FinavigColors.textSecondary,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.5,
            color: fade.color(
              Colors.black.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: fade.color(
                  FinavigColors.textSecondaryLight,
                  FinavigColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expires ${DateFormat('EEEE, dd MMM yyyy').format(expiresAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FinavigColors.urgencyBg(daysRemaining, brightness: theme.brightness),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: urgencyColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(urgency.icon, size: 12, color: urgencyColor),
                    const SizedBox(width: 4),
                    Text(
                      isOverdue ? '${-daysRemaining}d overdue' : '$daysRemaining days left',
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedFileCard(ThemeData theme, ExpiryItem item) {
    final fileName = item.fileName ?? 'Attached Document';
    final fileSizeKb = item.fileSize != null
        ? (item.fileSize! / 1024).toStringAsFixed(0)
        : null;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';

    final path = item.filePath;
    final isNetwork =
        path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    final file = path != null && path.isNotEmpty && !isNetwork
        ? File(path)
        : null;
    final exists = isNetwork || (file != null && file.existsSync());

    if (!exists) {
      final isDark = theme.brightness == Brightness.dark;
      final warnColor = isDark
          ? FinavigColors.warning
          : FinavigColors.warningDark;
      final warnBg = isDark
          ? FinavigColors.warningBg
          : FinavigColors.warningBgLight;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warnBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warnColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warnColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.devices_other_rounded,
                    color: warnColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File saved on another device',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: warnColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: warnColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'This document attachment was stored locally on a different device. You can re-upload the file on this device to view it here in the future.',
              style: theme.textTheme.bodySmall?.copyWith(color: warnColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _reuploadAttachment(context, item),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Re-upload File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openAttachmentViewer(context, item),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: warnColor,
                    side: BorderSide(color: warnColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Whether this attachment is a displayable image (drives the thumbnail
    // preview vs the generic file icon).
    final lowerPath = (path ?? '').toLowerCase();
    final isImage =
        lowerPath.contains('.png') ||
        lowerPath.contains('.jpg') ||
        lowerPath.contains('.jpeg') ||
        lowerPath.contains('.webp') ||
        lowerPath.contains('.gif') ||
        lowerPath.contains('.heic');

    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fade.color(Colors.white, FinavigColors.charcoal),
        borderRadius: BorderRadius.circular(16),
        boxShadow: FinavigShadows.adaptive(isDark),
        border: Border.all(
          color: fade.color(
            Colors.black.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.06),
          ),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          // Downsampled, cached thumbnail preview (or generic icon for
          // non-image files) — a 12 MP scan decodes at ~96 logical px here.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: fade.color(
                FinavigColors.accent.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? AttachmentImage(
                    path: path!,
                    isNetwork: isNetwork,
                    localFile: file,
                    targetWidth: 44,
                    fit: BoxFit.cover,
                  )
                : Icon(
                    Icons.attach_file_rounded,
                    color: fade.color(
                      FinavigColors.accent,
                      Colors.white,
                    ),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: fade.color(
                          FinavigColors.accent,
                          FinavigColors.accentBright,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ext,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fileSizeKb != null
                      ? 'Attachment file size: $fileSizeKb KB'
                      : 'Document attachment file',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _openAttachmentViewer(context, item),
            icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
            label: const Text('View'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _shareDocumentFile(context, item),
            icon: const Icon(Icons.ios_share_rounded, size: 15),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the attachment in the full-screen interactive viewer (images get
  /// pinch-to-zoom + double-tap zoom). Non-image files get an info sheet
  /// with a Share action instead.
  void _openAttachmentViewer(BuildContext context, ExpiryItem item) {
    final path = item.filePath;
    final name = item.fileName ?? 'Attached Document';
    final isNetwork =
        path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    final file = path != null && path.isNotEmpty && !isNetwork
        ? File(path)
        : null;
    final exists = isNetwork || (file != null && file.existsSync());

    if (!exists) {
      _showMissingFileInfoSheet(context, item, path, name);
      return;
    }

    final lowerPath = (path ?? '').toLowerCase();
    final isImage =
        lowerPath.contains('.png') ||
        lowerPath.contains('.jpg') ||
        lowerPath.contains('.jpeg') ||
        lowerPath.contains('.webp') ||
        lowerPath.contains('.gif') ||
        lowerPath.contains('.heic');

    if (isImage) {
      // Pre-warm before the fade-in opens so the first frame is instant.
      unawaited(
        prewarmAttachmentImage(
          context,
          path!,
          isNetwork: isNetwork,
          localFile: file,
        ),
      );
      showFullScreenImageViewer(
        context,
        name: name,
        path: path,
        isNetwork: isNetwork,
        localFile: file,
        onShare: () => _shareDocumentFile(context, item),
      );
    } else {
      _showFileInfoSheet(context, item, path, name, exists);
    }
  }

  /// Info sheet for non-image attachments (e.g. PDFs) that do exist.
  void _showFileInfoSheet(
    BuildContext context,
    ExpiryItem item,
    String? path,
    String name,
    bool exists,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final fade = FinavigTransition.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: fade.color(Colors.white, FinavigColors.charcoal),
              borderRadius: BorderRadius.circular(FinavigRadius.sheet),
              border: Border.all(
                color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item.fileSize != null)
                  Text(
                    'Size: ${(item.fileSize! / 1024).toStringAsFixed(1)} KB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'File path: $path',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _shareDocumentFile(context, item);
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share Document File'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Info sheet shown when the attachment was stored on another device
  /// or no file path is recorded.
  void _showMissingFileInfoSheet(
    BuildContext context,
    ExpiryItem item,
    String? path,
    String name,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final fade = FinavigTransition.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: fade.color(Colors.white, FinavigColors.charcoal),
              borderRadius: BorderRadius.circular(FinavigRadius.sheet),
              border: Border.all(
                color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.find_in_page_outlined,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  path != null && path.isNotEmpty
                      ? 'File was uploaded on another device ($path).'
                      : 'No file path stored for this document.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reuploadAttachment(
    BuildContext context,
    ExpiryItem item,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.path == null || !File(file.path!).existsSync()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected file.')),
        );
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(
        '${appDocDir.path}/finavig/documents/${item.id}',
      );
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final targetPath = '${targetDir.path}/${file.name}';
      final savedFile = await File(file.path!).copy(targetPath);

      final updatedItem = item.copyWith(
        fileName: file.name,
        filePath: savedFile.path,
        fileSize: file.size,
      );

      await DocumentScannerService.instance.updateItem(updatedItem);

      if (!context.mounted) return;
      setState(() {
        _item = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment "${file.name}" saved to this device'),
          backgroundColor: FinavigColors.safe,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, context: 'Could not re-upload the file'),
          ),
        ),
      );
    }
  }

  Widget _buildWarningCard(ThemeData theme, ExpiryItem item) {
    final days = item.daysRemaining;
    final isCritical = days <= 7;
    final urgencyColor = FinavigColors.urgencyColor(days);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FinavigColors.urgencyBg(days, brightness: theme.brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgencyColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCritical
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
              color: urgencyColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? 'Urgent action required' : 'Renewal information',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCritical ? theme.colorScheme.error : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // renewalWarning is often null; fall back to an expiry-aware
                  // message so the card never renders an empty body.
                  item.effectiveRenewalWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(ThemeData theme, ExpiryItem item) {
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeCountry = DocumentCollectionService.instance.activeCountry;
    final localizedDocType = item.docType.localizedDisplayName(activeCountry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Document details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: fade.color(Colors.white, FinavigColors.charcoal),
            borderRadius: BorderRadius.circular(16),
            boxShadow: FinavigShadows.adaptive(isDark),
            border: Border.all(
              color: fade.color(
                Colors.black.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.06),
              ),
              width: 0.6,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              _buildDetailRow(
                theme: theme,
                icon1: Icons.folder_outlined,
                label1: 'Document type',
                value1: localizedDocType,
                icon2: Icons.location_on_outlined,
                label2: 'Location',
                value2: item.location ?? activeCountry.displayName,
              ),
              Divider(
                height: 20,
                thickness: 0.5,
                color: fade.color(
                  Colors.black.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.06),
                ),
              ),
              _buildDetailRow(
                theme: theme,
                icon1: Icons.payments_outlined,
                label1: 'Renewal fee',
                value1: item.renewalFee != null
                    ? '${DocumentCollectionService.instance.activeCurrency} ${item.renewalFee!.toStringAsFixed(0)}'
                    : 'Estimated',
                icon2: Icons.history_edu_rounded,
                label2: 'Documented on',
                value2: item.documentDate ?? 'Not recorded',
              ),
              Divider(
                height: 20,
                thickness: 0.5,
                color: fade.color(
                  Colors.black.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.06),
                ),
              ),
              _buildDetailRow(
                theme: theme,
                icon1: Icons.person_outline_rounded,
                label1: 'Assigned to',
                value1: item.assignedTo ?? 'Unassigned',
                icon2: Icons.notifications_active_outlined,
                label2: 'Reminder status',
                value2: _reminderStatusLabel(item.reminderStatus),
                value2Color:
                    item.reminderStatus > 0 ? FinavigColors.safe : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required ThemeData theme,
    required IconData icon1,
    required String label1,
    required String value1,
    Color? value1Color,
    required IconData icon2,
    required String label2,
    required String value2,
    Color? value2Color,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildDetailCell(
            theme: theme,
            icon: icon1,
            label: label1,
            value: value1,
            valueColor: value1Color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDetailCell(
            theme: theme,
            icon: icon2,
            label: label2,
            value: value2,
            valueColor: value2Color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCell({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = valueColor ??
        fade.color(
          FinavigColors.accent,
          FinavigColors.textPrimary,
        );

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: valueColor ??
                      fade.color(
                        FinavigColors.textPrimaryLight,
                        FinavigColors.textPrimary,
                      ),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _reminderStatusLabel(int status) {
    switch (status) {
      case 0:
        return 'No reminders';
      case 1:
        return '90-day active';
      case 2:
        return '60-day active';
      case 3:
        return '30-day active';
      case 4:
        return '7-day urgent';
      default:
        return 'None';
    }
  }

  Widget _buildUrgencyPath(ThemeData theme, ExpiryItem item) {
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customDays = item.customReminderDays;
    final hasCustom = customDays != null && customDays.isNotEmpty;
    final daysText = hasCustom
        ? customDays.map((d) => '${d}d').join(', ')
        : '90, 60, 30, 7 days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Urgency timeline & alerts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (!EntitlementService.instance.allows(
                  EntitlementFeature.customReminderDays,
                )) {
                  await showUpgradeDialog(
                    context,
                    EntitlementFeature.customReminderDays,
                  );
                  return;
                }
                _showCustomReminderDaysDialog(context, item);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 13,
                      color: fade.color(FinavigColors.accent, Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasCustom ? 'Alerts: $daysText' : 'Custom alerts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fade.color(FinavigColors.accent, Colors.white),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fade.color(Colors.white, FinavigColors.charcoal),
            borderRadius: BorderRadius.circular(16),
            boxShadow: FinavigShadows.adaptive(isDark),
            border: Border.all(
              color: fade.color(
                Colors.black.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.06),
              ),
              width: 0.6,
            ),
          ),
          child: UrgencyTimelineCard.withIndicator(daysRemaining: item.daysRemaining),
        ),
      ],
    );
  }

  void _showCustomReminderDaysDialog(BuildContext context, ExpiryItem item) {
    final availablePresets = [90, 60, 45, 30, 15, 7, 3, 1];
    final selected = Set<int>.from(item.customReminderDays ?? [90, 60, 30, 7]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Custom Reminder Alerts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select notification alert days before expiry date:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availablePresets.map((days) {
                    final isSel = selected.contains(days);
                    return FilterChip(
                      label: Text('$days days'),
                      selected: isSel,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selected.add(days);
                          } else {
                            selected.remove(days);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  selected.isEmpty
                      ? 'No days selected (resets to standard 90/60/30/7 ladder).'
                      : 'Alerts will fire at: ${selected.toList()..sort((a, b) => b.compareTo(a))} days before expiry.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final sorted = selected.toList()
                    ..sort((a, b) => b.compareTo(a));
                  final updated = item.copyWith(
                    customReminderDays: sorted.isEmpty ? null : sorted,
                  );
                  await DocumentScannerService.instance.updateItem(updated);
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  setState(() {
                    _item = updated;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sorted.isEmpty
                            ? 'Reset to standard reminder ladder (90/60/30/7 days)'
                            : 'Custom alert days updated: ${sorted.join(', ')} days',
                      ),
                      backgroundColor: FinavigColors.safe,
                    ),
                  );
                },
                child: const Text('Save Alerts'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRenewalHistoryTimeline(ThemeData theme, ExpiryItem item) {
    final history = item.renewalHistory ?? [];
    if (history.isEmpty) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Renewal History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? Colors.white : FinavigColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: FinavigColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${history.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: FinavigColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rec = history[history.length - 1 - index]; // Newest first
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? FinavigColors.charcoal : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : FinavigColors.fog,
                  width: 1,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        color: FinavigColors.safe,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Renewed on ${rec.formattedRenewedAt}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (rec.fee != null && rec.fee! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: FinavigColors.safe.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${DocumentCollectionService.instance.activeCurrency} ${rec.fee!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: FinavigColors.safe,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Extended: ${rec.formattedPreviousExpiry}  ➔  ${rec.formattedNewExpiry}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (rec.renewedBy != null && rec.renewedBy!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'By: ${rec.renewedBy}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (rec.note != null && rec.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Note: "${rec.note}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Schedules OS-level local notifications on the ladder
  /// for this document (only tiers still in the future fire).
  Future<void> _scheduleReminders(BuildContext context, ExpiryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await NotificationService.instance.scheduleEscalationLadder(
        item.id,
        item.expiresAt,
        title: item.displayName,
        customReminderDays: item.customReminderDays,
      );
      if (item.reminderStatus == 0) {
        await DocumentScannerService.instance.setReminderStatus(item.id, 1);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Reminders scheduled for ${item.displayName}'),
          backgroundColor: FinavigColors.safe,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, context: 'Could not schedule reminders'),
          ),
        ),
      );
    }
  }

  Future<void> _markAsRenewed(BuildContext context, ExpiryItem item) async {
    // Shared renewal dialog: pick the new expiry date and optionally
    // re-upload the document file. Renewing never deletes the document.
    final result = await showRenewDocumentDialog(context, item);
    if (result == null) return;

    try {
      final fee = result.fee;
      final renewedBy = result.renewedBy;
      final note = result.note;
      final newExpiry = result.newExpiry;

      await DocumentScannerService.instance.markAsRenewed(
        item.id,
        newExpiryDate: newExpiry,
        fee: fee,
        renewedBy: renewedBy,
        note: note,
      );

      // Persist the replacement file when the user re-uploaded one.
      if (result.replacementFile != null) {
        final storedPath = await saveRenewalReplacementFile(
          item,
          result.replacementFile!,
        );
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

      if ((fee ?? 0) > 0) {
        await FinanceService.instance.addTransaction(
          FinanceTransaction(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            collectionId: item.collectionId,
            kind: FinanceKind.expense,
            category: FinanceCategory.renewals,
            title: '${item.displayName} renewal',
            amount: fee!,
            // Renewal fee is shown in the active collection's currency — stamp
            // the row with it so non-AE workspaces don't store a bare 'AED'.
            currency: DocumentCollectionService.instance.activeCurrency,
            occurredAt: DateTime.now(),
            note: note ?? 'Logged from document renewal',
            documentId: item.id,
          ),
        );
      }

      final updated = await DocumentScannerService.instance.getItemById(
        item.id,
      );

      if (!context.mounted) return;
      setState(() {
        _item = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (fee ?? 0) > 0
                ? '${item.displayName} renewed — payment of ${MoneyFormat.aed(fee!)} logged & history saved ✓'
                : '${item.displayName} renewed — now expires ${ExpiryItem.formatDate(newExpiry)} ✓',
          ),
          backgroundColor: FinavigColors.safe,
        ),
      );

      // Renewal = success moment. Record it; the soft rate prompt decides
      // for itself whether now is an appropriate time to ask (never nags).
      unawaited(_maybeAskForRating());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, context: 'Could not save the renewal'),
          ),
          backgroundColor: FinavigColors.danger,
        ),
      );
    }
  }

  /// Fire-and-forget rating ask: counts the renewal, then shows the native
  /// in-app review sheet only when the policy allows (2+ renewals, 90-day
  /// cooldown, max 3 per install).
  Future<void> _maybeAskForRating() async {
    await RatingPromptService.instance.recordRenewal();
    await RatingPromptService.instance.maybeAsk();
  }

  Future<void> _removeDocument(BuildContext context, ExpiryItem item) async {
    try {
      await DocumentScannerService.instance.removeItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.displayName} removed'),
          backgroundColor: FinavigColors.danger,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/documents');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, context: 'Could not remove')),
          backgroundColor: FinavigColors.danger,
        ),
      );
    }
  }

  Future<void> _editDocument(BuildContext context, ExpiryItem item) async {
    final result = await context.push<bool>(
      '/document/${item.id}/edit',
      extra: item,
    );
    if (result == true && mounted) {
      _loadItem();
    }
  }

  void _handleMenuAction(BuildContext context, String action, ExpiryItem item) {
    switch (action) {
      case 'edit':
        _editDocument(context, item);
        break;
      case 'renew':
        _markAsRenewed(context, item);
        break;
      case 'share':
        _shareDocumentFile(context, item);
        break;
      case 'export':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report exported (demo)')));
        break;
      case 'delete':
        _confirmDelete(context, item);
        break;
    }
  }

  /// Shares the attached document file via the platform share sheet
  /// (WhatsApp, Mail, etc.). Falls back to a helpful message when the file
  /// lives on another device or can't be reached.
  Future<void> _shareDocumentFile(BuildContext context, ExpiryItem item) async {
    final path = item.filePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attachment stored for this document yet.'),
        ),
      );
      return;
    }

    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final file = isNetwork ? null : File(path);
    if (!isNetwork && (file == null || !file.existsSync())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The attachment is only on another device — re-upload it first.',
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: item.fileName ?? item.displayName,
          subject: '${item.displayName} — shared from Finavig',
          files: isNetwork ? null : [XFile(path)],
          text: isNetwork ? path : null,
        ),
      );
      if (result.status == ShareResultStatus.success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Shared ✓'),
            backgroundColor: FinavigColors.safe,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, context: 'Could not share the file')),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, ExpiryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document'),
        content: Text(
          'Are you sure you want to remove "${item.displayName}" from tracking? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeDocument(context, item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FinavigColors.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

