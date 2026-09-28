import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/theme_service.dart';
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
/// screen (notifications, bill spikes, budget alerts & lead times).
class ProfilePreferencesSection extends StatelessWidget {
  const ProfilePreferencesSection({super.key});

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
      ],
    );
  }
}
