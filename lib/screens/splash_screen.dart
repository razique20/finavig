import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../widgets/dialogs/app_version_dialog.dart';

/// Full-bleed splash backdrop image (dark market-chart photo).
const String kSplashBackgroundAsset = 'assets/images/splash_bg.jpg';

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

    // Mark: a simple fade-in over the first stretch of the timeline.
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop: full-bleed finance image, cover-fitted to every screen.
          Image.asset(
            kSplashBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Ink scrim: darkens the photo so the FV mark reads clearly,
          // and blends the edges into the app's ink palette.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD90F172A), // 85% ink
                  Color(0x990F172A), // 60% ink
                  Color(0xE60B1120), // 90% ink-deep
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Deliberately minimal: just the FV mark, top center.
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _markFade.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: const _FvMonogram(),
                ),
              ],
            ),
          ),
          // Version + OS stamp, pinned to the bottom right —
          // quiet and out of the way while the FV mark
          // owns the top center.
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Text(
              AppVersionService.fullVersionDisplay,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: Color(0x59FFFFFF), // white @ 35%
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid white "FV" glyphs at the top of the splash.
class _FvMonogram extends StatelessWidget {
  const _FvMonogram();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'FV',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 72,
        height: 1.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 4.0,
        color: Colors.white,
      ),
    );
  }
}
