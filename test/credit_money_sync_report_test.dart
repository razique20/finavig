import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/credit.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/screens/money/money_rows.dart';
import 'package:finavig/screens/money/money_summary_cards.dart';
import 'package:finavig/services/credit_service.dart';
import 'package:finavig/services/finance_service.dart';
import 'package:finavig/services/monthly_summary_service.dart';

/// End-to-end verification of the credit ↔ Money sync: what it writes, what
/// the Money tab shows, and — crucially — what it deliberately keeps out of
/// the income/expense analytics while still listing the row.

CreditEntry _credit({
  required String id,
  CreditDirection direction = CreditDirection.borrowed,
  double amount = 1000,
}) =>
    CreditEntry(
      id: id,
      collectionId: 'personal',
      direction: direction,
      counterpartyName: 'Ahmed',
      amount: amount,
      currency: 'AED',
      startDate: DateTime.now(),
      deadline: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );

/// The leg the form would build for a new credit.
FinanceTransaction _disbursement(CreditEntry c) => FinanceTransaction(
      id: 'tx-out-${c.id}',
      collectionId: c.collectionId,
      kind: c.direction == CreditDirection.borrowed
          ? FinanceKind.income
          : FinanceKind.expense,
      category: FinanceCategory.other,
      title: c.direction == CreditDirection.borrowed
          ? 'Borrowed from ${c.counterpartyName}'
          : 'Lent to ${c.counterpartyName}',
      amount: c.amount,
      currency: c.currency,
      occurredAt: c.startDate,
      creditId: c.id,
      creditLeg: CreditLeg.disbursement,
    );

/// The leg the settle sheet would build.
FinanceTransaction _settlement(CreditEntry c, {DateTime? at}) =>
    FinanceTransaction(
      id: 'tx-in-${c.id}',
      collectionId: c.collectionId,
      kind: c.direction == CreditDirection.borrowed
          ? FinanceKind.expense
          : FinanceKind.income,
      category: FinanceCategory.other,
      title: c.direction == CreditDirection.borrowed
          ? 'Repaid ${c.counterpartyName}'
          : '${c.counterpartyName} repaid me',
      amount: c.amount,
      currency: c.currency,
      occurredAt: at ?? DateTime.now(),
      creditId: c.id,
      creditLeg: CreditLeg.settlement,
    );

