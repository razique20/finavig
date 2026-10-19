import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Pre-login welcome screen — the first thing a brand-new user sees after
/// the splash.
///
/// A modern feature walkthrough carousel showcasing Finavig's three core
/// pillars, with smooth page transitions, animated dot indicators, and a
/// "Get Started" CTA that marks onboarding as seen and advances to login.
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
  late final PageController _pageController;
  int _currentPage = 0;

  static const _pillars = <_FeaturePillar>[
    _FeaturePillar(
      icon: Icons.radar_rounded,
      accentColor: FinavigColors.danger,
      tintColor: FinavigColors.redTint,
      title: 'Smart Document\nExpiry Radar',
      subtitle:
          'Track passports, visas, trade licenses and IDs in one place — '
          'with escalating alerts so you never miss a renewal deadline.',
    ),
    _FeaturePillar(
      icon: Icons.account_balance_wallet_rounded,
      accentColor: FinavigColors.logoGreen,
      tintColor: FinavigColors.greenTint,
      title: 'Cash Flow\n& Envelopes',
      subtitle:
          'Automated budget pacing, envelope allocation and 90-day '
          'recurring expense predictions — your money on autopilot.',
    ),
    _FeaturePillar(
      icon: Icons.auto_awesome_rounded,
      accentColor: FinavigColors.lilac,
      tintColor: FinavigColors.lilacTint,
      title: 'AI Compliance\n& Insights',
      subtitle:
          'Point your camera at any document — OCR extracts the data '
          'instantly and AI generates compliance summaries for you.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          fade.color(FinavigColors.snowWhite, FinavigColors.obsidian),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              children: [
                const SizedBox(height: 28),

                // ── Logo ──────────────────────────────────────────────
                Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),

                Text(
                  'AI-powered financial & document intelligence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: fade.color(
                      FinavigColors.textSecondaryLight,
                      FinavigColors.textSecondary,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Feature carousel ──────────────────────────────────
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pillars.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _PillarCard(
                        pillar: _pillars[index],
                        isDark: isDark,
                        fade: fade,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ── Page indicator dots ───────────────────────────────
                _PageIndicator(
                  count: _pillars.length,
                  current: _currentPage,
                  activeColor: _pillars[_currentPage].accentColor,
                  inactiveColor: fade.color(FinavigColors.fog, FinavigColors.slateLight),
                ),

                const Spacer(flex: 4),

                // ── CTA ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _continueToLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            fade.color(FinavigColors.ink, FinavigColors.accentBright),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(FinavigRadius.button),
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

                Padding(
                  padding: const EdgeInsets.only(bottom: 28, top: 4),
                  child: Text(
                    'Budgets · Cash flow · Document expiry alerts',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single carousel pillar.
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturePillar {
  final IconData icon;
  final Color accentColor;
  final Color tintColor;
  final String title;
  final String subtitle;

  const _FeaturePillar({
    required this.icon,
    required this.accentColor,
    required this.tintColor,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual pillar card rendered inside the PageView.
// ─────────────────────────────────────────────────────────────────────────────

class _PillarCard extends StatelessWidget {
  final _FeaturePillar pillar;
  final bool isDark;
  final FinavigTransition fade;

  const _PillarCard({
    required this.pillar,
    required this.isDark,
    required this.fade,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark
        ? pillar.accentColor.withValues(alpha: 0.15)
        : pillar.tintColor;
    final cardBg = fade.color(Colors.white, FinavigColors.charcoal);
    final borderColor =
        fade.color(FinavigColors.fog, FinavigColors.slateLight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(FinavigRadius.card),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: FinavigShadows.adaptive(isDark),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                pillar.icon,
                size: 36,
                color: pillar.accentColor,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              pillar.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
                color: fade.color(
                  FinavigColors.textPrimaryLight,
                  FinavigColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              pillar.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated page-indicator dots. The active dot expands into a pill.
// ─────────────────────────────────────────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;
  final Color inactiveColor;

  const _PageIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
