import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/services/rating_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RatingPromptPolicy', () {
    test('never asks before the minimum renewal count', () {
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: RatingPromptPolicy.minRenewalsBeforeAsk - 1,
          lastAskedAt: null,
          askCount: 0,
        ),
        isFalse,
      );
    });

    test('asks at the first eligible success moment', () {
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: RatingPromptPolicy.minRenewalsBeforeAsk,
          lastAskedAt: null,
          askCount: 0,
        ),
        isTrue,
      );
    });

    test('respects the cooldown after a previous ask', () {
      final recent = DateTime.now()
          .subtract(const Duration(days: RatingPromptPolicy.cooldownDays - 1))
          .millisecondsSinceEpoch;
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: 5,
          lastAskedAt: recent,
          askCount: 1,
        ),
        isFalse,
      );
    });

    test('asks again once the cooldown has elapsed', () {
      final old = DateTime.now()
          .subtract(const Duration(days: RatingPromptPolicy.cooldownDays + 1))
          .millisecondsSinceEpoch;
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: 5,
          lastAskedAt: old,
          askCount: 1,
        ),
        isTrue,
      );
    });

    test('never asks beyond the per-install cap', () {
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: 50,
          lastAskedAt: null,
          askCount: RatingPromptPolicy.maxAsksPerInstall,
        ),
        isFalse,
      );
    });

    test('never asks when the platform sheet is unavailable', () {
      expect(
        RatingPromptPolicy.shouldAsk(
          renewalCount: 10,
          lastAskedAt: null,
          askCount: 0,
          canPrompt: false,
        ),
        isFalse,
      );
    });
  });

  group('RatingPromptService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does not ask and does not count an ask below the threshold',
        () async {
      final service = RatingPromptService.instance;
      service.canPromptOverride = () async => true;
      service.showPrompt = () async {};

      // One renewal — below minRenewalsBeforeAsk.
      await service.recordRenewal();
      final asked = await service.maybeAsk();

      expect(asked, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('finavig.rating.askCount'), isNull);
    });

    test('asks at the eligible moment and records the ask', () async {
      var promptShown = 0;
      final service = RatingPromptService.instance;
      service.canPromptOverride = () async => true;
      service.showPrompt = () async => promptShown++;

      await service.recordRenewal();
      await service.recordRenewal();
      final asked = await service.maybeAsk();

      expect(asked, isTrue);
      expect(promptShown, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('finavig.rating.askCount'), 1);
      expect(prefs.getInt('finavig.rating.lastAskedAt'), isNotNull);
    });

    test('never asks when the platform probe reports unavailable', () async {
      var promptShown = 0;
      final service = RatingPromptService.instance;
      service.canPromptOverride = () async => false;
      service.showPrompt = () async => promptShown++;

      await service.recordRenewal();
      await service.recordRenewal();
      final asked = await service.maybeAsk();

      expect(asked, isFalse);
      expect(promptShown, 0);
    });
  });
}
