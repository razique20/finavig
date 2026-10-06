import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/credit.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/credit_service.dart';
import 'package:finavig/services/finance_service.dart';

CreditEntry _entry({
  String id = 'c1',
  CreditDirection direction = CreditDirection.borrowed,
  double amount = 500,
  String currency = 'USD',
  String counterpartyName = 'Ahmed',
  String? counterpartyPhone,
  String? description,
  DateTime? startDate,
  DateTime? deadline,
  DateTime? createdAt,
  List<CreditExtension> extensionHistory = const [],
}) {
  // Older records defaulted their borrow/lend date to creation time;
  // mirror that here unless a test sets startDate explicitly.
  final created = createdAt ?? DateTime(2026, 9, 1);
  return CreditEntry(
    id: id,
    collectionId: 'personal',
    direction: direction,
    counterpartyName: counterpartyName,
    counterpartyPhone: counterpartyPhone,
    description: description,
    amount: amount,
    currency: currency,
    startDate: startDate ?? created,
    deadline: deadline ?? DateTime(2026, 9, 20),
    extensionHistory: extensionHistory,
    createdAt: created,
  );
}

void main() {
  final now = DateTime(2026, 9, 10);

  group('CreditMath.daysUntil / isOverdue', () {
    test('negative days when the deadline passed', () {
      final e = _entry(deadline: DateTime(2026, 9, 7));
      expect(CreditMath.daysUntil(e, now: now), -3);
      expect(CreditMath.isOverdue(e, now: now), isTrue);
    });

    test('zero on the deadline day itself', () {
      final e = _entry(deadline: DateTime(2026, 9, 10));
      expect(CreditMath.daysUntil(e, now: now), 0);
      expect(CreditMath.isOverdue(e, now: now), isFalse);
    });

    test('positive days when the deadline is ahead', () {
      final e = _entry(deadline: DateTime(2026, 9, 15));
      expect(CreditMath.daysUntil(e, now: now), 5);
      expect(CreditMath.isOverdue(e, now: now), isFalse);
    });

    test('compares calendar days, not time-of-day', () {
      final e = _entry(deadline: DateTime(2026, 9, 10, 23, 59));
      // Later the same calendar day is still "due today".
      expect(CreditMath.daysUntil(e, now: now), 0);
    });
  });

  group('CreditMath.deadlineLabel', () {
    test('overdue wording', () {
      final one = _entry(deadline: DateTime(2026, 9, 9));
      final many = _entry(deadline: DateTime(2026, 9, 1));
      expect(CreditMath.deadlineLabel(one, now: now), 'Overdue by 1 day');
      expect(CreditMath.deadlineLabel(many, now: now), 'Overdue by 9 days');
    });

    test('near-term wording', () {
      expect(
        CreditMath.deadlineLabel(
          _entry(deadline: DateTime(2026, 9, 10)),
          now: now,
        ),
        'Due today',
      );
      expect(
        CreditMath.deadlineLabel(
          _entry(deadline: DateTime(2026, 9, 11)),
          now: now,
        ),
        'Due tomorrow',
      );
      expect(
        CreditMath.deadlineLabel(
          _entry(deadline: DateTime(2026, 9, 14)),
          now: now,
        ),
        'Due in 4 days',
      );
    });

    test('falls back to a formatted date further out', () {
      expect(
        CreditMath.deadlineLabel(
          _entry(deadline: DateTime(2026, 10, 2)),
          now: now,
        ),
        'Due 02/10/2026',
      );
    });
  });

  group('CreditEntry.extendDeadline', () {
    test('appends to history and preserves the original deadline', () {
      final original = DateTime(2026, 9, 20);
      final first = _entry(deadline: original);
      final second = first.extendDeadline(
        DateTime(2026, 10, 1),
        at: DateTime(2026, 9, 5),
      );

      expect(second.extensionCount, 1);
      expect(second.deadline, DateTime(2026, 10, 1));
      expect(second.originalDeadline, original);
      expect(second.extensionHistory.single.from, original);
      expect(second.extensionHistory.single.to, DateTime(2026, 10, 1));
      expect(second.extensionHistory.single.at, DateTime(2026, 9, 5));
    });

    test('second extension keeps the full trail', () {
      final e = _entry(deadline: DateTime(2026, 9, 20))
          .extendDeadline(DateTime(2026, 10, 1))
          .extendDeadline(DateTime(2026, 11, 1));

      expect(e.extensionCount, 2);
      expect(e.originalDeadline, DateTime(2026, 9, 20));
      expect(e.extensionHistory[1].from, DateTime(2026, 10, 1));
      expect(e.extensionHistory[1].to, DateTime(2026, 11, 1));
      // Original entry untouched (extend returns a copy).
      expect(_entry(deadline: DateTime(2026, 9, 20)).extensionCount, 0);
    });

    test('rejects a deadline that is not later', () {
      final e = _entry(deadline: DateTime(2026, 9, 20));
      expect(
        () => e.extendDeadline(DateTime(2026, 9, 20)),
        throwsAssertionError,
      );
      expect(
        () => e.extendDeadline(DateTime(2026, 9, 19)),
        throwsAssertionError,
      );
    });
  });

  group('CreditMath.totals', () {
    test('sums borrowed and lent separately', () {
      final credits = [
        _entry(id: 'a', amount: 100, direction: CreditDirection.borrowed),
        _entry(id: 'b', amount: 250, direction: CreditDirection.borrowed),
        _entry(id: 'c', amount: 800, direction: CreditDirection.lent),
      ];
      final totals = CreditMath.totals(credits);
      expect(totals.borrowed, 350);
      expect(totals.lent, 800);
      // Net is what comes back minus what goes out.
      expect(totals.net, 450);
    });
  });

  group('CreditMath.sortedForDisplay', () {
    test('overdue first (most overdue on top), then soonest', () {
      final credits = [
        _entry(id: 'future', deadline: DateTime(2026, 9, 20)),
        _entry(id: 'overdue-a-lot', deadline: DateTime(2026, 9, 1)),
        _entry(id: 'overdue-a-bit', deadline: DateTime(2026, 9, 8)),
        _entry(id: 'soon', deadline: DateTime(2026, 9, 12)),
      ];
      final sorted = CreditMath.sortedForDisplay(credits, now: now);
      expect(sorted.map((c) => c.id).toList(), [
        'overdue-a-lot',
        'overdue-a-bit',
        'soon',
        'future',
      ]);
    });
  });

  group('WhatsApp follow-up templates', () {
    test('lent entry, friendly template mentions name and amount', () {
      final e = _entry(
        direction: CreditDirection.lent,
        amount: 1200.5,
        currency: 'USD',
        counterpartyName: 'Ahmed',
        deadline: DateTime(2026, 9, 20),
      );
      final msg = CreditMath.followUpMessage(e, friendly: true);
      expect(msg, contains('Ahmed'));
      expect(msg, contains('USD 1,200.50'));
      expect(msg, contains('20/09/2026'));
    });

    test('borrowed entry, standard template states the due date', () {
      final e = _entry(
        direction: CreditDirection.borrowed,
        amount: 300,
        currency: 'EUR',
        counterpartyName: 'Sara',
        deadline: DateTime(2026, 9, 20),
        startDate: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 8, 20),
      );
      final msg = CreditMath.followUpMessage(e, friendly: false);
      expect(msg, contains('Sara'));
      expect(msg, contains('EUR 300.00'));
      expect(msg, contains('due on 20/09/2026'));
      expect(msg, contains('borrowed on 20/08/2026'));
    });

    test('standard template uses startDate, not the record creation date',
        () {
      final e = _entry(
        direction: CreditDirection.lent,
        amount: 300,
        counterpartyName: 'Sara',
        deadline: DateTime(2026, 9, 20),
        startDate: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 9, 1),
      );
      final msg = CreditMath.followUpMessage(e, friendly: false);
      expect(msg, contains('lent on 10/08/2026'));
      expect(msg, isNot(contains('01/09/2026')));
    });

    test('wa.me link encodes the message and strips phone formatting', () {
      final uri = CreditMath.whatsappLink(
        '+971 50-123 4567',
        'Hi Ahmed! "Pay me" \$100',
      );
      expect(uri.authority, 'wa.me');
      expect(uri.path, '/971501234567');
      expect(uri.queryParameters['text'], 'Hi Ahmed! "Pay me" \$100');
    // Note: Uri.encodeComponent leaves "!" unescaped (sub-delim).
    expect(
      uri.toString(),
      'https://wa.me/971501234567?text='
      'Hi%20Ahmed!%20%22Pay%20me%22%20%24100',
    );
    });

    test('followUpLink builds from the entry phone', () {
      final e = _entry(
        counterpartyPhone: '+971501234567',
        deadline: DateTime(2026, 9, 20),
      );
      final uri = CreditMath.followUpLink(e);
      expect(uri.path, '/971501234567');
      expect(uri.queryParameters['text'], isNotEmpty);
    });

    test('entry without a phone still yields an (empty-number) link', () {
      final e = _entry(counterpartyPhone: null);
      final uri = CreditMath.followUpLink(e);
      expect(uri.path, '/');
    });
  });

  group('CreditEntry JSON round-trip', () {
    test('preserves all fields including extension history', () {
      final e = _entry(
        id: 'c-json',
        direction: CreditDirection.lent,
        amount: 750.25,
        currency: 'GBP',
        counterpartyName: 'John Doe',
        counterpartyPhone: '+44 7700 900123',
        deadline: DateTime(2026, 12, 31),
      ).extendDeadline(DateTime(2027, 1, 31));

      final restored = CreditEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, e.id);
      expect(restored.direction, CreditDirection.lent);
      expect(restored.counterpartyName, 'John Doe');
      expect(restored.counterpartyPhone, '+44 7700 900123');
      expect(restored.amount, 750.25);
      expect(restored.currency, 'GBP');
      expect(restored.deadline, DateTime(2027, 1, 31));
      expect(restored.originalDeadline, DateTime(2026, 12, 31));
      expect(restored.extensionCount, 1);
      expect(restored.createdAt, e.createdAt);
    });

    test('preserves start date and description', () {
      final e = _entry(
        id: 'c-note',
        description: 'Borrowed for car repair',
        startDate: DateTime(2026, 8, 15),
        deadline: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 9, 1),
      );

      final restored = CreditEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );

      expect(restored.startDate, DateTime(2026, 8, 15));
      expect(restored.description, 'Borrowed for car repair');
    });

    test('missing optional fields fall back safely', () {
      final restored = CreditEntry.fromJson({
        'id': 'c-min',
        'deadline': DateTime(2026, 9, 20).toIso8601String(),
        'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      });
      expect(restored.collectionId, 'personal');
      expect(restored.direction, CreditDirection.borrowed);
      expect(restored.counterpartyName, 'Contact');
      expect(restored.counterpartyPhone, isNull);
      expect(restored.description, isNull);
      // No startDate on older records — fall back to createdAt.
      expect(restored.startDate, DateTime(2026, 9, 1));
      expect(restored.amount, 0);
      expect(restored.currency, 'AED');
      expect(restored.extensionCount, 0);
    });
  });

  group('CreditService local flow (no Supabase in tests)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CreditService.instance.clearCache();
    });

    test('addCredit lists the entry scoped to the active collection',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(
        _entry(id: 'flow-1', direction: CreditDirection.lent),
      );

      final listed = service.activeCredits;
      expect(listed, hasLength(1));
      expect(listed.single.counterpartyName, 'Ahmed');
      expect(listed.single.amount, 500);
      expect(listed.single.direction, CreditDirection.lent);
    });

    test('extendDeadline moves the deadline and preserves the trail',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(
        _entry(id: 'flow-2', deadline: DateTime(2026, 9, 20)),
      );

      await service.extendDeadline('flow-2', DateTime(2026, 10, 5));
      final entry = service.activeCredits.single;
      expect(entry.deadline, DateTime(2026, 10, 5));
      expect(entry.originalDeadline, DateTime(2026, 9, 20));
      expect(entry.extensionHistory, hasLength(1));
      expect(entry.extensionHistory.single.to, DateTime(2026, 10, 5));

      await service.extendDeadline('flow-2', DateTime(2026, 10, 20));
      final extended = service.activeCredits.single;
      expect(extended.extensionHistory, hasLength(2));
      expect(extended.originalDeadline, DateTime(2026, 9, 20));
    });

    test('updateCredit replaces the stored entry', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 'flow-3', amount: 100));

      await service.updateCredit(
        _entry(id: 'flow-3', amount: 250, counterpartyName: 'Sara'),
      );
      final updated = service.activeCredits.single;
      expect(updated.amount, 250);
      expect(updated.counterpartyName, 'Sara');
    });

    test('deleteCredit removes the entry', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 'flow-4'));
      expect(service.activeCredits, hasLength(1));

      await service.deleteCredit('flow-4');
      expect(service.activeCredits, isEmpty);
    });

    test('records survive a cold start via the local store', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(
        _entry(
          id: 'flow-5',
          direction: CreditDirection.lent,
          amount: 1200,
          counterpartyPhone: '+971501234567',
          description: 'Lent for a deposit',
          startDate: DateTime(2026, 9, 1),
          deadline: DateTime(2026, 9, 30),
        ),
      );

      // Simulate an app restart: drop the in-memory cache, re-init.
      service.clearCache();
      await service.init();

      final reloaded = service.activeCredits;
      expect(reloaded, hasLength(1));
      expect(reloaded.single.id, 'flow-5');
      expect(reloaded.single.direction, CreditDirection.lent);
      expect(reloaded.single.counterpartyPhone, '+971501234567');
      expect(reloaded.single.amount, 1200);
      expect(reloaded.single.deadline, DateTime(2026, 9, 30));
      expect(reloaded.single.startDate, DateTime(2026, 9, 1));
      expect(reloaded.single.description, 'Lent for a deposit');
    });
  });

  group('CreditEntry settlement', () {
    test('markSettled stamps the date and links the Money transaction', () {
      final e = _entry().markSettled(
        at: DateTime(2026, 9, 12),
        transactionId: 'tx-1',
      );
      expect(e.isSettled, isTrue);
      expect(e.settledAt, DateTime(2026, 9, 12));
      expect(e.settlementTransactionId, 'tx-1');
      // The source entry is untouched (markSettled returns a copy).
      expect(_entry().isSettled, isFalse);
    });

    test('settled entries leave the outstanding totals', () {
      final credits = [
        _entry(id: 'open', amount: 100, direction: CreditDirection.borrowed),
        _entry(id: 'closed', amount: 900, direction: CreditDirection.borrowed)
            .markSettled(at: DateTime(2026, 9, 12)),
      ];
      final totals = CreditMath.totals(credits);
      expect(totals.borrowed, 100);
      expect(totals.net, -100);
    });

    test('isOverdue is false once settled, even past the deadline', () {
      final overdue = _entry(deadline: DateTime(2026, 9, 1));
      expect(CreditMath.isOverdue(overdue, now: now), isTrue);
      expect(
        CreditMath.isOverdue(
          overdue.markSettled(at: DateTime(2026, 9, 2)),
          now: now,
        ),
        isFalse,
      );
    });

    test('sortedForDisplay sinks settled entries to the bottom', () {
      final credits = [
        _entry(id: 'settled', deadline: DateTime(2026, 9, 1))
            .markSettled(at: DateTime(2026, 9, 2)),
        _entry(id: 'open-late', deadline: DateTime(2026, 9, 20)),
        _entry(id: 'open-soon', deadline: DateTime(2026, 9, 12)),
      ];
      expect(
        CreditMath.sortedForDisplay(credits, now: now)
            .map((c) => c.id)
            .toList(),
        ['open-soon', 'open-late', 'settled'],
      );
    });

    test('openOnly drops settled entries', () {
      final credits = [
        _entry(id: 'a'),
        _entry(id: 'b').markSettled(at: DateTime(2026, 9, 12)),
      ];
      expect(CreditMath.openOnly(credits).map((c) => c.id), ['a']);
    });

    test('extendDeadline keeps the settlement state', () {
      final settled = _entry(deadline: DateTime(2026, 9, 20))
          .markSettled(at: DateTime(2026, 9, 12), transactionId: 'tx-1');
      final extended = settled.extendDeadline(DateTime(2026, 10, 20));
      expect(extended.isSettled, isTrue);
      expect(extended.settledAt, DateTime(2026, 9, 12));
      expect(extended.settlementTransactionId, 'tx-1');
    });
  });

  group('CreditEntry settlement JSON round-trip', () {
    test('preserves settledAt and both Money links', () {
      final e = _entry(id: 'c-settled').copyWith(
        settledAt: DateTime(2026, 9, 12),
        disbursementTransactionId: 'tx-out',
        settlementTransactionId: 'tx-in',
      );
      final restored = CreditEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(restored.isSettled, isTrue);
      expect(restored.settledAt, DateTime(2026, 9, 12));
      expect(restored.disbursementTransactionId, 'tx-out');
      expect(restored.settlementTransactionId, 'tx-in');
    });

    test('legacy rows load as unsettled with no links', () {
      final restored = CreditEntry.fromJson({'id': 'c-legacy'});
      expect(restored.isSettled, isFalse);
      expect(restored.settledAt, isNull);
      expect(restored.disbursementTransactionId, isNull);
      expect(restored.settlementTransactionId, isNull);
    });

    test('copyWith can clear a settlement', () {
      final settled = _entry().markSettled(at: DateTime(2026, 9, 12));
      expect(settled.copyWith(settledAt: null).isSettled, isFalse);
    });
  });

  group('CreditService settlement flow (local only)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CreditService.instance.clearCache();
      FinanceService.instance.clearCache();
    });

    test('settleCredit without a transaction only closes the credit',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's1'));

      await service.settleCredit('s1', settledAt: DateTime(2026, 9, 12));

      final e = service.activeCredits.single;
      expect(e.isSettled, isTrue);
      expect(e.settlementTransactionId, isNull);
      expect(FinanceService.instance.activeTransactions, isEmpty);
    });

    test('settleCredit writes and links the repayment leg', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(
        _entry(id: 's2', direction: CreditDirection.lent, amount: 400),
      );
      final repayment = FinanceTransaction(
        id: 'tx-repay',
        collectionId: 'personal',
        kind: FinanceKind.income,
        category: FinanceCategory.other,
        title: 'Ahmed repaid me',
        amount: 400,
        occurredAt: DateTime(2026, 9, 12),
        creditId: 's2',
        creditLeg: CreditLeg.settlement,
      );

      await service.settleCredit(
        's2',
        settledAt: DateTime(2026, 9, 12),
        transaction: repayment,
      );

      final e = service.activeCredits.single;
      expect(e.isSettled, isTrue);
      expect(e.settlementTransactionId, 'tx-repay');
      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.id, 'tx-repay');
      expect(tx.kind, FinanceKind.income);
      expect(tx.creditId, 's2');
      expect(tx.creditLeg, CreditLeg.settlement);
    });

    test('settleCredit attaches an already-logged transaction by id',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's3'));
      final existing = FinanceTransaction(
        id: 'tx-existing',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.other,
        title: 'Paid Ahmed',
        amount: 500,
        occurredAt: DateTime(2026, 9, 12),
      );
      await FinanceService.instance.addTransaction(existing);

      await service.settleCredit(
        's3',
        settledAt: DateTime(2026, 9, 12),
        transactionId: 'tx-existing',
      );

      expect(
        service.activeCredits.single.settlementTransactionId,
        'tx-existing',
      );
      // Nothing new was logged — the existing record was reused.
      expect(FinanceService.instance.activeTransactions, hasLength(1));
    });

    test('settleCredit tags an attached repayment as a credit leg',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's6'));
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-attach',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.other,
          title: 'Paid Ahmed',
          amount: 500,
          occurredAt: DateTime(2026, 9, 12),
        ),
      );

      await service.settleCredit(
        's6',
        settledAt: DateTime(2026, 9, 12),
        transactionId: 'tx-attach',
      );

      // The reused row is tagged, not merely pointed at — otherwise it keeps
      // counting as real spending and can be attached to a second credit.
      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.isCreditLinked, isTrue);
      expect(tx.creditId, 's6');
      expect(tx.creditLeg, CreditLeg.settlement);
    });

    test('settleCredit links a hand-logged principal leg', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's7', amount: 900));
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-hand',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.other,
          title: 'Borrowed from Ahmed',
          amount: 900,
          occurredAt: DateTime(2026, 9, 1),
        ),
      );

      await service.settleCredit(
        's7',
        settledAt: DateTime(2026, 9, 12),
        disbursementTransactionId: 'tx-hand',
      );

      expect(
        service.activeCredits.single.disbursementTransactionId,
        'tx-hand',
      );
      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.creditId, 's7');
      expect(tx.creditLeg, CreditLeg.disbursement);
      // The hand-logged principal no longer inflates income.
      final summary = FinanceMath.summaryForMonth(
        FinanceService.instance.activeTransactions,
        DateTime(2026, 9, 12),
      );
      expect(summary.income, 0);
    });

    test('settleCredit never re-tags a leg owned by another credit',
        () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's8'));
      await FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'tx-other',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.other,
          title: 'Someone else\'s repayment',
          amount: 500,
          occurredAt: DateTime(2026, 9, 12),
          creditId: 'other-credit',
          creditLeg: CreditLeg.settlement,
        ),
      );

      await service.settleCredit(
        's8',
        settledAt: DateTime(2026, 9, 12),
        transactionId: 'tx-other',
      );

      expect(
        FinanceService.instance.activeTransactions.single.creditId,
        'other-credit',
      );
    });

    test('settleCredit is idempotent', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's4'));

      await service.settleCredit('s4', settledAt: DateTime(2026, 9, 12));
      await service.settleCredit('s4', settledAt: DateTime(2026, 9, 20));

      final e = service.activeCredits.single;
      expect(e.settledAt, DateTime(2026, 9, 12)); // first settle wins
    });

    test('addCreditWithDisbursement writes and links the principal',
        () async {
      final service = CreditService.instance;
      await service.init();
      final disbursement = FinanceTransaction(
        id: 'tx-principal',
        collectionId: 'personal',
        kind: FinanceKind.income,
        category: FinanceCategory.other,
        title: 'Borrowed from Ahmed',
        amount: 500,
        occurredAt: DateTime(2026, 9, 1),
        creditId: 'd1',
        creditLeg: CreditLeg.disbursement,
      );

      await service.addCreditWithDisbursement(
        _entry(id: 'd1'),
        disbursement: disbursement,
      );

      expect(
        service.activeCredits.single.disbursementTransactionId,
        'tx-principal',
      );
      final tx = FinanceService.instance.activeTransactions.single;
      expect(tx.id, 'tx-principal');
      expect(tx.creditLeg, CreditLeg.disbursement);
    });

    test('settlement survives a cold start', () async {
      final service = CreditService.instance;
      await service.init();
      await service.addCredit(_entry(id: 's5'));
      await service.settleCredit(
        's5',
        settledAt: DateTime(2026, 9, 12),
        transactionId: 'tx-5',
      );

      service.clearCache();
      await service.init();

      final e = service.activeCredits.single;
      expect(e.isSettled, isTrue);
      expect(e.settledAt, DateTime(2026, 9, 12));
      expect(e.settlementTransactionId, 'tx-5');
    });
  });
}
