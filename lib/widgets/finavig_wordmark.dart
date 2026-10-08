import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gcc_country.dart';
import '../theme/app_theme.dart';

/// The **Finavig** wordmark with the dot of the “i” in brand blue.
///
/// A font cannot colour one part of a glyph, so the word is set with a
/// *dotless* i (`U+0131`) and the dot is drawn over it. Inter builds its `i`
/// as the composite `dotlessi + uni0307`, and `dotlessi` shares both the stem
/// **and the advance width** with `i` (496 units each), so swapping it in
/// leaves the word's spacing pixel-identical — only the font's own dot
/// disappears.
///
/// The blue dot is then placed on the glyph rather than guessed at: [build]
/// lays the word out with a [TextPainter] to read the paragraph's baseline and
/// the caret position of the i, and offsets the dot by the metrics below,
/// measured from the bundled font (`assets/fonts/Inter-Regular.ttf`,
/// 2048 units/em) where the i's dot outline is `x[124,375] y[1301,1539]`:
///
/// | metric | em |
/// |---|---|
/// | dot centre from the baseline | [dotCenterY] |
/// | dot centre from the glyph origin | [dotCenterX] |
/// | dot diameter | [dotDiameter] |
///
/// Being em-based, the dot tracks any font size and the system text scale. If
/// the brand font ever changes, re-measure these three values from the new
/// font's `i` glyph.
class FinavigWordmark extends StatelessWidget {
  /// The word with a dotless `i` (`U+0131`), which is what is actually set.
  static const String dotlessText = 'F\u0131navig';

  /// The blue dot, so tests can measure where it landed.
  static const Key dotKey = Key('finavig-wordmark-dot');

  // Inter's i-dot geometry, in em units (see the class docs).
  static const double dotCenterX = 0.12183; // from the glyph origin
  static const double dotCenterY = 0.69336; // above the baseline
  static const double dotDiameter = 0.1216;

  /// Floor for the dot so a very small wordmark cannot lose it entirely.
  static const double _minDotDiameter = 2.5;

  /// Style of the word — the dot inherits its size and letter spacing from it.
  final TextStyle style;

  /// Colour of the dot. Defaults to the bright brand blue, which stays
  /// unmistakably blue against the ink wordmark on a white page.
  final Color dotColor;

  const FinavigWordmark({
    super.key,
    required this.style,
    this.dotColor = FinavigColors.accentBright,
  });

  @override
  Widget build(BuildContext context) {
    // Merge with the ambient style exactly as Text would, then hand the same
    // object to the measuring painter so measurement and painting agree.
    final base = DefaultTextStyle.of(context).style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);

    final painter = TextPainter(
      text: TextSpan(text: dotlessText, style: base),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout();

    // Painted pixels per em, and the two anchors the dot is measured from.
    final em = textScaler.scale(base.fontSize ?? 14);
    final iOriginX = painter
        .getOffsetForCaret(const TextPosition(offset: 1), Rect.zero)
        .dx;
    final baselineY = painter.computeLineMetrics().first.baseline;
    painter.dispose();

    final diameter = math.max(_minDotDiameter, dotDiameter * em);
    final center = Offset(
      iOriginX + dotCenterX * em,
      baselineY - dotCenterY * em,
    );

    return Stack(
      // The dot sits inside the line box, but never clip the wordmark.
      clipBehavior: Clip.none,
      children: [
        // The style lives on the Text (not just the span) so the widget exposes
        // the same effective style it paints with.
        Text.rich(TextSpan(text: dotlessText), style: base),
        Positioned(
          left: center.dx - diameter / 2,
          top: center.dy - diameter / 2,
          width: diameter,
          height: diameter,
          child: Container(
            key: dotKey,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}
