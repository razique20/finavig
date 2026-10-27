import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/subscription_tier.dart';
import '../services/dodo_payments_service.dart';
import '../services/entitlement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';

/// Screen displayed after a successful online checkout via Dodo Payments.
///
/// Triggered via the `finavig://payment-success` deep link callback or in-app browser redirect.
/// Automatically verifies the transaction and syncs entitlements.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isVerifying = true;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    setState(() => _isVerifying = true);
    try {
      final upgraded =
          await DodoPaymentsService.instance.verifyAndRefreshTier();
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verified = upgraded ||
            EntitlementService.instance.tier != SubscriptionTier.free;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verified = EntitlementService.instance.tier != SubscriptionTier.free;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tier = EntitlementService.instance.tier;
    final info = TierInfo.all[tier] ?? TierInfo.all[SubscriptionTier.plus]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Celebration Icon Ring
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FinavigColors.navyPrimary,
                        FinavigColors.accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FinavigColors.accent.withAlpha(isDark ? 80 : 120),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isVerifying
                        ? const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 54,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  _isVerifying ? 'Confirming Your Payment...' : 'Payment Successful!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  _isVerifying
                      ? 'Syncing your subscription with Finavig...'
                      : 'Welcome to Finavig ${info.name}. Your account features have been unlocked immediately.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Benefits Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withAlpha(80)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outlineVariant.withAlpha(60)
                          : FinavigColors.accent.withAlpha(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TierBadge(tier: tier == SubscriptionTier.free ? SubscriptionTier.plus : tier),
                          const SizedBox(width: 10),
                          Text(
                            'Active Plan',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      ...info.benefits.take(4).map(
                            (benefit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: FinavigColors.safe.withAlpha(40),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: FinavigColors.safe,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      benefit,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Primary CTA
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Start Exploring'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FinavigColors.navyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary CTA
                TextButton(
                  onPressed: () => context.go('/profile'),
                  child: Text(
                    'View My Subscription',
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
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
