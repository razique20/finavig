import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hero_widgets.dart';
import '../../widgets/indicators/finavig_logo.dart';

/// Header of the Profile (Settings) tab — a centred page title, a circular
/// avatar, the user's name and email. Matches the clean, airy list layout:
/// no navy hero or plan pills (plan status lives in the "Manage subscription"
/// row instead).
class ProfileSettingsHeader extends StatelessWidget {
  final String userName;

  /// Exact age derived from the DOB captured at signup; null hides the line
  /// (accounts created before DOB capture).
  final int? userAge;

  const ProfileSettingsHeader({
    super.key,
    required this.userName,
    this.userAge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final signedIn = AuthService.instance.isSignedIn;
    final email = AuthService.instance.userEmail;
    final titleColor = fade.color(
      FinavigColors.textPrimaryLight,
      FinavigColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ACCOUNT & PREFERENCES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (signedIn)
                CanvasIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Sign out',
                  onTap: () => _signOut(context),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Replace the unrelated profile photo with Finavig's own brand mark.
          FinavigLogo(
            size: 84,
            borderRadius: BorderRadius.circular(24),
            showShadow: theme.brightness == Brightness.dark,
          ),
          const SizedBox(height: 14),
          Text(
            userName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email ?? 'local@finavig.app',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (userAge != null) ...[
            const SizedBox(height: 2),
            Text(
              'Age $userAge',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: FinavigColors.danger,
          size: 28,
        ),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to see your documents.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FinavigColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Signs out and clears caches, the entitlement tier and the local
    // app-lock passcode in one place (see AuthService.signOutAndClear).
    await AuthService.instance.signOutAndClear();

    if (context.mounted) context.go('/login');
  }
}
