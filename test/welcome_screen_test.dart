import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/welcome_screen.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/finavig_wordmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login Page')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('WelcomeScreen renders headline, quote thread and CTA', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Plain white, like the splash: no backdrop artwork on this screen.
    expect(find.byType(Image), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);
    // Main headline — no logo mark on this screen. The wordmark sets a dotless
    // "i" so FinavigWordmark's blue dot can stand in for the font's own.
    expect(find.text(FinavigWordmark.dotlessText), findsOneWidget);
    expect(find.text('Finavig'), findsNothing);
    expect(find.text('FV'), findsNothing);
    expect(find.byKey(FinavigWordmark.dotKey), findsOneWidget);
    // WhatsApp-style quote thread: two incoming quotes + a reply.
    expect(
      find.text(
        'Do not save what is left after spending; '
        'spend what is left after saving.',
      ),
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
      find.text(
        "That's Finavig — budgets, cash flow and "
        'document alerts in one secure place.',
      ),
      findsOneWidget,
    );
    // Single CTA.
    expect(
      find.widgetWithText(ElevatedButton, 'Continue to Login'),
      findsOneWidget,
    );
  });

  testWidgets('author names, time and CTA label wear the brand blue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    Color? colourOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    // On the light quote bubble the deep step keeps 11px text readable…
    expect(colourOf('— Warren Buffett'), FinavigColors.accent);
    expect(colourOf('— Benjamin Franklin'), FinavigColors.accent);
    // …while the name and time inside the ink reply bubble need the bright
    // step, which the deep accent would sink into.
    expect(colourOf('Warren Buffett'), FinavigColors.accentBright);
    expect(colourOf('9:39 PM'), FinavigColors.accentBright);

    // The CTA keeps its ink plate and a white label (see
    // brand_ink_consistency_test); the blue sits on the line below it.
    final cta = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to Login'),
    );
    expect(
      cta.style?.foregroundColor?.resolve(const <WidgetState>{}),
      Colors.white,
    );
    expect(
      tester
          .widget<Text>(
            find.text('Budgets · Cash flow · Document expiry alerts'),
          )
          .style
          ?.color,
      FinavigColors.accent,
    );
  });

  testWidgets('Continue to Login persists flag and navigates to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue to Login'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenWelcome'), isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });
}
