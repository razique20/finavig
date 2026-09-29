import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router.dart' as app_router;

/// Handles notification taps: routes the user to the tapped document's
/// detail screen (cold start included) instead of dropping them on Home.
///
/// Reminders are scheduled with `payload: itemId` (see
/// [NotificationService.scheduleReminder]), so the tap response carries the
/// document id — this service turns it into `/document/:id` via the app
/// router. Budget-alert notifications carry no payload and just open the app.
///
/// The plugin's single initialization (and therefore the tap callback wiring)
/// lives in `NotificationService.init()`; this service only supplies the
/// handler via [NotificationService.onNotificationTap] and owns the routing.
class NotificationTapService {
  NotificationTapService._();

  static final NotificationTapService instance = NotificationTapService._();

  bool _initialized = false;

  /// Document id tapped from a notification but whose detail screen could
  /// not open yet (router not mounted on a very early cold start). Whoever
  /// mounts the router first consumes it.
  String? pendingDocumentId;

  /// Register the routing handler and resolve a cold-start launch (app was
  /// opened by tapping a notification). Call once from `main()`. Safe on
  /// web/tests: plugin failures degrade to a no-op.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Warm/background taps while the app is running.
    NotificationServiceTapHook.onTap = _handlePayload;

    // Cold start: the app was launched by tapping a notification.
    try {
      final launchDetails =
          await FlutterLocalNotificationsPlugin()
              .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _handlePayload(launchDetails!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('NotificationTapService: launch details unavailable — $e');
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return; // e.g. budget alerts
    debugPrint('NotificationTapService: tapped document=$payload');
    try {
      app_router.router.push('/document/$payload');
    } catch (e) {
      // Router not mounted yet (very early cold start) — stash and let the
      // first frame consume it.
      debugPrint('NotificationTapService: route not ready — $e');
      pendingDocumentId = payload;
    }
  }
}

/// Wiring seam so [NotificationTapService] can register its handler without
/// importing the notification plugin setup itself. NotificationService reads
/// this in `init()` and forwards tap responses.
class NotificationServiceTapHook {
  NotificationServiceTapHook._();

  /// Called with the payload of a tapped notification. Set at startup.
  static void Function(String? payload)? onTap;
}