FinanceTransaction _ordinary({
  required String id,
  required String title,
  required double amount,
  FinanceKind kind = FinanceKind.expense,
  FinanceCategory category = FinanceCategory.rent,
}) =>
    FinanceTransaction(
      id: id,
      collectionId: 'personal',
      kind: kind,
      category: category,
      title: title,
      amount: amount,
      occurredAt: DateTime.now(),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CreditService.instance.clearCache();
    FinanceService.instance.clearCache();
  });

  group('Sync mechanics — origin', () {
    test('borrowed credit mirrors as income and links both ways', () async {
      final credit = _credit(id: 'c-borrow', amount: 3000);
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final entry = CreditService.instance.activeCredits.single;
      expect(entry.disbursementTransactionId, 'tx-out-c-borrow');
      expect(entry.isSettled, isFalse);

      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.kind, FinanceKind.income);
      expect(tx.amount, 3000);
      expect(tx.creditId, 'c-borrow');
      expect(tx.creditLeg, CreditLeg.disbursement);
      expect(FinanceService.instance.activeTransactions.single.currency, 'AED');
    });

    test('lent credit mirrors as an expense', () async {
      final credit = _credit(
        id: 'c-lend',
        direction: CreditDirection.lent,
        amount: 800,
      );
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.kind, FinanceKind.expense);
      expect(tx.creditLeg, CreditLeg.disbursement);
    });

    test('no disbursement means no Money row is written', () async {
      await CreditService.instance
          .addCreditWithDisbursement(_credit(id: 'c-plain'));
      expect(FinanceService.instance.activeTransactions, isEmpty);
    });
  });

  group('Sync mechanics — settlement', () {
    test('repaying a borrowed loan writes an expense and closes the credit',
        () async {
      final credit = _credit(id: 'c1', amount: 1000);
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final stored = CreditService.instance.activeCredits.single;
      await CreditService.instance.settleCredit(
        'c1',
        settledAt: DateTime.now(),
        transaction: _settlement(stored),
      );

      final entry = CreditService.instance.activeCredits.single;
      expect(entry.isSettled, isTrue);
      expect(entry.settlementTransactionId, 'tx-in-c1');

      // Two legs now: income (principal) and expense (repayment).
      final txs = FinanceService.instance.activeTransactions;
      expect(txs, hasLength(2));
      expect(
        txs.map((t) => t.kind).toSet(),
        {FinanceKind.income, FinanceKind.expense},
      );
      expect(
        txs.map((t) => t.creditLeg).toSet(),
        {CreditLeg.disbursement, CreditLeg.settlement},
      );
    });

    test('money received back on a lent loan writes income', () async {
      final credit = _credit(
        id: 'c2',
        direction: CreditDirection.lent,
        amount: 500,
      );
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );
      await CreditService.instance.settleCredit(
        'c2',
        settledAt: DateTime.now(),
        transaction: _settlement(CreditService.instance.activeCredits.single),
      );
      expect(
        FinanceService.instance.activeTransactions
            .firstWhere((t) => t.creditLeg == CreditLeg.settlement)
            .kind,
        FinanceKind.income,
      );
    });

    test('a settled credit leaves the totals but stays in history', () async {
      final credit = _credit(id: 'c3', amount: 700);
      await CreditService.instance.addCreditWithDisbursement(credit);
      await CreditService.instance.settleCredit(
        'c3',
        settledAt: DateTime.now(),
      );

      final entries = CreditService.instance.activeCredits;
      expect(entries, hasLength(1)); // still listed
      expect(CreditMath.totals(entries).borrowed, 0); // not outstanding
      expect(CreditMath.openOnly(entries), isEmpty);
    });

    test('settling twice does not create a second leg', () async {
      final credit = _credit(id: 'c4');
      await CreditService.instance.addCreditWithDisbursement(credit);
      await CreditService.instance.settleCredit(
        'c4',
        settledAt: DateTime.now(),
        transaction: _settlement(credit),
      );
      await CreditService.instance.settleCredit(
        'c4',
        settledAt: DateTime.now(),
        transaction: _settlement(credit),
      );
      expect(FinanceService.instance.activeTransactions, hasLength(1));
    });

    test('a hand-logged borrowed loan is reconciled on settle', () async {
      // The 900 landed as plain income — logged by hand and never linked.
      await FinanceService.instance.addTransaction(
        _ordinary(
          id: 'tx-hand',
          title: 'Borrowed from Ahmed',
          amount: 900,
          kind: FinanceKind.income,
          category: FinanceCategory.other,
        ),
      );
      await CreditService.instance.addCredit(_credit(id: 'c5', amount: 900));

      await CreditService.instance.settleCredit(
        'c5',
        settledAt: DateTime.now(),
        transaction: _settlement(CreditService.instance.activeCredits.single),
        disbursementTransactionId: 'tx-hand',
      );

      final txs = FinanceService.instance.activeTransactions;
      expect(txs, hasLength(2));
      expect(txs.every((t) => t.isCreditLinked), isTrue);
      // Both legs are loan movements, so neither reads as real cash.
      final summary = FinanceMath.summaryForMonth(txs, DateTime.now());
      expect(summary.income, 0);
      expect(summary.expense, 0);
    });
  });

  group('Money tab — what is shown', () {
    test('loan legs are LISTED in the transaction log', () async {
      final credit = _credit(id: 'c1', amount: 3000);
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final txs = FinanceService.instance.activeTransactions;
      expect(txs, hasLength(1));
      expect(txs.single.title, 'Borrowed from Ahmed');
      expect(txs.single.amount, 3000);
    });

    test('loan legs are EXCLUDED from the Money summary totals', () async {
      await FinanceService.instance
          .addTransaction(_ordinary(
            id: 'real-income',
            title: 'Salary',
            amount: 5000,
            kind: FinanceKind.income,
            category: FinanceCategory.salaries,
          ));

      final credit = _credit(id: 'c1', amount: 3000);
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final txs = FinanceService.instance.activeTransactions;
      expect(txs, hasLength(2)); // both visible in the log …
      final summary = FinanceMath.summaryForMonth(txs, DateTime.now());
      expect(summary.income, 5000); // … but the loan is not income
    });

    test('a repayment does not consume a category budget', () async {
      await FinanceService.instance.addTransaction(
        _ordinary(id: 'real', title: 'Rent', amount: 1200),
      );
      final credit = _credit(id: 'c1', amount: 900);
      await CreditService.instance.addCreditWithDisbursement(credit);
      await CreditService.instance.settleCredit(
        'c1',
        settledAt: DateTime.now(),
        transaction: _settlement(credit),
      );

      final spend = FinanceMath.spendByCategory(
        FinanceService.instance.activeTransactions,
        DateTime.now(),
      );
      expect(spend[FinanceCategory.rent], 1200);
      expect(spend.containsKey(FinanceCategory.other), isFalse);
    });

    test('MonthlySummaryService (feeds the AI) excludes loan legs', () async {
      await FinanceService.instance.addTransaction(
        _ordinary(id: 'real', title: 'Rent', amount: 1200),
      );
      final credit = _credit(id: 'c1', amount: 900);
      await CreditService.instance.addCreditWithDisbursement(
        credit,
        disbursement: _disbursement(credit),
      );

      final data = MonthlySummaryService.instance.generate(now: DateTime.now());
      // The 900 loan expense must not appear in the month's expenses.
      expect(data.expense, 1200);
    });

    testWidgets('the "Biggest expenses" card hides a loan repayment',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopExpensesCard(
              transactions: [
                _ordinary(id: 'real', title: 'Real rent', amount: 1200),
                _settlement(_credit(id: 'c1', amount: 900)),
              ],
            ),
          ),
        ),
      );
      // The collapsible body animates open from frame 0.
      await tester.pumpAndSettle();
      expect(find.text('Real rent'), findsOneWidget);
      expect(find.text('Repaid Ahmed'), findsNothing);
    });

    testWidgets('the transaction tile tags a loan leg as "Credit"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(transaction: _settlement(_credit(id: 'c1'))),
          ),
        ),
      );
      expect(find.text('Credit'), findsOneWidget);
    });

    testWidgets('an ordinary transaction carries no Credit tag',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: _ordinary(id: 'x', title: 'Rent', amount: 10),
            ),
          ),
        ),
      );
      expect(find.text('Credit'), findsNothing);
    });
  });
}
