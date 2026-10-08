import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/credit.dart';
import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/services/ai_executive_summary_service.dart';
import 'package:finavig/services/credit_service.dart';
import 'package:finavig/services/entitlement_service.dart';
import 'package:finavig/services/groq_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CreditService.instance.clearCache();
    await EntitlementService.instance.refresh();
    await AiExecutiveSummaryService.instance.resetUsageCounter();
  });

  group('GroqApiService', () {
    test('ships with no client-side key (calls go through the server proxy)',
        () async {
      final service = GroqApiService.instance;
      await service.clearCustomApiKey();
      expect(service.apiKey, isEmpty);
      // Supabase isn't initialised in unit tests, so the proxy isn't
      // reachable and no call can be made yet.
      expect(service.isConfigured, isFalse);
    });

    test('supports setting and clearing custom API key override', () async {
      final service = GroqApiService.instance;
      const customKey = 'gsk_custom_test_key_123456789';

      await service.setCustomApiKey(customKey);
      expect(service.apiKey, equals(customKey));
      expect(service.isConfigured, isTrue);

      await service.clearCustomApiKey();
      expect(service.apiKey, isEmpty);
    });
  });

  group('Tier Quotas for Groq AI Summary', () {
    test('Free tier allows exactly 3 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'free'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.free);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 3);

      expect(await service.canGenerateAiSummary(), isTrue);
      expect(await service.getRemainingQuotaThisMonth(), 3);
    });

    test('Plus tier allows exactly 15 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'plus'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.plus);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 15);
    });

    test('Business tier allows exactly 40 monthly summaries', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'business'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.business);
      final service = AiExecutiveSummaryService.instance;
      expect(service.getMonthlyQuotaLimit(), 40);
    });
  });

  group('Credit obligations in the AI summary', () {
    CreditEntry credit({
      double amount = 2500,
      CreditDirection direction = CreditDirection.borrowed,
      DateTime? deadline,
    }) =>
        CreditEntry(
          id: 'credit-ai-${amount.toInt()}',
          collectionId: 'personal',
          direction: direction,
          counterpartyName: 'Ahmed',
          amount: amount,
          currency: 'AED',
          startDate: DateTime(2026, 9, 1),
          deadline: deadline ?? DateTime(2026, 9, 15),
          createdAt: DateTime(2026, 9, 1),
        );

    test('feeds outstanding credit into the Groq prompt and insights',
        () async {
      await CreditService.instance.init();
      await CreditService.instance.addCredit(credit());

      final service = AiExecutiveSummaryService.instance;
      String? capturedUser;
      service.groqCallOverride = (system, user) async {
        capturedUser = user;
        return 'Executive summary incl. credit.';
      };

      final now = DateTime(2026, 9, 21);
      final result = await service.generateSummary(
        forceRegenerate: true,
        now: now,
      );

      expect(capturedUser, isNotNull);
      expect(capturedUser, contains('CREDIT OBLIGATIONS'));
      expect(capturedUser, contains('Ahmed'));
      expect(capturedUser, contains('2,500'));
      // Overdue borrowed obligation should surface as an alert insight plus
      // an overall credit-position insight.
      final labels = result.insights.map((i) => i.categoryLabel).toList();
      expect(labels, contains('Credit Position'));
      expect(labels, contains('Credit Due'));
    });

    test('offline fallback narrative mentions credit obligations', () async {
      await CreditService.instance.init();
      await CreditService.instance.addCredit(credit(amount: 800));

      final service = AiExecutiveSummaryService.instance;
      service.groqCallOverride = (system, user) async => 'ok';

      // Consume the free-tier quota (3), then the 4th call uses the
      // deterministic fallback narrative.
      final now = DateTime(2026, 9, 21);
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);
      final overflow = await service.generateSummary(
        forceRegenerate: true,
        now: now,
      );

      expect(overflow.quotaExceeded, isTrue);
      expect(overflow.narrative, contains('On credit'));
      expect(overflow.narrative, contains('800'));
    });
  });

  group('AiExecutiveSummaryService Generation & Fallback', () {
    test('generates summary using Groq override and increments monthly counter', () async {
      final service = AiExecutiveSummaryService.instance;
      service.groqCallOverride = (system, user) async =>
          'Executive AI Summary: 2 documents require renewal. Monthly spending is AED 5,400.';

      final now = DateTime(2026, 9, 21);
      final result = await service.generateSummary(forceRegenerate: true, now: now);

      expect(result.usedGroq, isTrue);
      expect(result.quotaExceeded, isFalse);
      expect(result.narrative, contains('Executive AI Summary'));
      expect(await service.getUsedQuotaThisMonth(now), 1);
      expect(await service.getRemainingQuotaThisMonth(now), 2);
    });

    test('enforces quota limit when limit is reached', () async {
      final service = AiExecutiveSummaryService.instance;
      service.groqCallOverride = (system, user) async => 'AI Summary Text';

      final now = DateTime(2026, 9, 21);
      // Generate 3 times (Free tier limit)
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);
      await service.generateSummary(forceRegenerate: true, now: now);

      expect(await service.getUsedQuotaThisMonth(now), 3);
      expect(await service.canGenerateAiSummary(now), isFalse);

      // 4th generation should trigger quotaExceeded and return fallback narrative without crashing
      final overflowResult = await service.generateSummary(forceRegenerate: true, now: now);
      expect(overflowResult.quotaExceeded, isTrue);
      expect(overflowResult.usedGroq, isFalse);
    });
  });
}
