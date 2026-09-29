import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/widgets/cards/first_run_guide_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('hidden when guide already seen', (tester) async {
    SharedPreferences.setMockInitialValues({'hasSeenAppGuide': true});
    await tester.pumpWidget(wrap(const FirstRunGuideBanner()));
    await tester.pumpAndSettle();
    expect(find.text('New here?'), findsNothing);
  });

  testWidgets('shows when guide unseen, Later dismisses permanently',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap(const FirstRunGuideBanner()));
    await tester.pumpAndSettle();
    expect(find.text('New here?'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('New here?'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('firstRunGuideBannerDismissed'), isTrue);
  });
}
