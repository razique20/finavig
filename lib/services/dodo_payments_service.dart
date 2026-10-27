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

  /// Default deep link callback after completing checkout.
  /// Routes directly back into the Finavig mobile app.
  static const String defaultReturnUrl = 'finavig://payment-success';

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

  /// Launch the checkout URL in an in-app browser view (Safari / Chrome Custom Tab)
  /// so the user never leaves the app, with fallback to external browser.
  Future<bool> launchCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    try {
      final inAppSuccess = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (inAppSuccess) return true;
    } catch (_) {}

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

  static const String _verifyFunction = 'verify-dodo-payment';

  /// Check if active tier has changed after user completed payment.
  /// Calls the backend verification endpoint to sync directly with Dodo Payments API
  /// before refreshing local entitlements.
  Future<bool> verifyAndRefreshTier() async {
    final initialTier = EntitlementService.instance.tier;

    final client = SupabaseService.clientOrNull;
    if (client != null && AuthService.instance.isSignedIn) {
      try {
        final response = await client.functions
            .invoke(_verifyFunction)
            .timeout(const Duration(seconds: 15));
        if (response.status == 200 && response.data is Map) {
          final data = response.data as Map;
          if (data['upgraded'] == true) {
            debugPrint('[DodoPaymentsService] Plan verified and activated: ${data['tier']}');
          }
        }
      } catch (e) {
        debugPrint('[DodoPaymentsService] verify-dodo-payment check failed: $e');
      }
    }

    await EntitlementService.instance.refresh();
    return EntitlementService.instance.tier > initialTier;
  }
}
