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
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _page = 0;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<_OnboardingSlide> _buildSlides() => [
        // ── 1. Welcome ────────────────────────────────────────────────────
        _OnboardingSlide(
          useLogo: true,
          accentColor: FinavigColors.accent,
          title: 'Welcome to Finavig',
          subtitle: 'Your GCC companion',
          body:
              'Track every expiry — visas, Emirates IDs, trade licences, insurance, contracts — and manage your finances, all in one secure app.',
          chips: [
            '🇦🇪 UAE',
            '🇸🇦 KSA',
            '🇶🇦 Qatar',
            '🇰🇼 Kuwait',
            '🇧🇭 Bahrain',
            '🇴🇲 Oman',
          ],
        ),

        // ── 2. Documents ──────────────────────────────────────────────────
        _OnboardingSlide(
          icon: Icons.description_rounded,
          accentColor: FinavigColors.accent,
          title: 'Never Miss an Expiry',
          subtitle: 'Documents',
          body:
              'Scan or upload any document — visa, Ejari, labour card, vehicle registration. Our AI reads the expiry date and organises everything automatically.',
          previewItems: [
            _PreviewRow(
              Icons.badge_outlined,
              'Emirates ID',
              '23 days left',
              FinavigColors.warning,
            ),
            _PreviewRow(
              Icons.apartment_rounded,
              'Ejari Contract',
              '89 days left',
              FinavigColors.safe,
            ),
            _PreviewRow(
              Icons.flight_rounded,
              'Visa',
              'Expired 3 days ago',
              FinavigColors.danger,
            ),
          ],
        ),

        // ── 3. Money ──────────────────────────────────────────────────────
        _OnboardingSlide(
          icon: Icons.account_balance_wallet_rounded,
          accentColor: FinavigColors.safe,
          title: 'Master Your Finances',
          subtitle: 'Money',
          body:
              'Log income and expenses, set monthly budgets, view cash flow charts, and see exactly where your money goes.',
          previewItems: [
            _PreviewRow(
              Icons.trending_up_rounded,
              'Income',
              'AED 12,500',
              FinavigColors.safe,
            ),
            _PreviewRow(
              Icons.trending_down_rounded,
              'Expenses',
              'AED 8,340',
              FinavigColors.danger,
            ),
            _PreviewRow(
              Icons.savings_rounded,
              'Net Savings',
              'AED 4,160',
              FinavigColors.accent,
            ),
          ],
        ),

        // ── 4. Dashboard ──────────────────────────────────────────────────
        _OnboardingSlide(
          icon: Icons.home_rounded,
          accentColor: FinavigColors.accent,
          title: 'Your FV Dashboard',
          subtitle: 'Home',
          body:
              'See everything at a glance — urgent renewals, spending trends, streak tracking, and quick actions. Switch collections instantly.',
          previewItems: [
            _PreviewRow(
              Icons.local_fire_department_rounded,
              '12-Day Streak',
              'Keep going!',
              FinavigColors.warning,
            ),
            _PreviewRow(
              Icons.warning_amber_rounded,
              '3 Renewals Due',
              'This week',
              FinavigColors.danger,
            ),
            _PreviewRow(
              Icons.pie_chart_rounded,
              'Budget Status',
              '67% used',
              FinavigColors.accent,
            ),
          ],
        ),

        // ── 5. Notifications ──────────────────────────────────────────────
        _OnboardingSlide(
          icon: Icons.notifications_active_rounded,
          accentColor: FinavigColors.warning,
          title: 'Stay Ahead of Deadlines',
          subtitle: 'Smart Reminders',
          body:
              'Finavig alerts you at 90, 60, 30, and 7 days before any document expires. Allow notifications so the reminders can reach you.',
          isNotificationStep: true,
          previewItems: [
            _PreviewRow(
              Icons.calendar_today_rounded,
              '90 days',
              'Early reminder',
              FinavigColors.safe,
            ),
            _PreviewRow(
              Icons.event_rounded,
              '30 days',
              'Task created',
              FinavigColors.warning,
            ),
            _PreviewRow(
              Icons.alarm_rounded,
              '7 days',
              'Urgent alert!',
              FinavigColors.danger,
            ),
          ],
        ),

        // ── 6. Ready ──────────────────────────────────────────────────────
        _OnboardingSlide(
          icon: Icons.rocket_launch_rounded,
          accentColor: FinavigColors.safe,
          title: 'You\'re All Set',
          subtitle: 'Let\'s go',
          body:
              'Upload your first document, log a transaction, or explore the dashboard. Finavig is ready when you are.',
          isFinal: true,
        ),
      ];

  void _nextPage() {
    final slides = _buildSlides();
    if (_page < slides.length - 1) {
      final slide = slides[_page];
      if (slide.isNotificationStep) {
        NotificationService.instance.requestPermission();
      }
      _entryController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fade = FinavigTransition.of(context);
    final slides = _buildSlides();
    final slide = slides[_page];
    final progress = (_page + 1) / slides.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FinavigGradients.surfaceDark
              : FinavigGradients.surfaceLight,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar: progress + skip ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    // Step counter pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: slide.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: slide.accentColor.withValues(alpha: 0.15),
                        ),
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
                            backgroundColor: fade.color(
                              FinavigColors.fog,
                              Colors.white.withValues(alpha: 0.08),
                            ),
                            valueColor:
                                AlwaysStoppedAnimation(slide.accentColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Skip (hidden on final)
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
                            color: fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),

              // ── Slide content ────────────────────────────────────────
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
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _entryController,
                          curve: Curves.easeOut,
                        )),
                        child: _SlideContent(slide: s),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom: dots + action button ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    // Dots
                    Row(
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page
                                ? slide.accentColor
                                : fade.color(
                                    FinavigColors.fog,
                                    Colors.white.withValues(alpha: 0.12),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Next / Get Started button
                    ElevatedButton.icon(
                      onPressed:
                          slide.isFinal ? _finish : _nextPage,
                      icon: Text(
                        slide.isFinal
                            ? 'Get Started'
                            : slide.isNotificationStep
                                ? 'Allow & Continue'
                                : 'Next',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      label: const Icon(Icons.arrow_forward_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slide.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Slide Content ──────────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fade = FinavigTransition.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 28),

          // ── Icon / Logo ────────────────────────────────────────────
          if (slide.useLogo)
            _LogoBadge(color: slide.accentColor)
          else
            _IconBadge(icon: slide.icon!, color: slide.accentColor),

          const SizedBox(height: 24),

          // ── Subtitle pill ──────────────────────────────────────────
          if (slide.subtitle.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: slide.accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: slide.accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                slide.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: slide.accentColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),

          // ── Title ──────────────────────────────────────────────────
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: fade.color(
                FinavigColors.textPrimaryLight,
                FinavigColors.textPrimary,
              ),
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // ── Body ───────────────────────────────────────────────────
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: fade.color(
                FinavigColors.textSecondaryLight,
                FinavigColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── GCC chips ──────────────────────────────────────────────
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
                          color: fade.color(
                            FinavigColors.mist,
                            FinavigColors.slate,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: fade.color(
                              FinavigColors.fog,
                              FinavigColors.slateLight,
                            ),
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: fade.color(
                              FinavigColors.textPrimaryLight,
                              FinavigColors.textPrimary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],

          // ── Preview rows ───────────────────────────────────────────
          if (slide.previewItems.isNotEmpty) ...[
            FinavigGlass(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(14),
              child: Column(
                children:
                    slide.previewItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        Divider(
                          height: 18,
                          color: fade.color(
                            FinavigColors.fog,
                            Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.color.withValues(
                                alpha: isDark ? 0.12 : 0.08,
                              ),
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
                                color: fade.color(
                                  FinavigColors.textPrimaryLight,
                                  FinavigColors.textPrimary,
                                ),
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

          // ── Final: feature grid ────────────────────────────────────
          if (slide.isFinal) ...[
            const SizedBox(height: 8),
            _FeatureGrid(),
          ],

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ─── Logo Badge ─────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final Color color;

  const _LogoBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fade.color(Colors.white, FinavigColors.slate),
        border: Border.all(
          color: fade.color(FinavigColors.fog, FinavigColors.slateLight),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: ClipOval(
        child: Image.asset(
          'assets/New Logo/finavig-mark-transparent.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ─── Icon Badge ─────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isDark ? 0.1 : 0.08),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }
}

// ─── Feature Grid (final slide) ─────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fade = FinavigTransition.of(context);

    final features = [
      _FeatureItem(Icons.description_rounded, 'Documents', FinavigColors.accent),
      _FeatureItem(Icons.account_balance_wallet_rounded, 'Money', FinavigColors.safe),
      _FeatureItem(Icons.notifications_active_rounded, 'Alerts', FinavigColors.warning),
      _FeatureItem(Icons.local_fire_department_rounded, 'Streaks', FinavigColors.accent),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: f.color.withValues(alpha: isDark ? 0.1 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: f.color.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(f.icon, size: 24, color: f.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fade.color(
                          FinavigColors.textSecondaryLight,
                          FinavigColors.textSecondary,
                        ),
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
  final IconData? icon;
  final bool useLogo;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String body;
  final List<String> chips;
  final List<_PreviewRow> previewItems;
  final bool isNotificationStep;
  final bool isFinal;

  const _OnboardingSlide({
    this.icon,
    this.useLogo = false,
    required this.accentColor,
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
