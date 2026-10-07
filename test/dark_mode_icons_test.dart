// Dark-mode icon contract.
//
// In dark mode every icon is white, except the ones that carry meaning:
// urgency (red/amber/green), income/expense and tier gold keep their colour
// so status is still readable at a glance. These tests pin that contract at
// the theme level, the shared widget level and the live shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/router.dart';
import 'package:finavig/screens/money/money_sections.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/bento_icon_tile.dart';

/// Resolves the colour an [Icon] actually paints with, following the
/// inherited [IconTheme] when the widget itself sets no colour.
Color resolvedIconColor(WidgetTester tester, Finder iconFinder) {
  final element = tester.element(iconFinder);
  final widget = element.widget as Icon;
  return widget.color ?? IconTheme.of(element).color!;
}

Future<void> pumpIn(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? FinavigTheme.dark()
          : FinavigTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('theme contract', () {
    testWidgets('every colourless icon is pure white in dark mode',
        (tester) async {
      await pumpIn(tester, const Icon(Icons.star_rounded),
          brightness: Brightness.dark);
      expect(resolvedIconColor(tester, find.byIcon(Icons.star_rounded)),
          Colors.white);
    });

    testWidgets('ListTile icons are white in dark mode', (tester) async {
      await pumpIn(
        tester,
        const ListTile(leading: Icon(Icons.folder_rounded), title: Text('x')),
        brightness: Brightness.dark,
      );
      expect(resolvedIconColor(tester, find.byIcon(Icons.folder_rounded)),
          Colors.white);
    });

    testWidgets('light mode is untouched — ListTile icons stay muted',
        (tester) async {
      await pumpIn(
        tester,
        const ListTile(leading: Icon(Icons.folder_rounded), title: Text('x')),
        brightness: Brightness.light,
      );
      expect(
        resolvedIconColor(tester, find.byIcon(Icons.folder_rounded)),
        FinavigColors.textSecondaryLight,
      );
    });
  });

  group('adaptiveIcon helper', () {
    testWidgets('returns white on dark and the passed colour on light',
        (tester) async {
      late BuildContext darkCtx;
      late BuildContext lightCtx;
      await pumpIn(
        tester,
        Builder(builder: (c) {
          darkCtx = c;
          return const SizedBox.shrink();
        }),
        brightness: Brightness.dark,
      );
      expect(FinavigColors.adaptiveIcon(darkCtx, FinavigColors.textMuted),
          Colors.white);

      await pumpIn(
        tester,
        Builder(builder: (c) {
          lightCtx = c;
          return const SizedBox.shrink();
        }),
        brightness: Brightness.light,
      );
      expect(FinavigColors.adaptiveIcon(lightCtx, FinavigColors.textMuted),
          FinavigColors.textMuted);
    });
  });

  group('shared widgets', () {
    testWidgets('SectionHeader icon is white in dark, muted in light',
        (tester) async {
      await pumpIn(
        tester,
        const SectionHeader(icon: Icons.list_alt_rounded, title: 'Records'),
        brightness: Brightness.dark,
      );
      expect(resolvedIconColor(tester, find.byIcon(Icons.list_alt_rounded)),
          Colors.white);

      await pumpIn(
        tester,
        const SectionHeader(icon: Icons.list_alt_rounded, title: 'Records'),
        brightness: Brightness.light,
      );
      expect(resolvedIconColor(tester, find.byIcon(Icons.list_alt_rounded)),
          FinavigTheme.light().colorScheme.outline);
    });

    testWidgets('icons on a tinted chip are white in dark mode',
        (tester) async {
      const tile = BentoIconTile(
        icon: Icons.folder_rounded,
        color: FinavigColors.orange,
        tint: FinavigColors.orangeTint,
      );
      await pumpIn(tester, tile, brightness: Brightness.dark);
      expect(resolvedIconColor(tester, find.byIcon(Icons.folder_rounded)),
          Colors.white);

      await pumpIn(tester, tile, brightness: Brightness.light);
      expect(resolvedIconColor(tester, find.byIcon(Icons.folder_rounded)),
          FinavigColors.orange);
    });
  });

  group('live shell', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'hasOnboarded': true,
        'hasSeenWelcome': true,
        'hasSeenAppGuide': true,
      });
    });

    testWidgets('bottom-nav quick action orb and tab icons read white',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          theme: FinavigTheme.light(),
          darkTheme: FinavigTheme.dark(),
          themeMode: ThemeMode.dark,
          routerConfig: router,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      router.go('/home');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The + orb keeps its white glyph.
      expect(
        resolvedIconColor(tester, find.byIcon(Icons.add_rounded).first),
        Colors.white,
      );

      // The active tab is pure white; the others are white, dimmed only
      // enough to keep the current tab legible.
      final navIcons = <Color>[
        for (final icon in const [
          Icons.home_rounded,
          Icons.account_balance_wallet_rounded,
        ])
          if (find.byIcon(icon).evaluate().isNotEmpty)
            resolvedIconColor(tester, find.byIcon(icon).first),
      ];
      expect(navIcons, isNotEmpty);
      for (final c in navIcons) {
        expect(c.r, 1.0);
        expect(c.g, 1.0);
        expect(c.b, 1.0);
        expect(c.a, greaterThanOrEqualTo(0.6));
      }
    });
  });
}
