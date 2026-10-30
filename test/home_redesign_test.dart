import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/router.dart';
import 'package:finavig/screens/home_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() {
    // Mark the first-launch app guide as seen so its overlay never covers
    // the UI these layout tests interact with.
    SharedPreferences.setMockInitialValues({'hasSeenAppGuide': true});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: FinavigTheme.light(), home: const HomeScreen()),
    );
    // _loadData: collection + items + finance init.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('home renders hero header and categories grid', (tester) async {
    await pumpHome(tester);

    // Hero header content.
    expect(find.text('Net this month'), findsOneWidget);
    expect(find.text('Record'), findsNothing);
    expect(find.text('Budget'), findsNothing);

    // Content sheet sections. Budget actions live on the Money tab.
    expect(find.text('Categories'), findsNothing);
    expect(find.text('Budgets'), findsNothing);
    expect(find.text('Scan'), findsOneWidget);
    // Month card was removed — its details live in the hero header.
    expect(find.text('This month'), findsNothing);
  });

  testWidgets('floating nav pill stays compact at the bottom of the shell', (
    tester,
  ) async {
    // Supabase is unavailable in tests → auth gate is off → /home renders.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2)); // splash delay elapses
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Home tab content is showing.
    expect(find.text('Net this month'), findsOneWidget);

    // The active home icon sits in the bottom ~12% of the screen — not
    // stretched across the full height (regression: unbounded nav pill).
    // Nav items are located via their tooltips (grid tiles reuse icons).
    final iconCenter = tester.getCenter(find.byTooltip('Home'));
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(iconCenter.dy, greaterThan(screenH * 0.85));

    // All four tab destinations are present (center search action was
    // removed from the pill).
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Money'), findsOneWidget);
    expect(find.byTooltip('Documents'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byTooltip('Search'), findsNothing);

    // Tap the Money tab through the pill and back home.
    await tester.tap(find.byTooltip('Money'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Add Record'), findsWidgets);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Net this month'), findsOneWidget);
  });

  testWidgets('category tiles navigate to their own pages', (tester) async {
    // Device-like viewport; the category shortcuts scroll horizontally.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Real router: the tiles navigate via context.push.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2)); // splash delay elapses
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Budgets tile removed from the grid — start with the Records tile.

    // Records tile → /records (grouped transaction log).
    await tester.ensureVisible(find.text('Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Records'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Add Record'), findsWidgets);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Envelopes tile → /envelopes.
    await tester.ensureVisible(find.text('Envelopes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envelopes'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Savings envelopes'), findsOneWidget);

    // The separate AI Budget Plan link opens the planner route.
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // The planner has wider content than the Home shortcuts; use a tablet-sized
    // viewport for this route assertion so it tests navigation, not its layout.
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(2400, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    await tester.ensureVisible(find.text('AI Budget Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Budget Plan'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('AI Budget Planner'), findsOneWidget);
  });

  testWidgets('Home balance card has no redundant Record or Budget buttons', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Record'), findsNothing);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('AI Budget Plan'), findsOneWidget);
  });

  testWidgets('home renders without overflowing a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0; // logical ≈ 393 wide
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d);
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    await pumpHome(tester);

    final overflows = errors
        .map(
          (e) =>
              '${e.exception}\n${e.informationCollector?.call().join('\n') ?? ''}',
        )
        .where((s) => s.contains('overflowed'))
        .toList();
    expect(
      overflows,
      isEmpty,
      reason: 'Home must not overflow at 393px width: $overflows',
    );
  });

  testWidgets('categories are in one horizontal row with a separate AI link', (
    tester,
  ) async {
    await pumpHome(tester);

    final scroller = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('home-category-scroller')),
    );
    expect(scroller.scrollDirection, Axis.horizontal);

    expect(find.text('Categories'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Renewals'), findsOneWidget);
    expect(find.text('Envelopes'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('AI Budget Plan'), findsOneWidget);
    expect(find.text('AI Planner'), findsNothing);
    expect(find.text('Scan'), findsOneWidget);
  });
}
