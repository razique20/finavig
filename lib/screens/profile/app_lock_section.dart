import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../app_lock_flows.dart';
import 'profile_sections.dart';

/// Security section of the Profile (Settings) screen — the local App Lock
/// (re-entry passcode). Rebuilds live off [AppLockService] so the On/Off state
/// and biometric summary stay current.
class ProfileSecuritySection extends StatelessWidget {
  const ProfileSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLockService.instance,
      builder: (context, _) {
        final service = AppLockService.instance;
        final enabled = service.isEnabled;
        return ProfileSectionGroup(
          title: 'Security',
          children: [
            ProfileSettingsTile(
              icon: enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              iconColor: FinavigColors.violet,
              title: 'App Lock',
              subtitle: enabled
                  ? (service.biometricEnabled
                      ? 'Passcode with biometric unlocking'
                      : 'Passcode required when reopening Finavig')
                  : 'Ask for a passcode when reopening Finavig',
              trailing: Switch(
                value: enabled,
                activeThumbColor: FinavigColors.violet,
                onChanged: (value) => value
                    ? enableAppLock(context)
                    : disableAppLock(context),
              ),
              onTap: () => showAppLockSettingsSheet(context),
            ),
          ],
        );
      },
    );
  }
}

/// Management sheet for the local App Lock: set up, biometric toggle, change
/// passcode, and turn off. Every control saves immediately.
Future<void> showAppLockSettingsSheet(BuildContext context) async {
  // The sheet's own context dies with the sheet; follow-up flows (setup,
  // verify) are launched from the still-mounted host context.
  final host = context;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ListenableBuilder(
            listenable: AppLockService.instance,
            builder: (context, _) {
              final service = AppLockService.instance;
              final enabled = service.isEnabled;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: FinavigColors.violet.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: FinavigColors.violet,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'App Lock',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A local passcode that protects the app when you reopen '
                    'it. It is a quick re-entry shortcut — your account '
                    'password remains the real credential, and you can always '
                    'sign back in with it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!enabled)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          await enableAppLock(host);
                        },
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Set up App Lock'),
                        style: FilledButton.styleFrom(
                          backgroundColor: FinavigColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    FutureBuilder<bool>(
                      future: BiometricService.instance.isSupported,
                      builder: (context, snapshot) {
                        if (snapshot.data != true) {
                          return const SizedBox.shrink();
                        }
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: service.biometricEnabled,
                          activeThumbColor: FinavigColors.violet,
                          title: const Text('Unlock with biometrics'),
                          subtitle: const Text(
                            'Face ID / fingerprint, with the passcode as fallback',
                          ),
                          onChanged: (value) =>
                              AppLockService.instance.setBiometricEnabled(value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ProfileSettingsTile(
                      icon: Icons.password_rounded,
                      iconColor: FinavigColors.indigo,
                      title: 'Change passcode',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        changeAppLockPasscode(host);
                      },
                    ),
                    ProfileSettingsTile(
                      icon: Icons.lock_open_rounded,
                      iconColor: FinavigColors.danger,
                      title: 'Turn off App Lock',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        disableAppLock(host);
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
