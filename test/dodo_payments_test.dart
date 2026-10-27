import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/services/dodo_payments_service.dart';
import 'package:finavig/services/upgrade_request_service.dart';

void main() {
  group('DodoPaymentsService', () {
    test('singleton instance exists and is non-null', () {
      expect(DodoPaymentsService.instance, isNotNull);
    });

    test('throws StateError when unauthenticated', () async {
      // In local test runner, no Supabase session exists
      expect(
        () => DodoPaymentsService.instance.createCheckoutUrl(
          tier: SubscriptionTier.plus,
          duration: PlanDuration.oneMonth,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('defaultReturnUrl points to finavig payment success', () {
      expect(
        DodoPaymentsService.defaultReturnUrl,
        contains('payment-success'),
      );
    });
  });
}
