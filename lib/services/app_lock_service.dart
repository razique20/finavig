import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pluggable key/value backend for the app lock.
///
/// Abstracted so the passcode hashing and lockout logic can be unit-tested
/// without platform channels (the default implementation uses the iOS
/// Keychain / Android Keystore, which no test host provides).
abstract class AppLockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Default [AppLockStore] backed by the platform secure storage.
class SecureAppLockStore implements AppLockStore {
  const SecureAppLockStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Outcome of a passcode verification attempt.
enum PasscodeResult { success, wrong, lockedOut }

/// Local app-lock ("re-entry passcode").
///
/// This is a convenience lock layered **on top of** the Supabase session — it
/// gates access to an already-signed-in session when the app is reopened. It
/// is deliberately **not** an authentication credential: the account password
/// and email-confirmation flow remain the single source of truth, and the
/// "Forgot passcode" escape hatch simply signs the user out so they can
/// re-authenticate with their password.
///
/// Security posture:
/// * Only a salted, iterated SHA-256 hash of the passcode is persisted — never
///   the passcode itself.
/// * Secrets live in the platform secure storage (iOS Keychain / Android
///   Keystore) via [AppLockStore], never in SharedPreferences.
/// * Repeated wrong entries trigger an escalating lockout that is itself
///   persisted, so force-quitting the app does not reset it.
class AppLockService extends ChangeNotifier {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  // ── storage keys ────────────────────────────────────────────────────────
  static const _kHash = 'applock.passcode.hash';
  static const _kSalt = 'applock.passcode.salt';
  static const _kEnabled = 'applock.enabled';
  static const _kBiometric = 'applock.biometric';
  static const _kAttempts = 'applock.failed.attempts';
  static const _kLockoutUntil = 'applock.lockout.until';
  static const _kOfferSeen = 'applock.offer.seen';

  /// Passcode length enforced by the UI and validated here.
  static const int passcodeLength = 6;

  /// Wrong entries tolerated before the escalating lockout kicks in.
  static const int maxAttempts = 5;

  /// Iterations of the SHA-256 key-derivation loop. Cheap enough to feel
  /// instant, costly enough to make an offline brute-force expensive.
  static const int _kdfIterations = 100000;

  AppLockStore _store = const SecureAppLockStore();
  final Random _random = Random.secure();

  bool _enabled = false;
  bool _biometric = false;
  bool _locked = false;
  bool _offerSeen = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  /// Whether a passcode is currently configured.
  bool get isEnabled => _enabled;

  /// Whether the user opted into biometric unlocking (only meaningful when a
  /// passcode is set).
  bool get biometricEnabled => _biometric;

  /// Whether the lock overlay is currently demanded.
  bool get isLocked => _locked;

  /// True when the lock overlay should cover the app.
  bool get shouldBlock => _enabled && _locked;

  /// Whether the post-login set-up offer should be shown: a passcode is not
  /// set and we have not already offered on this device. Asked at most once,
  /// so it never nags returning users.
  bool get shouldOfferSetup => !_enabled && !_offerSeen;

  /// Seconds remaining before another attempt is allowed (0 when not locked out).
  int get lockoutSecondsRemaining {
    final until = _lockoutUntil;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// A passcode must be exactly [passcodeLength] digits.
  static bool isAcceptable(String passcode) =>
      passcode.length == passcodeLength &&
      int.tryParse(passcode) != null;

  /// Swaps in a test store. Production never calls this.
  @visibleForTesting
  void useStoreForTesting(AppLockStore store) {
    _store = store;
  }

  /// Loads the persisted lock state. Safe to call more than once.
  ///
  /// A fresh launch always starts locked when a passcode is set, so the very
  /// first frame after a cold start is already protected.
  Future<void> init() async {
    try {
      _enabled = await _store.read(_kEnabled) == 'true';
      _biometric = await _store.read(_kBiometric) == 'true';
      _offerSeen = await _store.read(_kOfferSeen) == 'true';
      _failedAttempts = int.tryParse(await _store.read(_kAttempts) ?? '') ?? 0;
      final until = int.tryParse(await _store.read(_kLockoutUntil) ?? '');
      _lockoutUntil =
          until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
    } catch (_) {
      // Secure storage unavailable — fail safe to "no lock" rather than
      // trapping the user behind a door we can't open.
      _enabled = false;
    }
    _locked = _enabled;
    notifyListeners();
  }

  /// Enables the lock and stores a freshly hashed passcode.
  ///
  /// Leaves the app unlocked — the caller has just proven ownership by
  /// choosing the passcode; the lock engages on the next background/cold start.
  Future<void> enable(String passcode, {bool biometric = false}) async {
    final salt = _newSalt();
    final hash = _derive(passcode, salt);
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, hash);
    await _store.write(_kEnabled, 'true');
    await _store.write(_kBiometric, biometric ? 'true' : 'false');
    _enabled = true;
    _biometric = biometric;
    _failedAttempts = 0;
    _lockoutUntil = null;
    await _persistAttempts();
    _locked = false;
    notifyListeners();
  }

