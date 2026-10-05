import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/router.dart';
import 'package:finavig/services/supabase_service.dart';
import 'package:finavig/theme/app_theme.dart';

/// End-to-end regression test for the "new signup never sees onboarding" bug.
///
/// Runs against the real Supabase project configured in AppCredentials
/// (mailer_autoconfirm is ON, so signUp returns a live session), clears the
/// device prefs so the app is treated as a first launch, then walks the real
/// sign-up quiz — email → password → (DOB) → (country) → (phone) — and asserts
/// the onboarding tour is what appears on completion (NOT Home).
///
/// Run:
///   flutter test integration_test/signup_onboarding_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('brand-new signup lands on onboarding, not Home',
      (tester) async {
    // Real backend: without this AuthService.isAvailable is false in tests.
    await SupabaseService.initialize();
    expect(SupabaseService.isInitialized, isTrue,
        reason: 'Supabase credentials must be configured for this test');

    // Fresh-install state: first launch should route splash → /welcome.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: FinavigTheme.light()),
    );

    // Let the splash do its version check + 1s dwell and route to /welcome.
    await _waitForText(tester, 'Continue to Login',
        timeoutSeconds: 30, context: 'splash → welcome');

    // Welcome → login.
    await tester.tap(find.text('Continue to Login'));
    await _waitForText(tester, 'Sign up',
        timeoutSeconds: 20, context: 'welcome → login');

    // Switch the login quiz into sign-up mode.
    await tester.tap(find.text('Sign up').first);
    await _waitForText(tester, "First — what's your email?",
        timeoutSeconds: 10, context: 'login → signup mode');

    // Step 0 — email (unique per run so re-runs never collide).
    final email =
        'finavig.qa.${DateTime.now().millisecondsSinceEpoch}@gmail.com';
    await _typeIntoField(tester, email);
    await tester.tap(find.text('Continue'));
    await _waitForText(tester, 'Create a password',
        timeoutSeconds: 10, context: 'email → password');

    // Step 1 — password.
    await _typeIntoField(tester, 'Finavig123!');
    await tester.tap(find.text('Continue'));
    await _waitForText(tester, 'When were you born?',
        timeoutSeconds: 10, context: 'password → DOB');

    // Step 2 — DOB is optional: skip.
    await tester.tap(find.text('Continue'));
    await _waitForText(tester, 'Where are you based?',
        timeoutSeconds: 10, context: 'DOB → country');

    // Step 3 — country defaults to UAE: accept.
    await tester.tap(find.text('Continue'));
    await _waitForText(tester, 'Create account',
        timeoutSeconds: 10, context: 'country → phone');

    // Step 4 — phone is optional; "Create account" submits the quiz.
    await tester.tap(find.text('Create account'));

    // Wait for the real Supabase signUp round-trip and post-auth refresh.
    // This is the actual assertion: a new signup must land on /onboarding.
    await _waitForText(tester, 'Upload your documents',
        timeoutSeconds: 45, context: 'signup → onboarding');

    expect(find.text('Upload your documents'), findsOneWidget,
        reason: 'a new signup must see the onboarding tour, not Home');
    expect(find.text('Net this month'), findsNothing,
        reason: 'Home must not be shown straight after signup');
    expect(tester.takeException(), isNull);
  });
}

/// Focuses the on-screen text field, types [value], and confirms the text
/// actually reached it — on a real device `enterText` alone can no-op if the
/// field has not yet been focused, which silently fails step validation.
Future<void> _typeIntoField(WidgetTester tester, String value) async {
  final field = find.byType(TextFormField).first;
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(field, value);
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(value), findsOneWidget,
      reason: 'text "$value" should be visible in the focused field');
}

/// Pumps until a widget with [text] exists, or fails with a dump of what is
/// actually on screen — live HTTP means fixed delays are unreliable here.
Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  required int timeoutSeconds,
  required String context,
}) async {
  for (var i = 0; i < timeoutSeconds * 10; i++) {
    if (find.text(text).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  final onScreen = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((t) => t != null)
      .take(20)
      .join(' | ');
  fail('At "$context": never found "$text". On screen: $onScreen');
}
