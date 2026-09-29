import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Dismissible "your scans live on this device" nudge shown on the Profile
/// tab until the user dismisses it (or Supabase Storage backup ships).
///
/// Attachments are stored in the app documents directory — uninstalling the
/// app deletes the bytes while metadata survives sync. Until cloud backup
/// exists (feasibility study §2.2), the honest mitigation is telling users
/// and pointing them at the export tools. Dismissal persists per install.
class ProfileBackupNudge extends StatefulWidget {
  const ProfileBackupNudge({super.key});

  @override
  State<ProfileBackupNudge> createState() => _ProfileBackupNudgeState();
}

class _ProfileBackupNudgeState extends State<ProfileBackupNudge> {
  static const String _dismissedKey = 'finavig.backupNudgeDismissed';

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _visible = !(prefs.getBool(_dismissedKey) ?? false));
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FinavigColors.warning.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FinavigColors.warning.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.phonelink_setup_rounded,
              color: FinavigColors.warning,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your document scans live on this device only',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? FinavigColors.warning
                          : FinavigColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uninstalling the app deletes the attached files. '
                    'Export a PDF/CSV report from the Expiry List to keep a '
                    'copy — cloud backup is on the way.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: theme.colorScheme.outline,
              tooltip: 'Dismiss',
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
