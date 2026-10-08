// Redesigned Settings (Profile) screen: a clean, airy list — centred title,
// circular avatar with name/email, then full-width white rows. The detailed
// controls live behind bottom sheets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/profile_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    ThemeData? theme,
    void Function(FlutterErrorDetails)? onError,
  }) async {
    if (onError != null) {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        onError(details);
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? FinavigTheme.light(),
        home: const ProfileScreen(),
      ),
    );
    await tester.pump(); // collections load
    await tester.pump(const Duration(seconds: 1)); // settings load
  }

  const rows = [
    'Manage profile',
    'Customize my experience',
    'Manage notifications',
    'My Collections',
    'Manage subscription',
    'Security & App Lock',
    'AI Summary',
    'FAQ',
    'App guide',
    'Submit a request',
    'My requests',
    'Ensure reminders work',
    'Download my data',
    'Delete account',
  ];

  testWidgets('renders the flat list layout', (tester) async {
    await pumpSettings(tester);

    // Centred title, no AppBar.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    for (final label in rows) {
      expect(find.text(label), findsOneWidget, reason: '"$label" row missing');
    }

    // The theme control lives behind the "Customize my experience" row.
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
  });

  testWidgets('Customize my experience opens the appearance sheet',
      (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.text('Customize my experience'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize my experience'));
    await tester.pumpAndSettle();

    // The segmented control is now on screen inside the sheet.
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without errors in dark mode', (tester) async {
    await pumpSettings(tester, theme: FinavigTheme.dark());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('FAQ'), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list fits a narrow phone viewport without overflowing',
      (tester) async {
    // iPhone-sized viewport — the rows must not overflow.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0; // logical width ≈ 393
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    await pumpSettings(tester, onError: errors.add);

    final overflows = errors
        .map((e) =>
            '${e.exception}\n${e.informationCollector?.call().join('\n') ?? ''}')
        .where((s) => s.contains('overflowed'))
        .toList();
    expect(overflows, isEmpty,
        reason: 'The list must not overflow at 393px width: $overflows');
  });
}
