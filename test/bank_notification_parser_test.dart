import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/document_collection.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/bank_notification_parser.dart';
import 'package:finavig/services/collection_service.dart';
import 'package:finavig/services/pending_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BankNotificationParser - UAE & GCC Bank Alerts', () {
    final parser = BankNotificationParser.instance;

    test('Parses Emirates NBD debit card alert with merchant and balance', () {
      const text =
          'Purchase of AED 245.50 with Debit Card ending 4321 at Carrefour on 06-Nov-2026. Avl Bal AED 12,450.00';
      final parsed = parser.tryParse(
        text: text,
        packageName: 'com.emiratesnbd.enbd',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 245.50);
      expect(parsed.currency, 'AED');
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.merchant.toLowerCase(), contains('carrefour'));
      expect(parsed.category, FinanceCategory.foodAndBeverages);
      expect(parsed.cardSuffix, '**4321');
      expect(parsed.availableBalance, 12450.00);
      expect(parsed.bankName, 'Emirates NBD');
    });

    test('Parses ADCB credit card transaction at Starbucks', () {
      const text =
          'Dear Customer, your Credit Card ending 9876 was used for AED 85.00 at Starbucks Dubai Mall on 06/11/2026.';
      final parsed = parser.tryParse(text: text);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 85.00);
      expect(parsed.currency, 'AED');
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.merchant.toLowerCase(), contains('starbucks'));
      expect(parsed.category, FinanceCategory.foodAndBeverages);
      expect(parsed.cardSuffix, '**9876');
    });

    test('Parses FAB bill payment for DEWA', () {
      const text =
          'Your account **1234 has been debited with AED 1,200.00 for DEWA electricity payment.';
      final parsed = parser.tryParse(
        text: text,
        packageName: 'com.firstabuDhabiBank.fab',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.00);
      expect(parsed.currency, 'AED');
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.cardSuffix, '**1234');
      expect(parsed.category, FinanceCategory.utilities);
      expect(parsed.bankName, 'FAB');
    });

    test('Parses Mashreq transport payment at Careem', () {
      const text =
          'AED 42.50 spent on Mashreq Card **5544 at Careem Taxi. Ref 998822.';
      final parsed = parser.tryParse(text: text);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 42.50);
      expect(parsed.currency, 'AED');
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.merchant.toLowerCase(), contains('careem'));
      expect(parsed.category, FinanceCategory.transport);
      expect(parsed.cardSuffix, '**5544');
    });

    group('Income Transaction Types', () {
      test('Parses salary credit as income with employer merchant', () {
        const text =
            'Salary credited: AED 18,500.00 from Acme Tech Corp to Account **9900 on 01-Nov.';
        final parsed = parser.tryParse(text: text);

        expect(parsed, isNotNull);
        expect(parsed!.amount, 18500.00);
        expect(parsed.currency, 'AED');
        expect(parsed.kind, FinanceKind.income);
        expect(parsed.cardSuffix, '**9900');
        expect(parsed.category, FinanceCategory.salaries);
      });

      test('Parses merchant refund as income type', () {
        const text =
            'Refund of AED 349.99 from Amazon UAE credited to card ending 4411. Avl Bal AED 8,500.00';
        final parsed = parser.tryParse(
          text: text,
          packageName: 'com.emiratesnbd.enbd',
        );

        expect(parsed, isNotNull);
        expect(parsed!.amount, 349.99);
        expect(parsed.currency, 'AED');
        expect(parsed.kind, FinanceKind.income);
        expect(parsed.cardSuffix, '**4411');
        expect(parsed.bankName, 'Emirates NBD');
      });

      test('Parses incoming wire/bank transfer as income', () {
        const text =
            'Inward transfer received: AED 5,000.00 from Rashid Al Nuaimi to ADCB Account **2211. Ref: TRF99231';
        final parsed = parser.tryParse(text: text);

        expect(parsed, isNotNull);
        expect(parsed!.amount, 5000.00);
        expect(parsed.currency, 'AED');
        expect(parsed.kind, FinanceKind.income);
        expect(parsed.bankName, 'ADCB');
        expect(parsed.cardSuffix, '**2211');
      });

      test('Parses cash deposit at ATM as income', () {
        const text =
            'Cash deposit of AED 3,000.00 credited to your FAB account ending 7733 at Dubai Mall ATM.';
        final parsed = parser.tryParse(text: text);

        expect(parsed, isNotNull);
        expect(parsed!.amount, 3000.00);
        expect(parsed.currency, 'AED');
        expect(parsed.kind, FinanceKind.income);
        expect(parsed.bankName, 'FAB');
        expect(parsed.cardSuffix, '**7733');
      });

      test('Parses dividend or investment payout credit alert as income', () {
        const text =
            'Credit alert: SAR 2,500.00 dividend received into your Al Rajhi investment account **4012.';
        final parsed = parser.tryParse(text: text);

        expect(parsed, isNotNull);
        expect(parsed!.amount, 2500.00);
        expect(parsed.currency, 'SAR');
        expect(parsed.kind, FinanceKind.income);
        expect(parsed.bankName, 'Al Rajhi');
      });
    });

    test('Parses Saudi Riyal (SAR) notification from Al Rajhi Bank', () {
      const text =
          'Purchase of SAR 320.00 using mada card *7712 at Panda Hypermarket.';
      final parsed = parser.tryParse(text: text);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 320.00);
      expect(parsed.currency, 'SAR');
      expect(parsed.kind, FinanceKind.expense);
      expect(parsed.merchant.toLowerCase(), contains('panda'));
      expect(parsed.category, FinanceCategory.foodAndBeverages);
    });

    test('Parses Dhs. and DH variations into AED', () {
      final parsed1 = parser.tryParse(
        text: 'Purchase of Dhs. 195.50 at Lulu Hypermarket with card **4433',
      );
      expect(parsed1, isNotNull);
      expect(parsed1!.amount, 195.50);
      expect(parsed1.currency, 'AED');

      final parsed2 = parser.tryParse(
        text: 'Paid DH 80.00 at Costa Coffee on card ending 1122',
      );
      expect(parsed2, isNotNull);
      expect(parsed2!.amount, 80.00);
      expect(parsed2.currency, 'AED');

      final parsed3 = parser.tryParse(
        text: '350 Dhs spent at Sephora with debit card **9911',
      );
      expect(parsed3, isNotNull);
      expect(parsed3!.amount, 350.00);
      expect(parsed3.currency, 'AED');
    });

    test(r'Parses USD ($), EUR (€), and GBP (£) international alerts', () {
      final usd = parser.tryParse(
        text: 'Purchase of \$45.00 at Apple Services on card ending 8811',
      );
      expect(usd, isNotNull);
      expect(usd!.amount, 45.00);
      expect(usd.currency, 'USD');

      final eur = parser.tryParse(
        text: 'Purchase of €120.00 at Hotel Paris on card ending 8811',
      );
      expect(eur, isNotNull);
      expect(eur!.amount, 120.00);
      expect(eur.currency, 'EUR');
    });

    test('Rejects non-transactional personal messages', () {
      const text = 'Hey buddy, are we meeting at the mall tomorrow?';
      final parsed = parser.tryParse(text: text);

      expect(parsed, isNull);
    });
  });

  group('PendingTransactionService', () {
    late PendingTransactionService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = PendingTransactionService.instance;
      await service.clearAll();
      await service.init();
    });

    test('Adds detected transaction and increments pendingCount', () async {
      final parsed = BankNotificationParser.instance.tryParse(
        text: 'Spent AED 150.00 at Carrefour on card **1234',
      );
      expect(parsed, isNotNull);

      final added = await service.addDetected(parsed!);
      expect(added, isTrue);
      expect(service.pendingCount, 1);
      expect(service.pending.first.parsed.amount, 150.00);
    });

    test('De-duplicates identical transactions within 5 minutes', () async {
      final parsed = BankNotificationParser.instance.tryParse(
        text: 'Spent AED 150.00 at Carrefour on card **1234',
      );
      expect(parsed, isNotNull);

      final first = await service.addDetected(parsed!);
      final duplicate = await service.addDetected(parsed);

      expect(first, isTrue);
      expect(duplicate, isFalse);
      expect(service.pendingCount, 1);
    });

    test('Marks transaction as confirmed', () async {
      final parsed = BankNotificationParser.instance.tryParse(
        text: 'Spent AED 50.00 at Costa Coffee on card **1234',
      );
      await service.addDetected(parsed!);

      final id = service.pending.first.id;
      await service.markConfirmed(id);

      expect(service.pendingCount, 0);
    });

    test('Marks transaction as dismissed', () async {
      final parsed = BankNotificationParser.instance.tryParse(
        text: 'Spent AED 99.00 at Vox Cinemas on card **1234',
      );
      await service.addDetected(parsed!);

      final id = service.pending.first.id;
      await service.markDismissed(id);

      expect(service.pendingCount, 0);
    });

    test('De-duplicates cross-source alerts (Push notification then SMS)', () async {
      // 1. Bank app push notification arrives first
      final pushParsed = BankNotificationParser.instance.tryParse(
        packageName: 'com.enbd.mobilebanking',
        title: 'Emirates NBD',
        text: 'Purchase of AED 250.00 with Card ending 9988 at Carrefour.',
      );
      expect(pushParsed, isNotNull);
      final firstAdded = await service.addDetected(pushParsed!);
      expect(firstAdded, isTrue);

      // 2. User confirms or dismisses it
      await service.markConfirmed(service.pending.first.id);

      // 3. SMS arrives 10 seconds later from generic SMS app with different wording
      final smsParsed = BankNotificationParser.instance.tryParse(
        packageName: 'com.google.android.apps.messaging',
        title: 'AD-ENBD',
        text: 'AED 250.00 spent on Card ending 9988 at Carrefour MOE. Avl Bal AED 10,000',
      );
      expect(smsParsed, isNotNull);

      // Should be dropped as duplicate even though first is already handled!
      final duplicateAdded = await service.addDetected(smsParsed!);
      expect(duplicateAdded, isFalse);
      expect(service.pendingCount, 0);
    });

    test('Parses WhatsApp banking notifications and rejects personal chats', () {
      final parser = BankNotificationParser.instance;

      // Personal chat in WhatsApp - should be rejected
      final personalChat = parser.tryParse(
        packageName: 'com.whatsapp',
        title: 'Family Group',
        text: 'Can you please transfer 250 AED for groceries tomorrow?',
      );
      expect(personalChat, isNull);

      // Official WhatsApp banking alert - should be parsed
      final whatsappAlert = parser.tryParse(
        packageName: 'com.whatsapp',
        title: 'Emirates NBD',
        text: 'Transaction alert: You have paid AED 45.00 at Starbucks using Card ending 1234.',
      );
      expect(whatsappAlert, isNotNull);
      expect(whatsappAlert!.amount, 45.00);
      expect(whatsappAlert.currency, 'AED');
      expect(whatsappAlert.merchant.toLowerCase(), contains('starbucks'));
    });

    test('Ensures auto-detected transactions are scoped strictly to Personal collection', () {
      final personalId = DocumentCollectionService.instance.personalCollectionId;
      expect(personalId, equals(DocumentCollection.personalId));
    });
  });
}
