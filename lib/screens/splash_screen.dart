import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_version_service.dart';
import '../services/auth_service.dart';
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
  bool _hasOnboarded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    if (mounted) {
      setState(() => _hasOnboarded = hasOnboarded);
      _controller.forward();
    }

    // Always check for app updates when opening the app
    final versionResult = await AppVersionService.instance.checkAppVersion(
      platform: AppVersionService.osPlatformKey,
    );
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
    return Scaffold(
      backgroundColor: FinavigColors.navyPrimary,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FV',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'FINANCIAL & DOCUMENT INTELLIGENCE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: FinavigColors.cyanAccent.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 48),
                if (_hasOnboarded)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(FinavigColors.cyanAccent),
                    ),
                  ),
              ],
            ),
          ),
          // Version label pinned to the bottom center
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Text(
              AppVersionService.fullVersionDisplay,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

