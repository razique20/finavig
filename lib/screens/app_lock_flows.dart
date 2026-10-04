import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'app_lock_screen.dart';

/// App Lock flows shared by more than one entry point: the Profile Security
/// section (manual set-up / change / turn off) and the one-time post-login
/// offer.

/// Runs the set-up flow: choose a passcode, optionally opt into biometrics.
Future<void> enableAppLock(BuildContext context) async {
  final pin = await PasscodeSetupScreen.push(context);
  if (pin == null || !context.mounted) return;

  // Enable the passcode first — the essential action must not depend on the
  // optional biometric probe resolving.
  await AppLockService.instance.enable(pin);
  if (!context.mounted) return;

  if (await BiometricService.instance.isSupported) {
    if (!context.mounted) return;
    final useBiometric = await _askEnableBiometric(context) ?? false;
    if (useBiometric) await AppLockService.instance.setBiometricEnabled(true);
  }

  if (context.mounted) _snack(context, 'App Lock is on');
}

/// Confirms the current passcode, then turns the lock off.
Future<void> disableAppLock(BuildContext context) async {
  final ok = await promptForPasscode(
    context,
    title: 'Turn off App Lock',
    subtitle: 'Enter your passcode to turn App Lock off.',
  );
  if (!ok || !context.mounted) return;

  await AppLockService.instance.disable();
  if (context.mounted) _snack(context, 'App Lock is off');
}

/// Confirms the current passcode, then collects and stores a new one.
Future<void> changeAppLockPasscode(BuildContext context) async {
  final ok = await promptForPasscode(
    context,
    title: 'Confirm passcode',
    subtitle: 'Enter your current passcode to change it.',
  );
  if (!ok || !context.mounted) return;

  final pin = await PasscodeSetupScreen.push(
    context,
    title: 'New passcode',
  );
  if (pin == null) return;

  await AppLockService.instance.changePasscode(pin);
  if (context.mounted) _snack(context, 'Passcode updated');
}

/// One-time, opt-in App Lock offer shown right after an existing user signs
/// in. Purely additive — declining (or any failure) lets entry proceed, and
/// the prompt is recorded so it never reappears.
Future<void> maybeOfferAppLockSetup(BuildContext context) async {
  final service = AppLockService.instance;
  if (!service.shouldOfferSetup) return;

  await service.markSetupOffered();
  if (!context.mounted) return;

  final accepted = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                      'Turn on App Lock?',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Add a 6-digit passcode so you can reopen Finavig quickly '
                'without retyping your password. It only locks this device — '
                'your account password stays the real credential, and you can '
                'turn it off any time in Settings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: FinavigColors.ink,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Set up'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (accepted != true || !context.mounted) return;
  await enableAppLock(context);
}

Future<bool?> _askEnableBiometric(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Use biometrics too?'),
      content: const Text(
        'Unlock Finavig with Face ID / fingerprint for a faster re-entry. '
        'Your passcode still works as a fallback.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enable'),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
