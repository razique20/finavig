import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/indicators/empty_state_illustration.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester,
    EmptyStateScene scene, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: EmptyStateIllustration(scene: scene, size: 104),
          ),
        ),
      ),
    );
    // MaterialApp animates theme changes; let the transition finish so the
    // assertions below read the settled theme.
    await tester.pumpAndSettle();
  }

  const expectedIcons = {
    EmptyStateScene.document: Icons.description_outlined,
    EmptyStateScene.wallet: Icons.account_balance_wallet_outlined,
    EmptyStateScene.search: Icons.search_rounded,
    EmptyStateScene.growth: Icons.trending_up_rounded,
  };

  for (final entry in expectedIcons.entries) {
    testWidgets(
        '${entry.key.name} empty state draws the standard ${entry.value.codePoint} icon',
        (tester) async {
      await pumpScene(tester, entry.key, theme: FinavigTheme.light());

      // A real Material icon — not the hand-drawn CustomPaint artwork.
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(EmptyStateIllustration),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, entry.value);
      expect(
        find.descendant(
          of: find.byType(EmptyStateIllustration),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );

      // The mark scales with the requested size.
      expect(icon.size, closeTo(104 * 0.5, 0.01));

      // No backdrop: the icon paints on its own, with no tinted circle.
      expect(
        find.descendant(
          of: find.byType(EmptyStateIllustration),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('empty state icon follows the theme in light and dark mode',
      (tester) async {
    await pumpScene(
      tester,
      EmptyStateScene.document,
      theme: FinavigTheme.light(),
    );
    final lightIcon = tester.widget<Icon>(find.byType(Icon));
    expect(lightIcon.color, FinavigColors.navyPrimary);

    await pumpScene(
      tester,
      EmptyStateScene.document,
      theme: FinavigTheme.dark(),
    );
    final darkIcon = tester.widget<Icon>(find.byType(Icon));
    expect(darkIcon.color, FinavigColors.cyanAccent);
  });
}
