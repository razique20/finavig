import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/services/upgrade_request_service.dart';

void main() {
  group('TierInfo pricing', () {
    test('anchor monthly prices match the agreed numbers', () {
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.oneMonth),
        contains('AED 25 / month'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.business, PlanDuration.oneMonth),
        contains('AED 99 / month'),
      );
    });

    test('3-month and 1-year bundles are priced and discounted', () {
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.threeMonths),
        contains('AED 69 / 3 months'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.threeMonths),
        contains('save 8%'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.oneYear),
        contains('AED 240 / year'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.oneYear),
        contains('save 20%'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.business, PlanDuration.oneYear),
        contains('AED 999 / year'),
      );
      expect(
        TierInfo.priceFor(SubscriptionTier.business, PlanDuration.oneYear),
        contains('save 16%'),
      );
    });

    test('monthly price never shows a saving suffix', () {
      expect(
        TierInfo.priceFor(SubscriptionTier.plus, PlanDuration.oneMonth),
        isNot(contains('save')),
      );
    });

    test('every tier/duration pair has AED and USD entries', () {
      for (final tier in [SubscriptionTier.plus, SubscriptionTier.business]) {
        for (final d in PlanDuration.values) {
          expect(TierInfo.priceAed[tier]![d], isNotNull);
          expect(TierInfo.priceUsdHint[tier]![d], isNotNull);
        }
      }
    });
  });
}
