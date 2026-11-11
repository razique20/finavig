import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../constants/app_constants.dart';

/// Centralized PostHog analytics service — singleton that wraps the
/// posthog_flutter SDK for **product analytics** and **feature flags**.
///
/// Free-plan monthly limits (resets every month):
///   • Product Analytics:  1,000,000 events
///   • Feature Flags:      1,000,000 evaluations
///   • Session Replay:     2,500 mobile recordings  (disabled — see below)
///
/// Session replay is intentionally **not** enabled to conserve the tightest
/// free-plan quota. To enable it later, wrap your root widget with
/// `PostHogWidget` in app.dart and toggle "Record user sessions" ON in the
/// PostHog dashboard.
///
/// Initialised once from [main] after [WidgetsFlutterBinding.ensureInitialized]
/// and before [runApp].
///
/// Usage:
/// ```dart
/// PosthogService.instance.capture('button_tapped', {'screen': 'home'});
/// final show = await PosthogService.instance.isFeatureEnabled('new_onboarding');
/// ```
class PosthogService {
  PosthogService._();

  static final PosthogService instance = PosthogService._();

  bool _initialized = false;

  /// Whether PostHog has been successfully initialised.
  bool get isInitialized => _initialized;

  // ── Initialization ──────────────────────────────────────────────────────

  /// Call once during app startup. Safe to call multiple times (no-ops after
  /// the first successful init).
  Future<void> init() async {
    if (_initialized) return;

    try {
      final config = PostHogConfig(AppConstants.posthogApiKey)
        ..host = AppConstants.posthogHost
        ..captureApplicationLifecycleEvents = true
        ..debug = kDebugMode; // verbose logging only in debug builds

      await Posthog().setup(config);
      _initialized = true;
      debugPrint('PosthogService: initialised '
          '(host=${AppConstants.posthogHost}, '
          'debug=$kDebugMode)');
    } catch (e, st) {
      debugPrint('PosthogService: init failed — $e\n$st');
      // Non-fatal: the app works without analytics.
    }
  }

  // ── Event Tracking (free: 1M events/month) ─────────────────────────────

  /// Capture a named event with optional properties.
  ///
  /// No-ops silently when PostHog isn't initialised so call sites don't need
  /// null-checks.
  Future<void> capture(
    String eventName, [
    Map<String, Object>? properties,
  ]) async {
    if (!_initialized) return;
    try {
      await Posthog().capture(
        eventName: eventName,
        properties: properties,
      );
    } catch (e) {
      debugPrint('PosthogService.capture(\$eventName): \$e');
    }
  }

  /// Track a screen view. Can be called manually for sub-screens /
  /// bottom-sheet flows.
  Future<void> screen(String screenName,
      [Map<String, Object>? properties]) async {
    if (!_initialized) return;
    try {
      await Posthog().screen(
        screenName: screenName,
        properties: properties,
      );
    } catch (e) {
      debugPrint('PosthogService.screen(\$screenName): \$e');
    }
  }

  // ── User Identity ───────────────────────────────────────────────────────

  /// Identify the signed-in user. Call after successful sign-in or on cold
  /// start when a session already exists.
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
  }) async {
    if (!_initialized) return;
    try {
      await Posthog().identify(
        userId: userId,
        userProperties: userProperties,
      );
    } catch (e) {
      debugPrint('PosthogService.identify: \$e');
    }
  }

  /// Reset the user identity. Call on sign-out so subsequent events aren't
  /// attributed to the previous user.
  Future<void> reset() async {
    if (!_initialized) return;
    try {
      await Posthog().reset();
    } catch (e) {
      debugPrint('PosthogService.reset: \$e');
    }
  }

  // ── Feature Flags (free: 1M evaluations/month) ─────────────────────────

  /// Check whether a boolean feature flag is enabled.
  Future<bool> isFeatureEnabled(String flagKey) async {
    if (!_initialized) return false;
    try {
      return await Posthog().isFeatureEnabled(flagKey);
    } catch (e) {
      debugPrint('PosthogService.isFeatureEnabled(\$flagKey): \$e');
      return false;
    }
  }

  /// Get the value of a feature flag (boolean, string, or JSON payload).
  Future<dynamic> getFeatureFlag(String flagKey) async {
    if (!_initialized) return null;
    try {
      return await Posthog().getFeatureFlag(flagKey);
    } catch (e) {
      debugPrint('PosthogService.getFeatureFlag(\$flagKey): \$e');
      return null;
    }
  }

  /// Force-refresh feature flags (e.g. after identify or property change).
  Future<void> reloadFeatureFlags() async {
    if (!_initialized) return;
    try {
      await Posthog().reloadFeatureFlags();
    } catch (e) {
      debugPrint('PosthogService.reloadFeatureFlags: \$e');
    }
  }

  // ── Super Properties (persisted across events) ─────────────────────────

  /// Register properties that are sent with every subsequent event.
  Future<void> register(Map<String, Object> properties) async {
    if (!_initialized) return;
    try {
      for (final entry in properties.entries) {
        await Posthog().register(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('PosthogService.register: \$e');
    }
  }
}
