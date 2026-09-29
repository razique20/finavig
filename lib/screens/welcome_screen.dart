import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Pre-login welcome screen — the first thing a brand-new user sees.
///
/// Hero headline, an in-phone product preview ("Easy ways to manage your
/// finances" with a Get Started pill), and a full-width Get Started button
/// that advances to the login page.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final headlineSize = w < 400 ? 30.0 : 36.0;

                // The phone mockup is a fixed-aspect poster (9:18.5 inner
                // screen plus bezel), so its final height is ~1.94× its
                // width. Size it against BOTH axes: cap the width on narrow
                // screens, and cap the height so the headline and the CTA
                // stay visible without scrolling.
                final widthCap = w < 480 ? w * 0.62 : 380.0;
                final fixedVertical = 40 // top padding
                    +
                    headlineSize * 1.15 * 2 // two-line headline
                    +
                    28 +
                    28 // gaps above/below the mockup
                    +
                    56 +
                    28; // CTA height + bottom padding
                final heightCap = (h - fixedVertical) / 1.94;
                final mockupWidth =
                    math.max(150.0, math.min(widthCap, heightCap));
                // In-phone UI scale relative to the 380px design width.
                final s = (mockupWidth / 380).clamp(0.5, 1.2);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 40, 24, 0),
                          child: Text(
                            'Modern Fintech for\nPersonal Finance',
                            style: TextStyle(
                              fontSize: headlineSize,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: FinavigColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: _PhoneMockup(
                            width: mockupWidth,
                            scale: s,
                            onTap: _getStarted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _getStarted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FinavigColors.navyPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster-style phone frame on the violet field, matching the reference art:
/// a white screen with playful shapes, a blue blob with the wordmark, and a
/// "Easy ways to manage your finances" card with a Get Started pill.
///
/// [scale] shrinks the fixed-size in-phone art (corner shapes, blob, sparkles,
/// headline, pill) proportionally so nothing overflows the smaller frame.
class _PhoneMockup extends StatelessWidget {
  final double width;
  final double scale;
  final VoidCallback onTap;

  const _PhoneMockup({
    required this.width,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: FinavigColors.navyPrimary,
          borderRadius: BorderRadius.circular(width * 0.13),
        ),
        padding: EdgeInsets.all(width * 0.055),
        child: AspectRatio(
          aspectRatio: 9 / 18.5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.075),
              border: Border.all(color: const Color(0xFF111111), width: 3),
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(math.max(0, width * 0.075 - 3)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Corner accent shapes
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _ScaledArt(s, 110, 90, const _CornerShapes()),
                  ),
                  // Sparkle top-left
                  Positioned(
                    top: 26 * s,
                    left: 30 * s,
                    child: _Sparkle(
                        size: 15 * s, color: const Color(0xFF111111)),
                  ),
                  // Floating rings around the blob
                  Center(
                    child: _ScaledArt(s, 210, 210, const _BlobWithRings()),
                  ),
                  // Headline + pill pinned to the bottom
                  Positioned(
                    left: math.max(10, 18 * s),
                    right: math.max(10, 18 * s),
                    bottom: math.max(10, 18 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Easy ways to manage your finances',
                                style: TextStyle(
                                  fontSize: math.max(13, 19 * s),
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: FinavigColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            SizedBox(width: math.max(4, 6 * s)),
                            _Sparkle(
                                size: math.max(7, 10 * s),
                                color: const Color(0xFFD9B8FF)),
                          ],
                        ),
                        SizedBox(height: math.max(8, 12 * s)),
                        // Get Started pill inside the phone
                        Container(
                          height: math.max(24, 34 * s),
                          decoration: BoxDecoration(
                            color: FinavigColors.navyPrimary,
                            borderRadius:
                                BorderRadius.circular(math.max(7, 10 * s)),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Get Started  →',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders fixed-design-size art at [w]×[h] × [s] via a uniform FittedBox,
/// so poster elements shrink cleanly with the mockup instead of overflowing.
class _ScaledArt extends StatelessWidget {
  final double s;
  final double w;
  final double h;
  final Widget child;

  const _ScaledArt(this.s, this.w, this.h, this.child);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w * s,
      height: h * s,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: w, height: h, child: child),
      ),
    );
  }
}

/// Corner cluster of mint and pink shapes, like the reference poster.
class _CornerShapes extends StatelessWidget {
  const _CornerShapes();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 90,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 14,
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFF9AF2C6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  topRight: Radius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFF4D8F7),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                ),
              ),
            ),
          ),
          Positioned(
            top: 62,
            right: 84,
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wordmark blob with concentric guilloché-style rings.
class _BlobWithRings extends StatelessWidget {
  const _BlobWithRings();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(size: Size.square(200), painter: _RingsPainter()),
          Container(
            width: 108,
            height: 150,
            decoration: BoxDecoration(
              color: FinavigColors.navyPrimary,
              borderRadius: BorderRadius.circular(60),
              border: Border.all(
                color: FinavigColors.cyanAccent.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: FinavigColors.cyanAccent.withOpacity(0.20),
                  blurRadius: 34,
                  spreadRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, FinavigColors.cyanAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'FV',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws several thin offset ellipse outlines for the thread-like ring effect.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Rotate a family of ellipses around the center.
    final colors = [
      const Color(0xFF7C7CF4),
      const Color(0xFFF1A7F5),
      const Color(0xFF7CE8C5),
    ];
    for (var i = 0; i < 14; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 14);
      paint.color = colors[i % colors.length].withOpacity(0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.9,
          height: size.height * 0.62,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => false;
}

/// Four-point star / sparkle used in the poster art.
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SparklePainter(color: color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
