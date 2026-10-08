import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/finavig_wordmark.dart';

/// The Finavig wordmark's blue dot.
///
/// The word is set with a dotless `i` so the font draws no dot of its own;
/// this file guards (a) that the dot exists and is the brand blue, and (b) that
/// it is actually placed *on the letter* — centred on the i's advance box and
/// sitting at Inter's dot height above the baseline — rather than at a
/// hardcoded screen offset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wordmarkStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: FinavigColors.ink,
  );

  /// Mounts the wordmark alone, optionally under a system text scale.
  Future<void> pumpWordmark(WidgetTester tester, {double scale = 1.0}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Center(child: FinavigWordmark(style: wordmarkStyle)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  TextStyle renderedStyle(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(FinavigWordmark),
          matching: find.byType(Text),
        ),
      )
      .style!;

  testWidgets('sets a dotless i and draws the blue dot', (tester) async {
    await pumpWordmark(tester);

    final base = tester.widget<Text>(
      find.descendant(
        of: find.byType(FinavigWordmark),
        matching: find.byType(Text),
      ),
    );
    // The first "i" is the dotless U+0131, so the font cannot draw a second,
    // ink dot beside the blue one.
    expect(base.textSpan!.toPlainText(), FinavigWordmark.dotlessText);
    expect(base.textSpan!.toPlainText().startsWith('F\u0131'), isTrue);
    expect(find.text('Finavig'), findsNothing);

    final dot = tester.widget<Container>(find.byKey(FinavigWordmark.dotKey));
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, FinavigColors.accentBright);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dot sits on the i, above the baseline', (tester) async {
    await pumpWordmark(tester);

    final style = renderedStyle(tester);
    final painter = TextPainter(
      text: TextSpan(text: FinavigWordmark.dotlessText, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();

    final iOriginX = painter
        .getOffsetForCaret(const TextPosition(offset: 1), Rect.zero)
        .dx;
    final iEndX = painter
        .getOffsetForCaret(const TextPosition(offset: 2), Rect.zero)
        .dx;
    final baselineY = painter.computeLineMetrics().first.baseline;
    painter.dispose();

    final wordmark = tester.getRect(find.byType(FinavigWordmark));
    final dot = tester.getRect(find.byKey(FinavigWordmark.dotKey));
    final localDotCenter = dot.center - wordmark.topLeft;

    // On the letter: inside the i's advance box…
    expect(
      localDotCenter.dx,
      inInclusiveRange(iOriginX, iEndX),
      reason: 'the dot must land on the i, not between letters',
    );
    // …sized to Inter's dot, and at its height above the baseline rather than
    // at the x-height (0.546em, where a lower dot would read as a diacritic).
    //
    // These are the font's own numbers, measured from
    // assets/fonts/Inter-Regular.ttf (2048 units/em), where `i` is the
    // composite `dotlessi + uni0307` and the dot outline is
    // x[124,375] y[1301,1539] — deliberately literal, so that editing the
    // widget's constants fails here and forces a re-measure of the font.
    const dotCenterXEm = 0.12183; // dot centre, from the glyph origin
    const dotCenterYEm = 0.69336; // dot centre, above the baseline
    const dotDiameterEm = 0.1216;

    final fontSize = style.fontSize!;
    expect(dot.width, closeTo(dotDiameterEm * fontSize, 0.1));
    expect(dot.height, closeTo(dotDiameterEm * fontSize, 0.1));
    expect(localDotCenter.dx, closeTo(iOriginX + dotCenterXEm * fontSize, 0.6));
    expect(
      localDotCenter.dy,
      closeTo(baselineY - dotCenterYEm * fontSize, 0.6),
      reason: "the dot must sit where Inter's own i dot would be",
    );
    expect(localDotCenter.dy, lessThan(baselineY));
    // Sanity: the widget's documented constants are the measured ones.
    expect(FinavigWordmark.dotCenterX, dotCenterXEm);
    expect(FinavigWordmark.dotCenterY, dotCenterYEm);
    expect(FinavigWordmark.dotDiameter, dotDiameterEm);

    // Inside the wordmark's own box, so nothing overflows the headline.
    expect(wordmark.contains(dot.center), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dot scales with the system text size', (tester) async {
    await pumpWordmark(tester);
    final small = tester.getRect(find.byKey(FinavigWordmark.dotKey));

    await pumpWordmark(tester, scale: 2.0);
    final large = tester.getRect(find.byKey(FinavigWordmark.dotKey));

    // A decorative dot must not stay 4px while the word doubles.
    expect(large.width, closeTo(small.width * 2, 0.5));
    expect(large.height, closeTo(small.height * 2, 0.5));
    expect(large.width, closeTo(large.height, 0.01));
    expect(tester.takeException(), isNull);
  });
}
