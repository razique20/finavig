// Theme-transition smoothness.
//
// MaterialApp lerps the whole ThemeData over its theme animation, but the
// lerped `brightness` only flips halfway through it. Any colour computed as
// `isDark ? dark : light` therefore jumps in one frame while everything
// around it is still interpolating — the "blink" the Home categories tiles
// showed when switching themes.
//
// These tests sample the tiles *during* the animation and require the values
// to sit between the two endpoints, which is exactly what the old
// `isDark ? … : …` version failed to do.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/router.dart';
import 'package:finavig/screens/home/home_banners.dart';
import 'package:finavig/screens/home/home_categories_grid.dart';
import 'package:finavig/services/theme_service.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  /// Mounts the categories grid under the real app themes and returns a way to
  /// flip the mode without rebuilding from scratch.
  Future<StateSetter> mount(WidgetTester tester) async {
    late StateSetter setter;
    var mode = ThemeMode.light;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) {
          setter = set;
          return MaterialApp(
            theme: FinavigTheme.light(),
            darkTheme: FinavigTheme.dark(),
            themeMode: mode,
            home: Scaffold(
              body: HomeCategoriesGrid(
                pendingActionsCount: 0,
                onScanTap: () async {},
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return (fn) {
      fn();
      setter(() => mode = ThemeMode.dark);
    };
  }

  Material tileMaterial(WidgetTester tester) => tester.widget<Material>(
        find
            .ancestor(of: find.text('Documents'), matching: find.byType(Material))
            .first,
      );

  Color tileIconColor(WidgetTester tester) {
    final element = tester.element(
      find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('Documents'),
                  matching: find.byType(Material),
                )
                .first,
            matching: find.byType(Icon),
          )
          .first,
    );
    return (element.widget as Icon).color ?? IconTheme.of(element).color!;
  }

  /// True when [value] lies strictly between the two endpoints.
  bool strictlyBetween(double value, double a, double b) {
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    return value > lo + 1e-6 && value < hi - 1e-6;
  }

  testWidgets('categories tile background cross-fades between the themes',
      (tester) async {
    final flip = await mount(tester);
    expect(tileMaterial(tester).color, Colors.white);

    flip(() {});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final mid = tileMaterial(tester).color!;
    // Between white (light) and slate @ 50% (dark) on every channel — the old
    // discrete branch produced the dark colour instantly here.
    expect(strictlyBetween(mid.r, 1.0, FinavigColors.slate.r), isTrue,
        reason: 'tile red channel must be mid-transition, was ${mid.r}');
    expect(strictlyBetween(mid.a, 1.0, 0.5), isTrue,
        reason: 'tile alpha must be mid-transition, was ${mid.a}');

    await tester.pumpAndSettle();
    // Dark endpoint unchanged: the slate tile at half opacity.
    final settled = tileMaterial(tester).color!;
    expect(settled.r, FinavigColors.slate.r);
    expect(settled.g, FinavigColors.slate.g);
    expect(settled.b, FinavigColors.slate.b);
    expect(settled.a, closeTo(0.5, 0.002));
  });

  testWidgets('categories tile icon cross-fades from brand violet to white',
      (tester) async {
    final flip = await mount(tester);
    expect(tileIconColor(tester), FinavigColors.violet);

    flip(() {});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final mid = tileIconColor(tester);
    expect(strictlyBetween(mid.r, FinavigColors.violet.r, 1.0), isTrue,
        reason: 'icon red channel must be mid-transition, was ${mid.r}');

    await tester.pumpAndSettle();
    expect(tileIconColor(tester), Colors.white,
        reason: 'dark endpoint must stay white');
  });

  testWidgets('tile label colour cross-fades too', (tester) async {
    final flip = await mount(tester);
    final labelStyle = () => tester
        .widget<Text>(find.text('Documents'))
        .style!
        .color!;
    expect(labelStyle(), FinavigColors.textPrimaryLight);

    flip(() {});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      strictlyBetween(
        labelStyle().r,
        FinavigColors.textPrimaryLight.r,
        FinavigColors.textSecondary.r,
      ),
      isTrue,
      reason: 'label must fade, not snap — was ${labelStyle().r}',
    );

    await tester.pumpAndSettle();
    expect(labelStyle(), FinavigColors.textSecondary);
  });

  testWidgets('a chip tile fades its tint opacity instead of jumping',
      (tester) async {
    final flip = await mount(tester);
    Color tint() => (tester
            .widget<Container>(
              find
                  .descendant(
                    of: find
                        .ancestor(
                          of: find.text('Documents'),
                          matching: find.byType(Material),
                        )
                        .first,
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration as BoxDecoration)
        .color!;
    expect(tint().a, closeTo(0.11, 1e-6));

    flip(() {});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(strictlyBetween(tint().a, 0.11, 0.16), isTrue,
        reason: 'chip tint opacity must ramp, was ${tint().a}');

    await tester.pumpAndSettle();
    expect(tint().a, closeTo(0.16, 1e-6));
  });

  // The floating nav dock ("universal" quick action + 4 tabs) and the Home
  // banners had the same snapping colours.
  group('nav dock', () {
    Future<StateSetter> mountShell(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'hasOnboarded': true,
        'hasSeenWelcome': true,
        'hasSeenAppGuide': true,
      });
      late StateSetter setter;
      var mode = ThemeMode.light;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            setter = set;
            return MaterialApp.router(
              theme: FinavigTheme.light(),
              darkTheme: FinavigTheme.dark(),
              themeMode: mode,
              routerConfig: router,
            );
          },
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      router.go('/home');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return (fn) {
        fn();
        setter(() => mode = ThemeMode.dark);
      };
    }

    /// The floating pill: the only 30px-radius container on screen.
    Container pill(WidgetTester tester) =>
        tester.widgetList<Container>(find.byType(Container)).firstWhere((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.borderRadius == BorderRadius.circular(30);
        });

    Color inactiveIconColor(WidgetTester tester) {
      final element = tester.element(find.byIcon(Icons.person_outline_rounded));
      return (element.widget as Icon).color ?? IconTheme.of(element).color!;
    }

    testWidgets('pill background cross-fades instead of snapping',
        (tester) async {
      final flip = await mountShell(tester);
      final light = (pill(tester).decoration as BoxDecoration).color;
      expect(light, Colors.white);

      flip(() {});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final mid = (pill(tester).decoration as BoxDecoration).color!;
      expect(strictlyBetween(mid.r, 1.0, FinavigColors.slate.r), isTrue,
          reason: 'pill must be mid-transition, was ${mid.r}');
      expect(strictlyBetween(mid.a, 1.0, 0.92), isTrue,
          reason: 'pill alpha must be mid-transition, was ${mid.a}');

      await tester.pumpAndSettle();
      final settled = (pill(tester).decoration as BoxDecoration).color!;
      expect(settled.r, FinavigColors.slate.r);
      expect(settled.a, closeTo(0.92, 0.002));
    });

    testWidgets('inactive tab icons cross-fade from grey to white',
        (tester) async {
      final flip = await mountShell(tester);
      expect(inactiveIconColor(tester), FinavigColors.textMutedLight);

      flip(() {});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final mid = inactiveIconColor(tester);
      expect(
        strictlyBetween(mid.r, FinavigColors.textMutedLight.r, 1.0),
        isTrue,
        reason: 'inactive icon must fade to white, was ${mid.r}',
      );

      await tester.pumpAndSettle();
      final settled = inactiveIconColor(tester);
      expect(settled.r, 1.0);
      expect(settled.a, closeTo(0.65, 0.002));
    });
  });

  // The Settings (Profile) page: same snapping surfaces, plus its Appearance
  // segmented control, which lives in a kept-alive shell page.
  group('settings page', () {
    Future<StateSetter> mountSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'hasOnboarded': true,
        'hasSeenWelcome': true,
        'hasSeenAppGuide': true,
      });
      await ThemeService.instance.setMode(ThemeMode.system);
      addTearDown(() => ThemeService.instance.setMode(ThemeMode.system));

      late StateSetter setter;
      var mode = ThemeMode.light;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            setter = set;
            return MaterialApp.router(
              theme: FinavigTheme.light(),
              darkTheme: FinavigTheme.dark(),
              themeMode: mode,
              routerConfig: router,
            );
          },
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      router.go('/profile');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return (fn) {
        fn();
        setter(() => mode = ThemeMode.dark);
      };
    }

    /// The grouped card wrapping the section that owns [label] — anchored on a
    /// child row/control, since the section title sits above the card.
    Container sectionTile(WidgetTester tester, String label) => tester
        .widgetList<Container>(
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        )
        .firstWhere((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.borderRadius == BorderRadius.circular(FinavigRadius.card);
        });

    testWidgets('section tiles cross-fade instead of snapping',
        (tester) async {
      final flip = await mountSettings(tester);
      expect(
        (sectionTile(tester, 'System').decoration as BoxDecoration).color,
        Colors.white,
      );

      flip(() {});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final mid =
          (sectionTile(tester, 'System').decoration as BoxDecoration).color!;
      expect(strictlyBetween(mid.r, 1.0, FinavigColors.slate.r), isTrue,
          reason: 'settings tile must be mid-transition, was ${mid.r}');
      expect(strictlyBetween(mid.a, 1.0, 0.5), isTrue,
          reason: 'settings tile alpha must be mid-transition, was ${mid.a}');

      await tester.pumpAndSettle();
      final settled =
          (sectionTile(tester, 'System').decoration as BoxDecoration).color!;
      expect(settled.r, FinavigColors.slate.r);
      expect(settled.a, closeTo(0.5, 0.002));
    });

    testWidgets('appearance selector moves to the tapped mode', (tester) async {
      await mountSettings(tester);

      Set<ThemeMode> selection() => tester
          .widget<SegmentedButton<ThemeMode>>(
            find.byType(SegmentedButton<ThemeMode>),
          )
          .selected;

      expect(selection(), {ThemeMode.system});

      await tester.ensureVisible(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(ThemeService.instance.mode, ThemeMode.dark);
      expect(selection(), {ThemeMode.dark},
          reason: 'the selected box must follow the tap, not stay on the old mode');

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(selection(), {ThemeMode.system});
    });
  });

  group('renewals-need-attention banner', () {
    Future<StateSetter> mountBanner(WidgetTester tester) async {
      late StateSetter setter;
      var mode = ThemeMode.light;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            setter = set;
            return MaterialApp(
              theme: FinavigTheme.light(),
              darkTheme: FinavigTheme.dark(),
              themeMode: mode,
              home: Scaffold(
                body: HomeAttentionBanner(
                  pendingActionNames: const ['Trade Licence', 'Visa'],
                  dismissedAttentionCount: null,
                  onDismiss: (_) {},
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      return (fn) {
        fn();
        setter(() => mode = ThemeMode.dark);
      };
    }

    Container bannerBox(WidgetTester tester) =>
        tester.widgetList<Container>(find.byType(Container)).firstWhere((c) {
          final d = c.decoration;
          return d is BoxDecoration && d.border != null;
        });

    Color titleColour(WidgetTester tester) => tester
        .widget<Text>(find.textContaining('need attention'))
        .style!
        .color!;

    testWidgets('banner surface and title cross-fade', (tester) async {
      final flip = await mountBanner(tester);
      const lightBg = Color(0xFFFEF2F2);
      const darkBg = Color(0xFF451A1A);
      expect((bannerBox(tester).decoration as BoxDecoration).color, lightBg);

      flip(() {});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final midBg = (bannerBox(tester).decoration as BoxDecoration).color!;
      expect(strictlyBetween(midBg.r, lightBg.r, darkBg.r), isTrue,
          reason: 'banner bg must be mid-transition, was ${midBg.r}');
      expect(
        strictlyBetween(titleColour(tester).r, const Color(0xFF991B1B).r, 1.0),
        isTrue,
        reason: 'banner title must be mid-transition, was ${titleColour(tester).r}',
      );

      await tester.pumpAndSettle();
      expect((bannerBox(tester).decoration as BoxDecoration).color, darkBg);
      expect(titleColour(tester), Colors.white);
    });
  });

  testWidgets('theme extension lerps in lockstep with theme-derived colours',
      (tester) async {
    final flip = await mount(tester);

    double progress(double value, double from, double to) =>
        (from - value) / (from - to);

    flip(() {});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final tile = tileMaterial(tester).color!;
    final context = tester.element(find.text('Documents'));
    final scaffold = Theme.of(context).scaffoldBackgroundColor;

    final tileProgress = progress(tile.r, 1.0, FinavigColors.slate.r);
    final themeProgress = progress(
      scaffold.r,
      FinavigTheme.light().scaffoldBackgroundColor.r,
      FinavigTheme.dark().scaffoldBackgroundColor.r,
    );

    // Within one frame of the theme's own animation.
    expect((tileProgress - themeProgress).abs(), lessThan(0.1),
        reason: 'tile ($tileProgress) must track the theme ($themeProgress)');
  });
}
