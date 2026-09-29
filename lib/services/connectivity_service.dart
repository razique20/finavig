import 'dart:async';
import 'dart:io' show InternetAddress, Platform;

import 'package:flutter/foundation.dart';

/// Platform connectivity probe. Abstracted so tests can stub it.
abstract class ConnectivityProbe {
  Future<bool> isOnline();
}

/// Default probe using the network resource check (no extra dependency —
/// `dart:io` Socket + `HttpClient` under the hood, so it works on iOS,
/// Android and desktop; on web the lookup degrades gracefully).
class HttpConnectivityProbe implements ConnectivityProbe {
  const HttpConnectivityProbe();

  @override
  Future<bool> isOnline() async {
    if (kIsWeb) {
      // No sockets on web — navigator.onLine is the honest signal there.
      return true;
    }
    try {
      final result = await InternetAddress.lookup('supabase.co');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Tracks online/offline state for the app shell's offline banner.
///
/// The app is offline-first by design (all writes queue in the sync outbox
/// and replay when a connection returns), so the banner's job is to *explain*
/// that: "Offline — changes are saved on device and will sync." Silence
/// reads as broken; this reads as expected behaviour.
///
/// Lightweight polling (every 30s + on lifecycle resume) — deliberately no
/// connectivity_plus dependency; a DNS lookup against Supabase's domain is a
/// more truthful "can we actually reach the backend" signal than a Wi-Fi
/// interface flag.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const Duration pollInterval = Duration(seconds: 30);

  /// Injectable probe (tests swap this for a stub).
  ConnectivityProbe probe = const HttpConnectivityProbe();

  /// True under `flutter test`: skip automatic probing so widget tests are
  /// deterministic — no real DNS, no pending timers. Explicit checks with a
  /// stubbed [probe] still run.
  static bool get _runningInTests {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  bool _isOnline = true;
  bool _checking = false;
  Timer? _timer;

  /// Latest known state. Starts optimistic (online) — the first probe
  /// corrects it within the poll cycle.
  bool get isOnline => _isOnline;

  /// Start polling. Call once from the app shell; no-op if already running.
  /// Also performs an immediate first check.
  void start() {
    if (_timer != null) return;
    if (_runningInTests && probe is HttpConnectivityProbe) return;
    unawaited(checkNow());
    _timer = Timer.periodic(pollInterval, (_) => checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Force a check (e.g. on app resume). Notifies listeners only on change.
  /// The default probe is skipped under `flutter test` so widget tests stay
  /// deterministic; stubbed probes always run.
  Future<void> checkNow() async {
    if (_checking) return;
    if (_runningInTests && probe is HttpConnectivityProbe) return;
    _checking = true;
    try {
      final online = await probe.isOnline();
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    } catch (_) {
      // Probe failure must never crash the app; keep last known state.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
