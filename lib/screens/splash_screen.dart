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
  late final Animation<double> _markScale;
  late final Animation<double> _markFade;
  late final Animation<double> _glowPulse;
  late final Animation<double> _taglineFade;

  bool _hasOnboarded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Monogram: quick pop-in over the first 40% of the timeline.
    _markScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );
    _markFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    // Glow keeps breathing after the pop settles.
    _glowPulse = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
    );
    // Tagline follows the mark.
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.8, curve: _TaglineEaseCurve()),
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
          // Backdrop: flat ink — one dark, no gradient wash or glow.
          const DecoratedBox(
            decoration: BoxDecoration(color: FinavigColors.ink),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient FV monogram with a soft neon halo.
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pop = _markScale.value;
                    return Opacity(
                      opacity: _markFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(scale: pop, child: child),
                    );
                  },
                  child: const _FvMonogram(),
                ),
                const SizedBox(height: 18),
                // Tagline fades in after the mark lands.
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _taglineFade.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: Text(
                    'FINANCIAL & DOCUMENT INTELLIGENCE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                      color: FinavigColors.cyanAccent.withOpacity(0.9),
                    ),
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

/// Ease-out for the tagline: fast reveal, gentle settle.
class _TaglineEaseCurve extends Curve {
  const _TaglineEaseCurve();

  @override
  double transformInternal(double t) => 1 - (1 - t) * (1 - t);
}

/// Solid white "FV" glyphs, sized to dominate the splash.
class _FvMonogram extends StatelessWidget {
  const _FvMonogram();

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Colors.white, Colors.white],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 1.0],
    );    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'FV',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 96,
          height: 1.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
