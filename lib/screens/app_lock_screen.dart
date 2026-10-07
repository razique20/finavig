import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../router.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../widgets/passcode_pad.dart';

const String _lockArtworkAsset = 'assets/images/splash_bg.jpg';

/// Full-screen lock overlay shown above the router while the app lock is
/// engaged (cold start, or return after the grace period).
///
/// It sits in `MaterialApp.builder` — above every route and dialog — so it is
/// self-contained: the "Forgot passcode" confirmation is rendered inline and
/// navigation uses the top-level [router], because no Navigator is reachable
/// from this position in the tree.
class AppLockScreen extends StatefulWidget {
  /// Called after the "Forgot passcode" flow has signed the user out. Defaults
  /// to routing to the login screen; overridable for tests.
  final VoidCallback? onSignedOut;

  const AppLockScreen({super.key, this.onSignedOut});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _biometricAvailable = false;
  bool _showForgotConfirm = false;
  bool _signingOut = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initBiometric();
    // Rebuild once a second so an active lockout counts down in place.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && AppLockService.instance.lockoutSecondsRemaining > 0) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    if (!AppLockService.instance.biometricEnabled) return;
    final supported = await BiometricService.instance.isSupported;
    if (!mounted || !supported) return;
    setState(() => _biometricAvailable = true);
    // Offer the fast path immediately — the passcode stays as the fallback.
    // Deferred a frame so the overlay is on screen before the OS prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlockWithBiometric());
  }

  Future<void> _unlockWithBiometric() async {
    final ok = await BiometricService.instance.authenticate(
      reason: 'Unlock Finavig',
    );
    if (ok) await AppLockService.instance.unlockViaBiometric();
  }

  Future<String?> _verify(String pin) async {
    final result = await AppLockService.instance.verify(pin);
    switch (result) {
      case PasscodeResult.success:
        return null; // Gate removes the overlay on notify.
      case PasscodeResult.wrong:
        return 'Incorrect passcode';
      case PasscodeResult.lockedOut:
        final secs = AppLockService.instance.lockoutSecondsRemaining;
        return 'Too many attempts. Try again in ${secs}s';
    }
  }

  Future<void> _forgotPasscode() async {
    setState(() => _signingOut = true);
    // Disables the passcode, clears caches/tier, and signs out.
    await AuthService.instance.signOutAndClear();
    if (!mounted) return;
    // Re-authentication is the recovery path — the account password remains
    // the single source of truth.
    if (widget.onSignedOut != null) {
      widget.onSignedOut!();
    } else {
      router.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = AppLockService.instance.lockoutSecondsRemaining > 0;

    return Scaffold(
      backgroundColor: FinavigColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _lockArtworkAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC0F172A), Color(0xF20B1120)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: _showForgotConfirm
                    ? _forgotCard()
                    : _lockCard(lockedOut),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockCard(bool lockedOut) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, FinavigColors.cyanAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              'FV',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          PasscodeLockPanel(
            title: lockedOut ? 'Locked for now' : 'Enter your passcode',
            subtitle: lockedOut
                ? 'Too many incorrect attempts. Try again in '
                    '${AppLockService.instance.lockoutSecondsRemaining}s, or use '
                    '"Forgot passcode" to sign in with your password.'
                : 'Unlock Finavig to see your documents and money data.',
            enabled: !lockedOut,
            onSubmit: _verify,
            // NOTE: no `tooltip:` here. This overlay sits above the Navigator
            // (MaterialApp.builder), so it has no Overlay ancestor and a
            // Tooltip would render "No Overlay widget found". Semantics gives
            // the same accessibility label without needing an Overlay.
            biometricButton: _biometricAvailable
                ? Semantics(
                    button: true,
                    label: 'Unlock with biometrics',
                    child: IconButton(
                      onPressed: lockedOut ? null : _unlockWithBiometric,
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                : null,
            footer: TextButton(
              onPressed: lockedOut || _signingOut
                  ? null
                  : () => setState(() => _showForgotConfirm = true),
              child: const Text(
                'Forgot passcode?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forgotCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: FinavigColors.slate.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Reset App Lock?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'App Lock is only a quick re-entry shortcut — your account '
              'password is the real credential. Continuing signs you out so '
              'you can sign back in with your email and password. You can '
              'set a new passcode afterwards.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _signingOut
                        ? null
                        : () => setState(() => _showForgotConfirm = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _signingOut ? null : _forgotPasscode,
                    style: FilledButton.styleFrom(
                      backgroundColor: FinavigColors.violet,
                    ),
                    child: _signingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign out & reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Collects a brand-new passcode twice (entry, then confirmation) and pops the
/// chosen value when they match.
///
/// Used by both "set up" and "change passcode"; the caller persists it via
/// [AppLockService.enable] / [AppLockService.changePasscode].
class PasscodeSetupScreen extends StatefulWidget {
  final String title;

  const PasscodeSetupScreen({
    super.key,
    this.title = 'Create a passcode',
  });

  /// Pushes the setup flow and resolves to the chosen passcode, or null when
  /// the user backs out.
  static Future<String?> push(
    BuildContext context, {
    String title = 'Create a passcode',
  }) {
    return Navigator.of(context, rootNavigator: true).push<String?>(
      MaterialPageRoute(
        builder: (_) => PasscodeSetupScreen(title: title),
      ),
    );
  }

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  String? _first;
  bool _confirming = false;

  Future<String?> _handle(String pin) async {
    if (!_confirming) {
      if (!AppLockService.isAcceptable(pin)) {
        return 'Use exactly ${AppLockService.passcodeLength} digits';
      }
      setState(() {
        _first = pin;
        _confirming = true;
      });
      return null;
    }
    if (pin != _first) {
      return "Passcodes didn't match — try again";
    }
    if (!mounted) return null;
    Navigator.of(context).pop(pin);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _confirming ? 'Confirm passcode' : widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: PasscodeLockPanel(
                onDark: false,
                title: _confirming ? 'Confirm your passcode' : widget.title,
                subtitle: _confirming
                    ? 'Enter the same 6 digits once more.'
                    : 'Choose a 6-digit passcode to unlock Finavig quickly. '
                        'Your account password always works as a backup.',
                onSubmit: _handle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes a passcode prompt and resolves to whether the correct passcode was
/// entered. Used before turning the lock off or changing the passcode.
Future<bool> promptForPasscode(
  BuildContext context, {
  String title = 'Enter your passcode',
  String subtitle = 'Confirm it is really you before continuing.',
}) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      builder: (_) => _VerifyPasscodeScreen(title: title, subtitle: subtitle),
    ),
  );
  return ok ?? false;
}

class _VerifyPasscodeScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const _VerifyPasscodeScreen({required this.title, required this.subtitle});

  @override
  State<_VerifyPasscodeScreen> createState() => _VerifyPasscodeScreenState();
}

class _VerifyPasscodeScreenState extends State<_VerifyPasscodeScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && AppLockService.instance.lockoutSecondsRemaining > 0) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<String?> _handle(String pin) async {
    final result = await AppLockService.instance.verify(pin);
    switch (result) {
      case PasscodeResult.success:
        if (mounted) Navigator.of(context).pop(true);
        return null;
      case PasscodeResult.wrong:
        return 'Incorrect passcode';
      case PasscodeResult.lockedOut:
        return 'Too many attempts. Try again in '
            '${AppLockService.instance.lockoutSecondsRemaining}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = AppLockService.instance.lockoutSecondsRemaining > 0;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: PasscodeLockPanel(
                onDark: false,
                enabled: !lockedOut,
                title: widget.title,
                subtitle: lockedOut
                    ? 'Too many incorrect attempts. Try again in '
                        '${AppLockService.instance.lockoutSecondsRemaining}s.'
                    : widget.subtitle,
                onSubmit: _handle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
