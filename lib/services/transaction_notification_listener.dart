import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bank_notification_parser.dart';
import 'pending_transaction_service.dart';

/// Listens to incoming device notifications (Android only) and routes banking
/// alerts through [BankNotificationParser] → [PendingTransactionService].
///
/// On Android this uses a `NotificationListenerService` via a MethodChannel.
/// On iOS, notification listening isn't available — the service degrades to
/// a manual clipboard/paste import (see [parseFromClipboard]).
///
/// The feature is opt-in: the user must enable it in Settings, which also
/// triggers the Android system permission prompt.
class TransactionNotificationListener extends ChangeNotifier {
  TransactionNotificationListener._();
  static final TransactionNotificationListener instance =
      TransactionNotificationListener._();
  factory TransactionNotificationListener() => instance;

  static const String _enabledKey = 'finavig_notification_listener_enabled_v1';
  static const String _channelName = 'com.finavig.finavig/notification_listener';

  final MethodChannel _channel = const MethodChannel(_channelName);
  bool _initialized = false;
  bool _enabled = false;
  bool _hasPermission = false;

  /// Whether the feature is turned on in settings.
  bool get isEnabled => _enabled;

  /// Whether Android has granted notification access.
  bool get hasPermission => _hasPermission;

  /// Whether the listener is actively running.
  bool get isActive => _enabled && _hasPermission;

  /// Stream of newly detected transactions (for in-app toasts/overlays).
  final StreamController<PendingTransaction> _detectionStream =
      StreamController<PendingTransaction>.broadcast();
  Stream<PendingTransaction> get onTransactionDetected =>
      _detectionStream.stream;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Load user preference
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
    } catch (_) {}

    // Set up the method call handler for incoming notifications from native
    _channel.setMethodCallHandler(_handleMethodCall);

    // Check permission status (Android only)
    if (Platform.isAndroid && _enabled) {
      await checkPermission();
    }

    await PendingTransactionService.instance.init();
    notifyListeners();
  }

  /// Enable or disable the notification listener.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (_) {}

    if (enabled && Platform.isAndroid) {
      await _requestPermission();
    } else if (!enabled && Platform.isAndroid) {
      // Optionally stop the listener
      try {
        await _channel.invokeMethod('stopListening');
      } catch (_) {}
    }

    notifyListeners();
  }

  // ── Android permission management ───────────────────────────────────────

  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) {
      _hasPermission = false;
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isPermissionGranted');
      _hasPermission = result ?? false;
    } catch (_) {
      _hasPermission = false;
    }
    notifyListeners();
    return _hasPermission;
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
      // Re-check after user returns from settings
      await Future.delayed(const Duration(seconds: 2));
      await checkPermission();
      if (_hasPermission) {
        await _channel.invokeMethod('startListening');
      }
    } catch (e) {
      debugPrint('TransactionNotificationListener permission request error: $e');
    }
    notifyListeners();
  }

  /// Opens Android notification access settings directly.
  Future<void> openPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  // ── Method channel handler (receives notifications from native) ─────────

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final text = args['text'] as String? ?? '';
      final title = args['title'] as String?;
      final packageName = args['packageName'] as String?;

      await _processNotification(
        text: text,
        title: title,
        packageName: packageName,
      );
    } else if (call.method == 'onPermissionChanged') {
      final granted = call.arguments as bool? ?? false;
      _hasPermission = granted;
      notifyListeners();
    }
  }

  // ── Core processing ────────────────────────────────────────────────────

  Future<void> _processNotification({
    required String text,
    String? title,
    String? packageName,
  }) async {
    if (!_enabled) return;

    final parsed = BankNotificationParser.instance.tryParse(
      text: text,
      packageName: packageName,
      title: title,
    );

    if (parsed == null || !parsed.isViable) return;

    final added = await PendingTransactionService.instance.addDetected(parsed);
    if (added) {
      final pending = PendingTransactionService.instance.pending.first;
      _detectionStream.add(pending);
    }
  }

  // ── iOS/manual fallback: parse from clipboard text ──────────────────────

  /// Parse a banking SMS/notification text that the user manually pastes.
  /// Returns the parsed result or null if it doesn't look like a transaction.
  Future<ParsedBankNotification?> parseFromClipboard() async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipData?.text;
      if (text == null || text.isEmpty) return null;

      return BankNotificationParser.instance.tryParse(text: text);
    } catch (_) {
      return null;
    }
  }

  /// Parse arbitrary text (for the SMS paste field on iOS).
  ParsedBankNotification? parseText(String text) {
    if (text.isEmpty) return null;
    return BankNotificationParser.instance.tryParse(text: text);
  }

  /// For testing/demo: injects a simulated notification into the listener.
  /// Works across iOS Simulator, Android, and Desktop.
  Future<bool> simulateNotification({
    required String text,
    String? title,
    String? packageName,
  }) async {
    final parsed = BankNotificationParser.instance.tryParse(
      text: text,
      packageName: packageName,
      title: title,
    );

    if (parsed == null || !parsed.isViable) return false;

    final added = await PendingTransactionService.instance.addDetected(parsed);
    if (added) {
      final pending = PendingTransactionService.instance.pending.first;
      _detectionStream.add(pending);
      return true;
    }
    return false;
  }

  /// Clean up.
  @override
  void dispose() {
    _detectionStream.close();
    super.dispose();
  }
}
