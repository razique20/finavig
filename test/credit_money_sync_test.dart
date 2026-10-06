import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/credit.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/screens/money/forms/credit_form_sheet.dart';
import 'package:finavig/screens/money/forms/credit_settle_sheet.dart';
import 'package:finavig/services/finance_service.dart';

CreditEntry _entry({
  String id = 'c1',
  CreditDirection direction = CreditDirection.borrowed,
  double amount = 500,
  String counterpartyName = 'Ahmed',
  String? disbursementTransactionId,
}) =>
    CreditEntry(
      id: id,
      collectionId: 'personal',
      direction: direction,
      counterpartyName: counterpartyName,
      amount: amount,
      currency: 'AED',
      startDate: DateTime(2026, 9, 1),
      deadline: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 9, 1),
      disbursementTransactionId: disbursementTransactionId,
    );

/// Opens [sheet] as a modal bottom sheet and hands back a future that
/// resolves with the value it pops.
Future<Future<T?>> _openSheet<T>(WidgetTester tester, Widget sheet) async {
  final completer = Completer<T?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                completer.complete(
                  await showModalBottomSheet<T>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => sheet,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return completer.future;
}

/// Scrolls [finder] into view before tapping — the sheets are taller than
/// the test surface.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FinanceService.instance.clearCache();
  });

  group('CreditFormSheet origin sync', () {
    testWidgets('is off by default — Save returns no Money leg',
        (tester) async {
      final future = await _openSheet<CreditFormResult>(
        tester,
        const CreditFormSheet(),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Ahmed');
      await tester.enterText(find.byType(TextField).at(2), '500');
      await tester.pump();

      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));

      final result = await future;
      expect(result, isNotNull);
      expect(result!.disbursement, isNull);
      expect(result.entry.amount, 500);
    });

    testWidgets('ticking the checkbox builds a linked income leg',
        (tester) async {
      final future = await _openSheet<CreditFormResult>(
        tester,
        const CreditFormSheet(),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Ahmed');
      await tester.enterText(find.byType(TextField).at(2), '750');
      await tester.pump();

      await _tap(tester, find.text('Also record this in Money'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));

      final result = await future;
      final leg = result!.disbursement;
      expect(leg, isNotNull);
      // Borrowed money received = income.
      expect(leg!.kind, FinanceKind.income);
      expect(leg.amount, 750);
      expect(leg.creditId, result.entry.id);
      expect(leg.creditLeg, CreditLeg.disbursement);
      expect(leg.collectionId, 'personal');
    });

    testWidgets('lent money mirrors as an expense', (tester) async {
      final future = await _openSheet<CreditFormResult>(
        tester,
        const CreditFormSheet(),
      );

      await _tap(tester, find.text('I lent'));
      await tester.enterText(find.byType(TextField).at(0), 'Sara');
      await tester.enterText(find.byType(TextField).at(2), '300');
      await tester.pump();
      await _tap(tester, find.text('Also record this in Money'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));

      final result = await future;
      expect(result!.disbursement?.kind, FinanceKind.expense);
      expect(result.disbursement?.title, 'Lent to Sara');
    });
  });

  group('CreditSettleSheet', () {
    testWidgets('lent entry defaults to a linked income repayment',
        (tester) async {
      final entry = _entry(direction: CreditDirection.lent, amount: 400);
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      expect(find.text('Money received back'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as received'));

      final result = await future;
      final leg = result!.newTransaction;
      expect(leg, isNotNull);
      expect(result.logsInMoney, isTrue);
      expect(leg!.kind, FinanceKind.income);
      expect(leg.amount, 400);
      expect(leg.creditId, entry.id);
      expect(leg.creditLeg, CreditLeg.settlement);
    });

    testWidgets('borrowed entry mirrors as an expense', (tester) async {
      final entry = _entry(direction: CreditDirection.borrowed, amount: 850);
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as repaid'));

      final result = await future;
      expect(result!.newTransaction?.kind, FinanceKind.expense);
      expect(result.newTransaction?.amount, 850);
    });

    testWidgets('choosing "only settle" writes nothing to Money',
        (tester) async {
      final entry = _entry(direction: CreditDirection.lent);
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      await _tap(tester, find.text('Only settle the credit'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as received'));

      final result = await future;
      expect(result!.logsInMoney, isFalse);
      expect(result.newTransaction, isNull);
      expect(result.linkedTransactionId, isNull);
    });

    testWidgets('offers an already-logged repayment for attachment',
        (tester) async {
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-existing',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.other,
          title: 'Paid Ahmed',
          amount: 500,
          occurredAt: DateTime(2026, 9, 12),
        ),
      );

      final entry = _entry(direction: CreditDirection.borrowed);
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      await _tap(tester, find.text('Attach one I already logged'));
      await _tap(tester, find.text('Paid Ahmed'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as repaid'));

      final result = await future;
      expect(result!.linkedTransactionId, 'tx-existing');
      expect(result.newTransaction, isNull);
    });

    testWidgets('borrowed entry links a matching hand-logged principal',
        (tester) async {
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-principal',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.other,
          title: 'Borrowed from Ahmed',
          amount: 900,
          occurredAt: DateTime(2026, 9, 1),
        ),
      );

      final entry = _entry(direction: CreditDirection.borrowed, amount: 900);
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      expect(find.text('Money you received'), findsOneWidget);
      expect(find.text('Borrowed from Ahmed'), findsOneWidget);

      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as repaid'));

      final result = await future;
      // The single amount-matching principal is preselected and handed back.
      expect(result!.linkedDisbursementId, 'tx-principal');
    });

    testWidgets('no principal section once the loan already carries one',
        (tester) async {
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-principal',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.other,
          title: 'Borrowed from Ahmed',
          amount: 900,
          occurredAt: DateTime(2026, 9, 1),
        ),
      );

      final entry = _entry(
        direction: CreditDirection.borrowed,
        amount: 900,
        disbursementTransactionId: 'tx-principal',
      );
      final future = await _openSheet<CreditSettlement>(
        tester,
        CreditSettleSheet(entry: entry),
      );

      expect(find.text('Money you received'), findsNothing);
      await _tap(tester, find.widgetWithText(FilledButton, 'Mark as repaid'));
      final result = await future;
      expect(result!.linkedDisbursementId, isNull);
    });
  });
}
