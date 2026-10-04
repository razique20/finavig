import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper over `local_auth` so the rest of the app never touches the
/// plugin directly and every failure mode (no hardware, no enrolment, user
/// cancel) collapses to a plain `false` instead of an exception.
class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Test hook: when non-null, hardware probes short-circuit to this value
  /// instead of touching the platform channel (which no test host answers).
  @visibleForTesting
  bool? supportedOverride;

  /// Test hook paired with [supportedOverride]: the value [authenticate]
  /// returns when overridden.
  @visibleForTesting
  bool authenticateResultOverride = false;

  /// Whether this device can authenticate with biometrics right now.
  Future<bool> get isSupported async {
    if (supportedOverride != null) return supportedOverride!;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for biometric authentication. Returns true only on a successful
  /// match; cancellation and errors return false.
  Future<bool> authenticate({required String reason}) async {
    if (supportedOverride != null) return authenticateResultOverride;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
