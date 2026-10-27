import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_tier.dart';
import 'auth_service.dart';
import 'entitlement_service.dart';
import 'supabase_service.dart';
import 'upgrade_request_service.dart';

/// Handles Dodo Payments hosted checkout session creation and tier sync.
class DodoPaymentsService {
  DodoPaymentsService._();

  static final DodoPaymentsService instance = DodoPaymentsService._();

  static const String _checkoutFunction = 'create-dodo-checkout';

  /// Default landing page after completing checkout on web.
  static const String defaultReturnUrl = 'https://finavig.ae/payment-success';

  /// Request a Dodo Payments checkout session URL from the backend Edge Function.
  ///
  /// Returns the hosted `checkout_url` string, or throws an exception on failure.
  Future<String> createCheckoutUrl({
    required SubscriptionTier tier,
    PlanDuration duration = PlanDuration.oneMonth,
    String returnUrl = defaultReturnUrl,
  }) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Please sign in to upgrade your subscription.',
      );
    }

    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      throw StateError(
        'You must be signed in to purchase a subscription plan.',
      );
    }

    try {
      final response = await client.functions
          .invoke(
            _checkoutFunction,
            body: {
              'tier': tier.id,
              'duration': duration.id,
              'return_url': returnUrl,
            },
          )
          .timeout(const Duration(seconds: 25));

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['message'] ?? response.data['error'] ?? 'Checkout failed')
            : 'Server returned error ${response.status}';
        throw StateError(errorMsg.toString());
      }

      final data = response.data;
      if (data is Map && data['checkout_url'] != null) {
        return data['checkout_url'] as String;
      }

      throw StateError('Invalid response from checkout service: missing checkout_url');
    } catch (e) {
      debugPrint('[DodoPaymentsService] createCheckoutUrl failed: $e');
      rethrow;
    }
  }

  /// Launch the checkout URL in an external browser or in-app custom tab.
  Future<bool> launchCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// High-level flow: creates checkout session, launches browser, and provides
  /// callback hook when user returns.
  Future<bool> startCheckout({
    required SubscriptionTier tier,
    PlanDuration duration = PlanDuration.oneMonth,
  }) async {
    final checkoutUrl = await createCheckoutUrl(
      tier: tier,
      duration: duration,
    );
    return await launchCheckoutUrl(checkoutUrl);
  }

  /// Check if active tier has changed after user completed payment.
  Future<bool> verifyAndRefreshTier() async {
    final initialTier = EntitlementService.instance.tier;
    await EntitlementService.instance.refresh();
    return EntitlementService.instance.tier > initialTier;
  }
}
