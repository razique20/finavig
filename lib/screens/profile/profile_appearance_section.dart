import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/theme_service.dart';
import '../../services/user_data_export_service.dart';
import '../../theme/app_theme.dart';
import 'profile_sections.dart';

/// Appearance section — theme mode segmented control. Changes persist via
/// [ThemeService] and apply instantly through the root MaterialApp.
class ProfileAppearanceSection extends StatelessWidget {
  const ProfileAppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionGroup(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto, size: 18),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                  label: Text('Dark'),
                ),
              ],
              selected: {ThemeService.instance.mode},
              onSelectionChanged: (selected) {
                ThemeService.instance.setMode(selected.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Preferences section — link tile into the standalone Alerts & Reminders
/// screen (notifications, bill spikes, budget alerts & lead times), plus the
/// OEM battery guidance and the PDPL "Download my data" export.
class ProfilePreferencesSection extends StatelessWidget {
  const ProfilePreferencesSection({super.key});

  /// OEM battery-saver guidance (don't kill my app). Missed reminders are
  /// the highest-impact reliability risk on Xiaomi/Huawei/Samsung — this
  /// hands the user the vendor-specific fix.
  static Future<void> _openBatteryGuidance() async {
    final uri = Uri.parse('https://dontkillmyapp.com');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // No browser available — nothing sensible to do; ignore.
    }
  }

  /// Bundle all tracked data into one JSON file (PDPL data-portability).
  ///
  /// Uses the section's own context after async work only through
  /// [ScaffoldMessenger], which survives navigation.
  static Future<void> _exportUserData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await UserDataExportService.instance.buildExportJson();
      final path = await FilePicker.platform.saveFile(
        fileName:
            'finavig-data-export-${DateTime.now().toIso8601String().split('T').first}.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (path != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Data export saved to $path')),
        );
        return;
      }
      // saveFile cancelled or unsupported — fall back to the share sheet.
      await SharePlus.instance.share(
        ShareParams(
          title: 'Finavig data export',
          text: json,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not build the export — please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSectionGroup(
      title: 'Preferences',
      children: [
        ProfileSettingsTile(
          icon: Icons.notifications_active_rounded,
          iconColor: FinavigColors.indigo,
          title: 'Alerts & Reminders',
          subtitle: 'Notifications, bill spikes, budget alerts & lead times',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => context.push('/alerts-reminders'),
        ),
        ProfileSettingsTile(
          icon: Icons.battery_saver_rounded,
          iconColor: FinavigColors.emerald,
          title: 'Ensure reminders work',
          subtitle:
              'Some phones kill background alerts — check these settings',
          trailing: const Icon(Icons.open_in_new_rounded, size: 16),
          onTap: _openBatteryGuidance,
        ),
        ProfileSettingsTile(
          icon: Icons.download_rounded,
          iconColor: FinavigColors.violet,
          title: 'Download my data',
          subtitle: 'Export documents & finance data as a JSON file',
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => _exportUserData(context),
        ),
      ],
    );
  }
}
