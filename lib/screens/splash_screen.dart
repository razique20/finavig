import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import 'dart:async' as async_dispatcher;
import '../theme/app_theme.dart';
import '../widgets/dialogs/app_version_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final Animation<double> _markFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Wordmark: a simple fade-in over the first stretch of the timeline.
    _markFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    if (mounted) {
      _controller.forward();
    }

    // Always check for app updates when opening the screen
    final versionResult = await AppVersionService.instance.checkAppVersion(
      platform: AppVersionService.osPlatformKey,
    );

    // Best-effort: report this launch to the admin app-health pipeline.
    // Do not block startup on this — if Supabase is misconfigured or the
    // user is not signed in yet, this is intentionally a no-op.
    async_dispatcher.unawaited(AppVersionService.instance.trackAppUsage());
    if (mounted && versionResult.shouldPromptUpdate) {
      final allowed = await AppVersionDialog.showIfNeeded(context, versionResult);
      if (!allowed && versionResult.status == VersionCheckStatus.forceUpdate) {
        return; // Halt navigation if force update is required and not completed
      }
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      // First launch: show the welcome screen before the auth flow.
      if (!hasSeenWelcome) {
        context.go('/welcome');
      } else {
        final auth = AuthService.instance;
        if (auth.isAvailable && !auth.isSignedIn) {
          context.go('/login');
        } else if (hasOnboarded) {
          context.go('/home');
        } else {
          context.go('/onboarding');
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately plain: a white field with the logo dead center.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _markFade.value.clamp(0.0, 1.0),
            child: child,
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 120,
            height: 120,
          ),
        ),
      ),
    );
  }
}
