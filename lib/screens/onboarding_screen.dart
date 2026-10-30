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

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  List<_OnboardingPage> _buildPages(BuildContext context) => [
    _OnboardingPage(
      icon: Icons.upload_file_rounded,
      title: 'Upload your documents',
      body:
          'Drop a folder or zip of all your company documents. We\'ll sort them out — trade licences, Ejari, visas, insurance, contracts, domains, subscriptions.',
      color: FinavigColors.cyanAccent,
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_rounded,
      title: 'AI identifies every expiry',
      body:
          'No manual entry. Our layered AI reads each document, finds the expiry date, and tells you: what expires, when, and what happens if you miss it.',
      color: FinavigColors.violetAccent,
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'We remind you before it\'s too late',
      body:
          '90 days out → reminder. 60 days → task assigned. 30 days → escalation. 7 days → urgent alert. You set the cadence; we enforce it.',
      color: FinavigColors.warning,
    ),
    _OnboardingPage(
      icon: Icons.folder_special_rounded,
      title: 'One system for the whole company',
      body:
          'Trade licence, ejari, visas, Emirates IDs, labour documents, insurance, vehicles, contracts, domains, subscriptions, supplier agreements — in one place.',
      color: FinavigColors.emeraldAccent,
    ),
    // Pre-permission explainer: the OS notification prompt fires from
    // this page's action (via NotificationService.requestPermission),
    // so the ask is explained before it appears — never over the cold-
    // start launch screen.
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'Allow notifications — please',
      body:
          'Finavig alerts you 90, 60, 30 and 7 days before any document '
          'expires. Allow notifications on the next screen, or the '
          'reminders that save you the fines can\'t reach you.',
      color: FinavigColors.cyanAccent,
      action: () {
        // Fire the OS prompt at the moment it has been explained.
        NotificationService.instance.requestPermission();
        setState(() => _page++);
      },
    ),
    _OnboardingPage(
      icon: Icons.check_circle_rounded,
      title: 'You\'re ready',
      body:
          'Nothing to install. Nothing to sync. Just upload and we\'ll take it from there. Welcome to Finavig.',
      color: FinavigColors.safe,
      actionLabel: 'Get started',
      action: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('hasOnboarded', true);
          if (context.mounted) {
            // Canonical post-onboarding reporting site for app-health.
            async_dispatcher.unawaited(
              AppVersionService.instance.trackAppUsage(),
            );
            context.go('/home');
          }
        });
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _buildPages(context);
    final page = pages[_page];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FinavigGradients.darkHeader
              : const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: 340,
                      child: FinavigGlass(
                        borderRadius: BorderRadius.circular(24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 36,
                        ),
                        child: Stack(
                          children: [
                            // Decorative background icons (random app-related)
                            Positioned(
                              top: 10,
                              right: 14,
                              child: Transform.rotate(
                                angle: 0.15,
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 36,
                                  color: page.color.withValues(alpha: isDark ? 0.08 : 0.12),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 44,
                              right: 60,
                              child: Transform.rotate(
                                angle: -0.1,
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 28,
                                  color: page.color.withValues(alpha: isDark ? 0.06 : 0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 22,
                              right: 10,
                              child: Transform.rotate(
                                angle: 0.2,
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 32,
                                  color: page.color.withValues(alpha: isDark ? 0.07 : 0.11),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 42,
                              child: Transform.rotate(
                                angle: -0.15,
                                child: Icon(
                                  Icons.attach_money_outlined,
                                  size: 24,
                                  color: page.color.withValues(alpha: isDark ? 0.05 : 0.09),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 64,
                              left: 10,
                              child: Transform.rotate(
                                angle: 0.12,
                                child: Icon(
                                  Icons.folder_outlined,
                                  size: 26,
                                  color: page.color.withValues(alpha: isDark ? 0.06 : 0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 18,
                              left: 56,
                              child: Transform.rotate(
                                angle: -0.08,
                                child: Icon(
                                  Icons.insert_chart_outlined,
                                  size: 22,
                                  color: page.color.withValues(alpha: isDark ? 0.05 : 0.08),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 340,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    child: KeyedSubtree(
                                      key: ValueKey(_page),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 110,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              color: page.color.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: page.color.withValues(alpha: 0.3),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: page.color.withValues(alpha: 0.2),
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              page.icon,
                                              size: 52,
                                              color: page.color,
                                            ),
                                          ),
                                          const SizedBox(height: 28),
                                          Text(
                                            page.title,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? FinavigColors.textPrimaryDark
                                                  : FinavigColors.textPrimaryLight,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            page.body,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.55,
                                              color: isDark
                                                  ? FinavigColors.textSecondary
                                                  : FinavigColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom navigation row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots
                    Row(
                      children: List.generate(
                        pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page
                                ? FinavigColors.cyanAccent
                                : (isDark
                                      ? FinavigColors.textMuted.withValues(alpha: 0.3)
                                      : Colors.black12),
                          ),
                        ),
                      ),
                    ),
                    // Action button / next button
                    if (_page < pages.length - 1)
                      TextButton(
                        onPressed: () {
                          // The notification page is the only step with a
                          // side effect — it fires the OS permission prompt
                          // that the page just explained. Every other step
                          // simply advances.
                          if (page.action != null) {
                            page.action!();
                          } else {
                            setState(() => _page++);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: FinavigColors.cyanAccent,
                        ),
                        child: Text(
                          // This is the flow's only forward control, so it
                          // is a "Next" — the old "Skip" label promised a
                          // jump it never performed. Kept short ("Continue"
                          // rather than "Allow notifications") so the row
                          // never overflows on 320dp phones.
                          _page == pages.length - 2 ? 'Continue' : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      // The final CTA (icon + "Get started") is the widest
                      // control in the flow — scale it down instead of
                      // overflowing the row on 320dp phones.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: page.action,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: const Text('Get started'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FinavigColors.cyanAccent,
                              foregroundColor: const Color(0xFF0A0E1A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final VoidCallback? action;
  final String? actionLabel;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.action,
    this.actionLabel,
  });
}