  /// Replaces the passcode, keeping the current biometric preference.
  Future<void> changePasscode(String newPasscode) =>
      enable(newPasscode, biometric: _biometric);

  /// Records that the one-time set-up offer has been shown. Persisted and
  /// deliberately **not** cleared by [disable] / sign-out, so the prompt is
  /// genuinely once per device rather than once per session.
  Future<void> markSetupOffered() async {
    if (_offerSeen) return;
    _offerSeen = true;
    try {
      await _store.write(_kOfferSeen, 'true');
    } catch (_) {
      // Non-fatal — in-memory flag still suppresses a repeat this session.
    }
    notifyListeners();
  }

  /// Updates only the biometric preference.
  Future<void> setBiometricEnabled(bool value) async {
    _biometric = value;
    await _store.write(_kBiometric, value ? 'true' : 'false');
    notifyListeners();
  }

  /// Turns the lock off and erases every stored secret.
  Future<void> disable() async {
    for (final key in const [
      _kHash,
      _kSalt,
      _kEnabled,
      _kBiometric,
      _kAttempts,
      _kLockoutUntil,
    ]) {
      try {
        await _store.delete(key);
      } catch (_) {
        // Best-effort — clearing in-memory state below is what matters.
      }
    }
    _enabled = false;
    _biometric = false;
    _locked = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }

  /// Compares [passcode] against the stored hash, applying the lockout policy.
  Future<PasscodeResult> verify(String passcode) async {
    if (!_enabled) return PasscodeResult.success;

    // Honour an active lockout before even comparing.
    if (lockoutSecondsRemaining > 0) return PasscodeResult.lockedOut;

    final salt = await _store.read(_kSalt);
    final stored = await _store.read(_kHash);
    if (salt == null || stored == null) {
      // Corrupt / partial state — fail closed.
      return PasscodeResult.wrong;
    }

    if (_constantTimeEquals(_derive(passcode, salt), stored)) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      await _persistAttempts();
      _locked = false;
      notifyListeners();
      return PasscodeResult.success;
    }

    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDurationFor(_failedAttempts));
    }
    await _persistAttempts();
    notifyListeners();
    return lockoutSecondsRemaining > 0
        ? PasscodeResult.lockedOut
        : PasscodeResult.wrong;
  }

  /// Engages the lock (no-op when no passcode is set or already locked).
  void lock() {
    if (!_enabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Releases the lock after a successful biometric authentication, clearing
  /// any accumulated wrong-attempt state.
  Future<void> unlockViaBiometric() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    await _persistAttempts();
    _locked = false;
    notifyListeners();
  }

  // ── internals ───────────────────────────────────────────────────────────

  Future<void> _persistAttempts() async {
    try {
      await _store.write(_kAttempts, '$_failedAttempts');
      final until = _lockoutUntil;
      if (until != null) {
        await _store.write(_kLockoutUntil, '${until.millisecondsSinceEpoch}');
      } else {
        await _store.delete(_kLockoutUntil);
      }
    } catch (_) {
      // Non-fatal: the in-memory counters still apply for this session.
    }
  }

  static Duration _lockoutDurationFor(int attempts) {
    switch (attempts - maxAttempts) {
      case 0:
        return const Duration(seconds: 30);
      case 1:
        return const Duration(minutes: 1);
      case 2:
        return const Duration(minutes: 5);
      default:
        return const Duration(minutes: 15);
    }
  }

  String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Iterated SHA-256 over `salt:passcode`. Deterministic for a given salt, so
  /// the stored hash can be recomputed and compared without ever storing the
  /// passcode.
  String _derive(String passcode, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$passcode')).bytes;
    for (var i = 1; i < _kdfIterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64.encode(digest);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
