import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'app.dart';
import 'services/alert_preferences_service.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';
import 'services/budget_alert_service.dart';
import 'services/gemini_api_service.dart';
import 'services/collection_service.dart';
import 'services/custom_document_type_service.dart';
import 'services/document_scanner_service.dart';
import 'services/entitlement_service.dart';
import 'services/error_capture_service.dart';
import 'services/notification_tap_service.dart';
import 'services/finance_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
import 'services/urgency_engine.dart';
import 'services/notification_service.dart';
import 'services/perf_tracing_service.dart';
import 'services/rating_prompt_ui.dart';
import 'services/storage_migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error hooks first, so even startup crashes are captured.
  ErrorCaptureService.instance.install();

  // Wire the native in-app review sheet into the soft rating prompt.
  RatingPromptUi.register();

  // Frame-time monitor: debug/profile only, zero cost in release. Wires
  // DevTools timeline sections too (trace/traceAsync call sites).
  PerfTracingService.instance.startFrameMonitor();
  PerfTracingService.markFlow(PerfTracingService.flowColdStartToHome);

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load the user's theme preference before the first frame.
  await ThemeService.instance.init();

  // Supabase must be initialised once, before any service that uses it.
  // Credentials come from AppCredentials (lib/config/app_credentials.dart).
  // Without them the app runs in local-only mode.
  await SupabaseService.initialize();

  // Local app-lock state must be known before the first frame so a cold start
  // with a passcode set is already protected (see AppLockGate).
  await AppLockService.instance.init();

  // Alert toggles must load before the budget alert engine starts
  // evaluating, so a disabled alert never fires on cold start.
  await AlertPreferencesService.instance.load();

  // Budget alerts listen to finance data changes for the whole app lifetime
  // (OS notifications + Money-tab badge + snackbars).
  await BudgetAlertService.instance.init();
  unawaited(GeminiApiService.instance.load()); // optional LLM key for AI features

  // One-time rebrand migration: move locally stored documents from the
  // legacy Wazy folder (/wazy/documents) to the Finavig folder.
  await StorageMigrationService.migrate();

  // Prewarm services. Auth session is restored from secure storage by
  // supabase_flutter during Supabase.initialize, so by this point
  // AuthService.isSignedIn is already correct on cold start.
  await _prewarmServices();

  // Route notification taps to the tapped document (cold start included).
  // After prewarm so the router mounts with services loaded; a very early
  // tap is stashed as pendingDocumentId and consumed by the app shell.
  unawaited(NotificationTapService.instance.init());

  runApp(const FinavigApp());
}

/// Initialise the services that don't depend on auth first, then the
/// Supabase-backed ones (only meaningful when a session exists).
Future<void> _prewarmServices() async {
  await Future.wait([
    UrgencyEngine().init(),
    NotificationService().init(),
  ]);

  if (AuthService.instance.isSignedIn) {
    // Custom types must load before documents: rows are decoded into
    // ExpiryItems during init and need the registry to resolve doc_type keys.
    await CustomDocumentTypeService.instance.init();
    await Future.wait([
      DocumentCollectionService.instance.init(),
      DocumentScannerService.instance.init(),
      FinanceService.instance.init(),
      // Track 1: resolve the user's granted tier for feature gating.
      EntitlementService.instance.init(),
    ]);

    // Initial evaluation once finance data is loaded (catches thresholds
    // crossed while the app was closed — e.g. an auto-logged rent payment
    // pushing a budget past 100%).
    unawaited(BudgetAlertService.instance.evaluateNow());

    // Bring the OS-scheduled reminders back in sync with the loaded
    // documents (clears stale entries, schedules the 90/60/30/7 ladder).
    try {
      final items = await DocumentScannerService.instance.getAllItems();
      await NotificationService.instance.resyncAll(
        items
            .map((i) => (id: i.id, name: i.displayName, expiresAt: i.expiresAt))
            .toList(),
      );
    } catch (_) {
      // Best-effort: never block startup over reminders.
    }
  }
}
