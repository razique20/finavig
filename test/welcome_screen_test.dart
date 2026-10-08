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

  testWidgets('WelcomeScreen renders headline, quote thread and CTA',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Plain white, like the splash: no backdrop artwork on this screen.
    expect(find.byType(Image), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);
    // Main headline — no logo mark on this screen.
    expect(find.text('Finavig'), findsOneWidget);
    expect(find.text('FV'), findsNothing);
    // WhatsApp-style quote thread: two incoming quotes + a reply.
    expect(
      find.text('Do not save what is left after spending; '
          'spend what is left after saving.'),
      findsOneWidget,
    );
    expect(find.text('— Warren Buffett'), findsOneWidget);
    expect(
      find.text('An investment in knowledge pays the best interest.'),
      findsOneWidget,
    );
    expect(find.text('— Benjamin Franklin'), findsOneWidget);
    expect(find.text('Warren Buffett'), findsOneWidget);
    expect(
      find.text("That's Finavig — budgets, cash flow and "
          'document alerts in one secure place.'),
      findsOneWidget,
    );
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
