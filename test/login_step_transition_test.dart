import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/screens/login_screen.dart';

/// The login quiz swaps steps of different heights (step 0 carries two answer
/// cards, step 1 a single field). The container used to hold the taller
/// outgoing step for the whole cross-fade and then collapse in one frame,
/// which kicked the incoming email field ~82 px up and back down.
///
/// These tests pin the fixed behaviour: the height settles *during* the
/// cross-fade, continuously and in one direction, and lands on a stable
/// resting position.
///
/// Measured on the fix: the biggest single-frame move is ~11 px; before it,
/// one frame carried the whole 82 px.
const double _kMaxFrameStep = 14.0;

Future<void> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Wide enough for the test font (Ahem renders every glyph as a square, so
  // the footer links are far wider than with a real font) and tall enough that
  // the quiz is genuinely centre-aligned — which is what makes a step of a
  // different height move everything above it.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  // Step 0: pick a user type, then advance.
  await tester.tap(find.text('New to Finavig'));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('step change settles continuously, with no single-frame jump',
      (tester) async {
    await _pumpLogin(tester);

    final samples = <double>[];
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      samples.add(tester.getTopLeft(find.text("What's your email?")).dy);
    }

    final deltas = <double>[
      for (var i = 1; i < samples.length; i++) samples[i] - samples[i - 1],
    ];

    final biggest = deltas.reduce((a, b) => a.abs() > b.abs() ? a : b);
    expect(
      biggest.abs(),
      lessThan(_kMaxFrameStep),
      reason: 'the step content moved ${biggest.toStringAsFixed(1)} px in a '
          'single frame — that is the snap this transition must not have '
          '(samples: ${samples.map((s) => s.toStringAsFixed(1)).join(', ')})',
    );

    // Smooth means one direction: no bounce back before it settles.
    for (final delta in deltas) {
      expect(delta, greaterThanOrEqualTo(-0.01),
          reason: 'the step content must not reverse direction mid-transition');
    }

    // It has to actually move — a passing test on a frozen layout would
    // prove nothing.
    expect(samples.last - samples.first, greaterThan(40.0),
        reason: 'the step content should glide to its new position');

    // Let the screen's deferred focus request land, so no timer outlives the
    // test.
    await tester.pump(const Duration(milliseconds: 80));
  });

  testWidgets('the settled position is stable once the transition ends',
      (tester) async {
    await _pumpLogin(tester);

    await tester.pump(const Duration(milliseconds: 320));
    final settled = tester.getTopLeft(find.text("What's your email?")).dy;

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(find.text("What's your email?")).dy,
        settled,
        reason: 'the field drifted after the transition had finished',
      );
    }
  });
}
