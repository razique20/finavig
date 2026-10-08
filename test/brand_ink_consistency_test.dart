import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/screens/home_screen.dart';
import 'package:finavig/screens/login_screen.dart';
import 'package:finavig/screens/welcome_screen.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/finavig_wordmark.dart';

/// One brand ink, four surfaces.
///
/// The Home balance card, the Welcome headline / CTA / reply bubble and the
/// Login CTA are all [FinavigColors.ink]. They must stay that: if the ink is
/// retuned, every surface moves together instead of one screen silently
/// drifting to a different navy (which reads black next to the others).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  test('the shared brand ink is the Home hero navy', () {
    expect(FinavigColors.ink, const Color(0xFF0F172A));
  });

  testWidgets('Welcome headline, CTA and reply bubble all use the brand ink', (
    tester,
  ) async {
    await pumpScreen(tester, const WelcomeScreen());

    // The wordmark sets a dotless "i" (the blue dot is drawn on top of it),
    // so the headline text is "Fınavig" rather than "Finavig".
    final headline = tester.widget<Text>(
      find.text(FinavigWordmark.dotlessText),
    );
    expect(
      headline.style?.color,
      FinavigColors.ink,
      reason: 'Welcome headline must be the Home hero navy',
    );

    final cta = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to Login'),
    );
    expect(
      cta.style?.backgroundColor?.resolve(const <WidgetState>{}),
      FinavigColors.ink,
      reason: 'Welcome CTA must be the Home hero navy',
    );

    // The outgoing reply bubble is the other ink plate on this screen.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == FinavigColors.ink,
      ),
      findsOneWidget,
      reason: 'Welcome reply bubble must be the Home hero navy',
    );
  });

  testWidgets('Login CTA uses the brand ink', (tester) async {
    await pumpScreen(tester, const LoginScreen());

    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(
      cta.style?.backgroundColor?.resolve(const <WidgetState>{}),
      FinavigColors.ink,
      reason: 'Login CTA must be the Home hero navy',
    );
  });

  testWidgets('Home balance card uses the brand ink', (tester) async {
    await pumpScreen(tester, const HomeScreen());

    // The top balance card is Home's "hero" plate — the same ink as the
    // Money tab's hero band.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == FinavigColors.ink,
      ),
      findsOneWidget,
      reason: 'Home top card must be the shared brand ink',
    );
  });
}
