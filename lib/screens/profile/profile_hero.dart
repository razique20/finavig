import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Header of the Profile (Settings) tab — a centred page title, a circular
/// avatar, the user's name and email. Matches the clean, airy list layout: a
/// soft gradient wash behind, no navy hero, no plan pills (plan status lives
/// in the "Manage subscription" row instead).
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

    final initials = userName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: Text(
                    'Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: signedIn
                    ? _CircleIconButton(
                        icon: Icons.logout_rounded,
                        tooltip: 'Sign out',
                        onTap: () => _signOut(context),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Avatar — the same dark brand plate as the Home balance card
          // (ink in light mode, charcoal in dark) instead of the old blue
          // gradient, so the initials read as one brand mark with the rest of
          // the app. The dark-mode variant gets a hairline so it still lifts
          // off the obsidian canvas.
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  fade.color(FinavigColors.ink, FinavigColors.charcoal),
                  fade.color(FinavigColors.inkDeep, FinavigColors.slate),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: fade.color(
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.08),
                ),
              ),
              boxShadow: FinavigShadows.adaptive(
                theme.brightness == Brightness.dark,
              ),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? 'U' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
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
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to see your documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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

/// Round header action button that adapts to the light canvas (accent in light
/// mode, white icon on a translucent chip in dark).
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    return Material(
      color: fade.color(
        FinavigColors.accent.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.08),
      ),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: fade.color(FinavigColors.accent, Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
