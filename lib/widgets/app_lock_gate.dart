import 'package:flutter/material.dart';

import '../screens/app_lock_screen.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';

/// Wraps the app's routed content and overlays [AppLockScreen] whenever the
/// local passcode lock is engaged.
///
/// Placement: this is installed through `MaterialApp.builder`, so the overlay
/// renders above every route and dialog. The underlying UI keeps its state and
/// simply stays hidden until the passcode (or biometrics) releases the lock.
///
/// The lock engages:
/// * on cold start (see [AppLockService.init]), and
/// * when the app returns to the foreground after more than [_gracePeriod]
///   in the background, so quick app-switches don't nag for a passcode.
///
/// It never engages while signed out — there is nothing behind it to protect,
/// and the login screen handles its own authentication.
class AppLockGate extends StatefulWidget {
  final Widget child;

  /// Signed-in probe; defaults to the real auth state. Overridable so the
  /// overlay can be exercised in widget tests without a Supabase session.
  final bool Function()? isSignedIn;

  /// Forwarded to [AppLockScreen] for the "Forgot passcode" exit.
  final VoidCallback? onSignedOut;

  const AppLockGate({
    super.key,
    required this.child,
    this.isSignedIn,
    this.onSignedOut,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const Duration _gracePeriod = Duration(seconds: 30);

  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _backgroundedAt;
      _backgroundedAt = null;
      if (at != null && DateTime.now().difference(at) > _gracePeriod) {
        AppLockService.instance.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLockService.instance,
      builder: (context, _) {
        final signedIn = widget.isSignedIn?.call() ??
            AuthService.instance.isSignedIn;
        final locked = AppLockService.instance.shouldBlock && signedIn;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (locked) AppLockScreen(onSignedOut: widget.onSignedOut),
          ],
        );
      },
    );
  }
}
