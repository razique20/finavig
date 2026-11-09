import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async' as async_dispatcher;

import '../services/app_version_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _page = 0;
  late AnimationController _pulseController;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<_OnboardingSlide> _buildSlides(BuildContext context) => [
        // ── Slide 1: Welcome / Brand ──────────────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0D1B2A), Color(0xFF1B2D45)],
          accentColor: FinavigColors.cyanAccent,
          icon: null, // uses logo
          useLogo: true,
          title: 'Welcome to Finavig',
          subtitle: 'Your smart companion for GCC life',
          body:
              'Track every expiry — visas, Emirates IDs, trade licences, insurance, contracts — and manage your finances. All in one secure app.',
          chips: ['🇦🇪 UAE', '🇸🇦 KSA', '🇶🇦 Qatar', '🇰🇼 Kuwait', '🇧🇭 Bahrain', '🇴🇲 Oman'],
        ),

        // ── Slide 2: Documents Tab ────────────────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0A1628), Color(0xFF152238)],
          accentColor: FinavigColors.violetAccent,
          icon: Icons.description_rounded,
          title: 'Never Miss an Expiry',
          subtitle: 'Documents Tab',
          body:
              'Scan or upload any document — visa, Ejari, labour card, vehicle registration. Our AI reads the expiry date automatically and organises everything by category.',
          previewItems: [
            _PreviewRow(Icons.badge_outlined, 'Emirates ID', '23 days left', FinavigColors.warning),
            _PreviewRow(Icons.apartment_rounded, 'Ejari Contract', '89 days left', FinavigColors.safe),
            _PreviewRow(Icons.flight_rounded, 'Visa', 'Expired 3 days ago', FinavigColors.danger),
          ],
        ),

        // ── Slide 3: Money Tab ────────────────────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0A1628), Color(0xFF1A2540)],
          accentColor: FinavigColors.emeraldAccent,
          icon: Icons.account_balance_wallet_rounded,
          title: 'Master Your Finances',
          subtitle: 'Money Tab',
          body:
              'Log income and expenses, set monthly budgets, view cash flow charts, and see exactly where your money goes — by category, by month.',
          previewItems: [
            _PreviewRow(Icons.trending_up_rounded, 'Income', 'AED 12,500', FinavigColors.safe),
            _PreviewRow(Icons.trending_down_rounded, 'Expenses', 'AED 8,340', FinavigColors.danger),
            _PreviewRow(Icons.savings_rounded, 'Net Savings', 'AED 4,160', FinavigColors.cyanAccent),
          ],
        ),

        // ── Slide 4: Home Dashboard ───────────────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0D1B2A), Color(0xFF162540)],
          accentColor: FinavigColors.cyanAccent,
          icon: Icons.home_rounded,
          title: 'Your FV Dashboard',
          subtitle: 'Home Tab',
          body:
              'See everything at a glance — urgent renewals, spending trends, streak tracking, and quick actions. Switch between personal and business collections instantly.',
          previewItems: [
            _PreviewRow(Icons.local_fire_department_rounded, '12-Day Streak', 'Keep it going!', FinavigColors.warning),
            _PreviewRow(Icons.warning_amber_rounded, '3 Renewals Due', 'This week', FinavigColors.danger),
            _PreviewRow(Icons.pie_chart_rounded, 'Budget Status', '67% used', FinavigColors.cyanAccent),
          ],
        ),

        // ── Slide 5: Notifications Permission ─────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0A1628), Color(0xFF1B2D45)],
          accentColor: FinavigColors.warning,
          icon: Icons.notifications_active_rounded,
          title: 'Stay Ahead of Deadlines',
          subtitle: 'Smart Reminders',
          body:
              'Finavig alerts you at 90, 60, 30, and 7 days before any document expires. Allow notifications so the reminders that save you from fines can reach you.',
          isNotificationStep: true,
          previewItems: [
            _PreviewRow(Icons.calendar_today_rounded, '90 days', 'Early reminder sent', FinavigColors.safe),
            _PreviewRow(Icons.event_rounded, '30 days', 'Renewal task created', FinavigColors.warning),
            _PreviewRow(Icons.alarm_rounded, '7 days', 'Urgent alert!', FinavigColors.danger),
          ],
        ),

        // ── Slide 6: Ready ────────────────────────────────────────────────
        _OnboardingSlide(
          gradient: const [Color(0xFF0D1B2A), Color(0xFF1A2E48)],
          accentColor: FinavigColors.safe,
          icon: Icons.rocket_launch_rounded,
          title: 'You\'re All Set',
          subtitle: 'Let\'s get started',
          body:
              'Upload your first document, log a transaction, or explore the dashboard. Finavig is ready when you are.',
          isFinal: true,
        ),
      ];

  void _nextPage() {
    final slides = _buildSlides(context);
    if (_page < slides.length - 1) {
      final slide = slides[_page];
      if (slide.isNotificationStep) {
        NotificationService.instance.requestPermission();
      }
      _entryController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _page++);
      _entryController.forward();
    }
  }

  void _finish() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('hasOnboarded', true);
      if (!mounted) return;
      async_dispatcher.unawaited(
        AppVersionService.instance.trackAppUsage(),
      );
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = _buildSlides(context);
    final slide = slides[_page];
    final progress = (_page + 1) / slides.length;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: slide.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative floating shapes ───────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -60 + (t * 20),
                    right: -40 + (t * 10),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            slide.accentColor.withValues(alpha: 0.08 + t * 0.04),
                            slide.accentColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100 + (t * 15),
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            slide.accentColor.withValues(alpha: 0.06 + t * 0.03),
                            slide.accentColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Page content ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar: progress + skip ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      // Step counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: slide.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_page + 1} of ${slides.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: slide.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Progress bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: 4,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(slide.accentColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Skip button (hidden on final slide)
                      if (!slide.isFinal)
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ── Slide content area ─────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) {
                      final s = slides[index];
                      return FadeTransition(
                        opacity: _entryController,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _entryController,
                            curve: Curves.easeOut,
                          )),
                          child: _SlideContent(slide: s, pulse: _pulseController),
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom navigation ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      // Dot indicators
                      Row(
                        children: List.generate(
                          slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _page
                                  ? slide.accentColor
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Action button
                      slide.isFinal
                          ? _GlowButton(
                              label: 'Get Started',
                              icon: Icons.arrow_forward_rounded,
                              color: slide.accentColor,
                              onTap: _finish,
                            )
                          : _GlowButton(
                              label: slide.isNotificationStep
                                  ? 'Allow & Continue'
                                  : 'Next',
                              icon: Icons.arrow_forward_rounded,
                              color: slide.accentColor,
                              onTap: _nextPage,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide Content Widget ───────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final _OnboardingSlide slide;
  final AnimationController pulse;

  const _SlideContent({required this.slide, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // ── Icon / Logo ──────────────────────────────────────────────
          if (slide.useLogo)
            _LogoBadge(color: slide.accentColor, pulse: pulse)
          else
            _IconBadge(icon: slide.icon!, color: slide.accentColor, pulse: pulse),

          const SizedBox(height: 28),

          // ── Subtitle pill ────────────────────────────────────────────
          if (slide.subtitle.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: slide.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: slide.accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                slide.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: slide.accentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          // ── Title ────────────────────────────────────────────────────
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),

          // ── Body ─────────────────────────────────────────────────────
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),

          // ── GCC Country chips ────────────────────────────────────────
          if (slide.chips.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: slide.chips
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],

          // ── Preview rows ─────────────────────────────────────────────
          if (slide.previewItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: slide.previewItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        Divider(
                          height: 20,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: item.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          Text(
                            item.value,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: item.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Final slide: feature grid ────────────────────────────────
          if (slide.isFinal) ...[
            const SizedBox(height: 8),
            _FeatureGrid(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Logo Badge ─────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final Color color;
  final AnimationController pulse;

  const _LogoBadge({required this.color, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15 + t * 0.1),
                blurRadius: 40 + t * 20,
                spreadRadius: t * 8,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F1A2E),
              border: Border.all(
                color: color.withValues(alpha: 0.3 + t * 0.15),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: ClipOval(
              child: Image.asset(
                'assets/New Logo/finavig-mark-transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Icon Badge ─────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController pulse;

  const _IconBadge({
    required this.icon,
    required this.color,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value;
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12 + t * 0.08),
                blurRadius: 30 + t * 15,
                spreadRadius: t * 5,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.25 + t * 0.1),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 44, color: color),
          ),
        );
      },
    );
  }
}

// ─── Glow Button ────────────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        label: Icon(icon, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF0A0E1A),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─── Feature Grid (final slide) ─────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(Icons.description_rounded, 'Documents', FinavigColors.violetAccent),
      _FeatureItem(Icons.account_balance_wallet_rounded, 'Money', FinavigColors.emeraldAccent),
      _FeatureItem(Icons.notifications_active_rounded, 'Alerts', FinavigColors.warning),
      _FeatureItem(Icons.local_fire_department_rounded, 'Streaks', FinavigColors.cyanAccent),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: f.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: f.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(f.icon, size: 26, color: f.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Data Models ────────────────────────────────────────────────────────────

class _OnboardingSlide {
  final List<Color> gradient;
  final Color accentColor;
  final IconData? icon;
  final bool useLogo;
  final String title;
  final String subtitle;
  final String body;
  final List<String> chips;
  final List<_PreviewRow> previewItems;
  final bool isNotificationStep;
  final bool isFinal;

  const _OnboardingSlide({
    required this.gradient,
    required this.accentColor,
    this.icon,
    this.useLogo = false,
    required this.title,
    this.subtitle = '',
    required this.body,
    this.chips = const [],
    this.previewItems = const [],
    this.isNotificationStep = false,
    this.isFinal = false,
  });
}

class _PreviewRow {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PreviewRow(this.icon, this.label, this.value, this.color);
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureItem(this.icon, this.label, this.color);
}
