import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_api_service.dart';
import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

/// Opens the edit-profile bottom sheet (role / phone). Returns the saved
/// values so the caller can update its state — sheets stay stateless.
Future<void> showProfileEditSheet(
  BuildContext context, {
  required String initialRole,
  required String initialPhone,
  required void Function(String role, String phone) onSaved,
}) async {
  final roleCtrl = TextEditingController(text: initialRole);
  final phoneCtrl = TextEditingController(text: initialPhone);

  await showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profile',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Role / Designation',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: '+971 50 000 0000',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSaved(
                      roleCtrl.text.trim().isEmpty
                          ? initialRole
                          : roleCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Prompt for / clear the Gemini API key used by the AI executive summary.
/// Persists via [GeminiApiService] and reports the outcome back through
/// [onSaved] so the caller can update its state.
Future<void> showGeminiKeySheet(
  BuildContext context, {
  required String currentKey,
  required void Function(String key) onSaved,
}) async {
  final controller = TextEditingController(text: currentKey);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Gemini API key'),
      content: TextField(
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(
          hintText: 'AIza…',
          helperText:
              'Stored only on this device. Get a free key at aistudio.google.com',
        ),
      ),
      actions: [
        if (currentKey.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == null || !context.mounted) return;

  onSaved(result);
  if (result.isEmpty) {
    await GeminiApiService.instance.clearApiKey();
  } else {
    await GeminiApiService.instance.setApiKey(result);
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.isEmpty
            ? 'Gemini key removed — summaries use built-in templates'
            : 'Gemini key saved — summaries will be AI-polished',
      ),
    ),
  );
}

/// Opens a bottom sheet for submitting a new support / tracking request.
Future<void> showProfileSupportSheet(BuildContext context) async {
  final theme = Theme.of(context);
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String selectedType = 'tracking_option_request';

  await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.teal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Submit a Request',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Request type
                  Text(
                    'Request Type',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(
                            value: 'tracking_option_request',
                            child: Row(
                              children: [
                                Icon(Icons.track_changes_rounded,
                                    size: 18, color: Colors.teal),
                                SizedBox(width: 10),
                                Text('Tracking Option Request'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'feature_request',
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded,
                                    size: 18, color: Colors.amber),
                                SizedBox(width: 10),
                                Text('Feature Request'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'bug_report',
                            child: Row(
                              children: [
                                Icon(Icons.bug_report_outlined,
                                    size: 18, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('Bug Report'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'support_request',
                            child: Row(
                              children: [
                                Icon(Icons.help_outline_rounded,
                                    size: 18, color: Colors.blue),
                                SizedBox(width: 10),
                                Text('General Support'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => selectedType = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Title',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g. Add vehicle registration tracking',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Describe what you need in detail…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final desc = descCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a title'),
                            ),
                          );
                          return;
                        }
                        if (desc.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please add a description'),
                            ),
                          );
                          return;
                        }

                        final result =
                            await SupportService.instance.submitRequest(
                          title: title,
                          description: desc,
                          requestType: selectedType,
                        );

                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.message ?? 'Request submitted',
                              ),
                            ),
                          );
                          Navigator.pop(ctx, result.success);
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Submit Request'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FinavigColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Opens a bottom sheet listing all the user's past support requests with
/// their current status.
Future<void> showProfileRequestHistorySheet(BuildContext context) async {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: FinavigColors.adaptiveIcon(context, Colors.blueGrey),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My Requests',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<SupportRequestItem>>(
                  future: SupportService.instance.fetchUserRequests(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 56,
                                color:
                                    FinavigColors.adaptiveIcon(context, theme.colorScheme.outline.withOpacity(0.4)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No requests yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Submit a request and it will appear here',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return ProfileSupportRequestCard(item: item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A card that shows one support request — type, title, description snippet,
/// submitted date, and a colour-coded status badge.
class ProfileSupportRequestCard extends StatelessWidget {
  final SupportRequestItem item;

  const ProfileSupportRequestCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (Color statusColor, IconData statusIcon) = switch (item.status) {
      'in_progress' => (Colors.orange, Icons.autorenew_rounded),
      'resolved' => (FinavigColors.safe, Icons.check_circle_outline_rounded),
      _ => (Colors.blueGrey, Icons.schedule_rounded), // 'open'
    };

    final statusLabel = switch (item.status) {
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      _ => 'Open',
    };

    final typeIcon = switch (item.requestType) {
      'tracking_option_request' => Icons.track_changes_rounded,
      'feature_request' => Icons.lightbulb_outline_rounded,
      'bug_report' => Icons.bug_report_outlined,
      _ => Icons.help_outline_rounded,
    };

    final typeColor = switch (item.requestType) {
      'tracking_option_request' => Colors.teal,
      'feature_request' => Colors.amber.shade700,
      'bug_report' => Colors.redAccent,
      _ => Colors.blue,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? FinavigColors.slate.withOpacity(0.55)
            : FinavigColors.cloud,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: type pill + status badge
          Row(
            children: [
              // Type pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 14, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      item.typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Admin notes (if any)
          if (item.adminNotes != null &&
              item.adminNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FinavigColors.cyanSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FinavigColors.cyanSecondary.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 16,
                    color: FinavigColors.cyanSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.adminNotes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FinavigColors.cyanSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Date
          Text(
            _formatRequestDate(item.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRequestDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} · $hour:$min $amPm';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Account deletion (Play Store data-safety compliance)
// ────────────────────────────────────────────────────────────────────────────

/// Two-step account deletion: a warning sheet, then a typed-confirmation
/// dialog. On confirm the Supabase auth user is deleted via the
/// `delete_own_account` RPC (see supabase/delete_account_function.sql) and
/// all cascaded server rows plus local caches are wiped by
/// [AuthService.deleteAccount].
Future<void> showDeleteAccountSheet(BuildContext context) async {
  // Step 1 — warning with a data-clearance summary.
  final wantsDelete = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete account?',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'This permanently removes:\n'
              '\u2022 Your account and sign-in ability\n'
              '\u2022 All documents, scans and financial records\n'
              '\u2022 Budgets, envelopes and AI quota history\n\n'
              'This cannot be undone once confirmed.',
              style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: Theme.of(sheetCtx)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx, false),
                    child: const Text('Keep my account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    child: const Text('Continue'),
                    ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(AppLinks.privacy),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Read the Privacy Policy'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (wantsDelete != true || !context.mounted) return;

  // Step 2 — typed confirmation.
  final email = AuthService.instance.userEmail ?? '';
  final typed = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (dlgCtx) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('Confirm deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type your email to confirm:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(hintText: email),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (ctx, value, _) => FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: value.text.trim().toLowerCase() ==
                      email.trim().toLowerCase() &&
                  email.isNotEmpty
                  ? () => Navigator.pop(dlgCtx, value.text.trim())
                  : null,
              child: const Text('Delete forever'),
            ),
          ),
        ],
      );
    },
  );

  if (typed == null || !context.mounted) return;

  // Step 3 — delete.
  final messenger = ScaffoldMessenger.of(context);
  try {
    await AuthService.instance.deleteAccount();
    if (context.mounted) context.go('/login');
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Account deleted. Your data has been removed.'),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyError(e, context: 'Could not delete account')),
        backgroundColor: Colors.red,
      ),
    );
  }
}
