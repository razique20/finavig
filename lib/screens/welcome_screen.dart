import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Same generated artwork as the splash backdrop — one visual identity from
/// the first frame to the welcome card.
const String _welcomeImageAsset = 'assets/images/splash_bg.jpg';

/// Pre-login welcome screen — the first thing a brand-new user sees after
/// the splash.
///
/// No logo mark: a single main headline up top, a short thread of
/// quotes styled like a WhatsApp conversation (an incoming quote, a
/// reply bubble with the quoted-reply block, and one more quote), and
/// a single "Continue to Login" CTA that marks onboarding-seen and
/// advances to the login page.
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

  Future<void> _continueToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinavigColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed brand artwork, cover-fitted like the splash.
          Image.asset(
            _welcomeImageAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Ink scrim: readable headline up top, strong contrast behind
          // the bottom CTA.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30F172A), // 70% ink
                  Color(0x660F172A), // 40% ink
                  Color(0xF20B1120), // 95% ink-deep
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    // Main headline — the wordmark itself, no logo mark.
                    const Text(
                      'Finavig',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'AI-powered financial & document intelligence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const Spacer(flex: 3),
                    // Quote thread — styled like a WhatsApp conversation.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _IncomingQuoteBubble(
                            quote:
                                'Do not save what is left after spending; '
                                'spend what is left after saving.',
                            attribution: 'Warren Buffett',
                          ),
                          SizedBox(height: 10),
                          _ReplyBubble(
                            replyToName: 'Warren Buffett',
                            quotedText:
                                '…spend what is left after saving.',
                            message:
                                "That's Finavig — budgets, cash flow and "
                                'document alerts in one secure place.',
                            timestamp: '9:39 PM',
                          ),
                          SizedBox(height: 10),
                          _IncomingQuoteBubble(
                            quote:
                                'An investment in knowledge pays the best '
                                'interest.',
                            attribution: 'Benjamin Franklin',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 6),
                    // CTA pinned to the bottom over the deep-scrim zone.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _continueToLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FinavigColors.accentBright,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Continue to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28, top: 4),
                      child: Text(
                        'Budgets · Cash flow · Document expiry alerts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An incoming chat bubble carrying a quote and its attribution
/// (WhatsApp-style, tail corner on the top-left).
class _IncomingQuoteBubble extends StatelessWidget {
  final String quote;
  final String attribution;

  const _IncomingQuoteBubble({
    required this.quote,
    required this.attribution,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: FinavigColors.slate.withOpacity(0.85),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '— $attribution',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FinavigColors.accentBright,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An outgoing reply bubble with the WhatsApp-style quoted-reply block
/// (accent bar, sender name, snippet) above the message itself.
class _ReplyBubble extends StatelessWidget {
  final String replyToName;
  final String quotedText;
  final String message;
  final String timestamp;

  const _ReplyBubble({
    required this.replyToName,
    required this.quotedText,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            decoration: BoxDecoration(
              color: FinavigColors.accentBright,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: FinavigColors.accentBright.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quoted-reply block.
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: Colors.white.withOpacity(0.75),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyToName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quotedText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
