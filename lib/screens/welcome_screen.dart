import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Pre-login welcome screen — the first thing a brand-new user sees after
/// the splash.
///
/// A clean brand screen: transparent logo, a short description, and a few
/// lines about what the app does, with a "Get Started" CTA that marks
/// onboarding as seen and advances to login.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _continueToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);

    return Scaffold(
      backgroundColor: fade.color(
        FinavigColors.snowWhite,
        FinavigColors.obsidian,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Logo ──────────────────────────────────────────────
                    Image.asset(
                      'assets/New Logo/finavig-mark-transparent.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 22),

                    // ── Tagline ───────────────────────────────────────────
                    Text(
                      'AI-powered financial & document intelligence',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: fade.color(
                          FinavigColors.textSecondaryLight,
                          FinavigColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── What this app does ───────────────────────────────
                    Text(
                      'Stay on top of the documents that matter — trade licences, '
                      'visas, IDs and renewals — with smart expiry alerts, cash-flow '
                      'budgets and AI-powered insights that keep you compliant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: fade.color(
                          FinavigColors.textPrimaryLight,
                          FinavigColors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── App highlights ────────────────────────────────────
                    _NoteRow(
                      label: 'Document expiry radar',
                      detail:
                          'Track passports, visas, trade licences, IDs and more '
                          '— with escalating alerts so nothing slips through.',
                      fade: fade,
                    ),
                    const SizedBox(height: 14),
                    _NoteRow(
                      label: 'Cash flow & budgets',
                      detail:
                          'Automated budget pacing, envelope allocation and '
                          '90-day expense predictions — your money on autopilot.',
                      fade: fade,
                    ),
                    const SizedBox(height: 14),
                    _NoteRow(
                      label: 'AI compliance insights',
                      detail:
                          'Point your camera at any document — OCR extracts the '
                          'data instantly and AI generates compliance summaries.',
                      fade: fade,
                    ),

                    const Spacer(flex: 3),

                    // ── CTA ───────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _continueToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: fade.color(
                            FinavigColors.ink,
                            FinavigColors.accentBright,
                          ),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              FinavigRadius.button,
                            ),
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

                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 12),
                      child: Text(
                        'Budgets · Cash flow · Document expiry alerts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: fade.color(
                            FinavigColors.accent,
                            FinavigColors.accentBright,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single app-highlight note row.
// ─────────────────────────────────────────────────────────────────────────────

class _NoteRow extends StatelessWidget {
  final String label;
  final String detail;
  final FinavigTransition fade;

  const _NoteRow({
    required this.label,
    required this.detail,
    required this.fade,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: fade.color(FinavigColors.accent, FinavigColors.accentBright),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
