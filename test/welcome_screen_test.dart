import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login Page')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('WelcomeScreen renders brand image, monogram and Continue to Login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Full-bleed brand artwork behind everything.
    expect(
      find.byWidgetPredicate((w) =>
          w is Image &&
          w.image == const AssetImage('assets/images/splash_bg.jpg')),
      findsOneWidget,
    );
    // FV monogram and wordmark.
    expect(find.text('FV'), findsOneWidget);
    expect(find.text('Finavig'), findsOneWidget);
    // Single CTA.
    expect(
      find.widgetWithText(ElevatedButton, 'Continue to Login'),
      findsOneWidget,
    );
  });

  testWidgets('Continue to Login persists flag and navigates to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester
        .tap(find.widgetWithText(ElevatedButton, 'Continue to Login'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenWelcome'), isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });
}
