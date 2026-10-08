import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/credit.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/router.dart';
import 'package:finavig/screens/money/money_sections.dart';
import 'package:finavig/services/collection_service.dart';
import 'package:finavig/services/credit_service.dart';
import 'package:finavig/services/demo_document_service.dart';
import 'package:finavig/services/document_scanner_service.dart';
import 'package:finavig/services/finance_service.dart';
import 'package:finavig/theme/app_theme.dart';

/// Tours the screens that changed with the credit book, the dark-brand
/// welcome/login flow and App Lock, dwelling on each one so the host can
/// capture live screenshots into `docs/screenshots/`.
///
/// Companion to `tool/capture_docs_shots.sh` (which syncs on the
/// `==SCREEN: NN_name==` markers) — the same pattern as the pitch tour in
/// `app_pitch_screenshots_test.dart`.
///
/// Every stop asserts its own anchor text before the marker is printed, so a
/// screenshot is never captured on a screen the tour didn't actually reach.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('docs tour: capture the new and updated screens', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', true);
    await prefs.setBool('hasSeenWelcome', true);
    // Keep the shots free of the first-run guide banner.
    await prefs.setBool('hasSeenAppGuide', true);

    // Exactly one demo licence (21 days out) so the Money renewal outlook is
    // populated. The stored vault survives across runs on the same simulator
    // and `addDemoDocument` mints a new id every call, so clear any demo
    // documents a previous tour left behind first — otherwise the shots
    // accumulate duplicate rows and double the renewal totals.
    await DemoDocumentService.instance.removeAll();
    await DemoDocumentService.instance.addDemoDocument();
    // Logged so the capture script (and CI) can prove the frame was taken with
    // a deterministic vault rather than an accumulating one.
    final trackedDocs = await DocumentScannerService.instance.getAllItems();
    debugPrint('==DOCS: ${trackedDocs.length}==');

    final collectionId = DocumentCollectionService.instance.activeCollectionId;

    Future<void> addTxn(
      FinanceKind kind,
      FinanceCategory category,
      String title,
      double amount,
      int daysAgo, {
      String? creditId,
      CreditLeg? creditLeg,
    }) {
      return FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'docs-${title.toLowerCase().replaceAll(' ', '-')}',
          collectionId: collectionId,
          kind: kind,
          category: category,
          title: title,
          amount: amount,
          currency: 'AED',
          occurredAt: DateTime.now().subtract(Duration(days: daysAgo)),
          creditId: creditId,
          creditLeg: creditLeg,
        ),
      );
    }

    // A live-looking month for the Money tab and the ledger.
    await addTxn(
      FinanceKind.income,
      FinanceCategory.sales,
      'Client retainer',
      18500,
      9,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.rent,
      'Warehouse rent',
      4200,
      8,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.salaries,
      'Team salaries',
      9600,
      7,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.suppliers,
      'Supplier restock',
      3100,
      5,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.utilities,
      'DEWA — August',
      940,
      4,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.transport,
      'Fleet fuel',
      640,
      3,
    );
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.renewals,
      'Trade licence renewal',
      2500,
      1,
    );

    // Credit book: an open borrowed loan (earliest deadline, so it sorts
    // first), an outstanding loan the user gave, and one already settled.
    final now = DateTime.now();
    await CreditService.instance.init();
    await CreditService.instance.addCredit(
      CreditEntry(
        id: 'credit-ahmed',
        collectionId: collectionId,
        direction: CreditDirection.borrowed,
        counterpartyName: 'Ahmed',
        counterpartyPhone: '+971 50 123 4567',
        amount: 900,
        currency: 'AED',
        description: 'For rent',
        startDate: now.subtract(const Duration(days: 6)),
        deadline: now.add(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    );
    await CreditService.instance.addCredit(
      CreditEntry(
        id: 'credit-bilal',
        collectionId: collectionId,
        direction: CreditDirection.lent,
        counterpartyName: 'Bilal',
        counterpartyPhone: '+971 55 987 6543',
        amount: 1500,
        currency: 'AED',
        description: 'Van deposit',
        startDate: now.subtract(const Duration(days: 3)),
        deadline: now.add(const Duration(days: 25)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    );
    await CreditService.instance.addCredit(
      CreditEntry(
        id: 'credit-ajmal',
        collectionId: collectionId,
        direction: CreditDirection.borrowed,
        counterpartyName: 'Ajmal',
        amount: 700,
        currency: 'AED',
        description: 'Car repair',
        startDate: now.subtract(const Duration(days: 40)),
        deadline: now.add(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 40)),
        settledAt: now.subtract(const Duration(days: 20)),
      ),
    );

    // A credit-linked repayment on top of the ledger, so Records shows the
    // "Credit" chip and the exclusion from the totals is visible.
    await addTxn(
      FinanceKind.expense,
      FinanceCategory.other,
      'Repaid Ahmed',
      900,
      0,
      creditId: 'credit-ahmed',
      creditLeg: CreditLeg.settlement,
    );

    // Real router + real theme, jumped straight past splash so the tour can't
    // be hijacked by the cold-start redirect.
    router.go('/welcome');
    await tester.pumpWidget(
      MaterialApp.router(
        theme: FinavigTheme.light(),
        darkTheme: FinavigTheme.dark(),
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    );

    // Fixed-step pumps settle the frame; the real wall-clock pause after gives
    // the host a wide window to capture mid-dwell without racing.
    Future<void> dwell() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(seconds: 6));
    }

    /// Asserts the anchor for this stop, announces it, then dwells.
    Future<void> stop(String name, String anchor) async {
      expect(
        find.textContaining(anchor),
        findsWidgets,
        reason: 'stop $name never rendered "$anchor"',
      );
      debugPrint('==SCREEN: $name==');
      await dwell();
    }

    Future<void> go(String route) async {
      router.go(route);
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // ── Welcome + login (recoloured to the dark brand theme) ──────────────
    await tester.pump(const Duration(milliseconds: 200));
    await stop('02-welcome', 'Continue to Login');

    await go('/login');
    await stop('04-login', 'What type of user are you?');

    // Sign-up path: pick "New to Finavig", then continue to the email step.
    await tester.tap(find.text('New to Finavig'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await stop('05-signup-form', "What's your email?");

    // ── The redesigned tabs: one light canvas per tab, ink accents, flat
    //    card-free ledgers. Anchors are the new sections' own labels, so a
    //    shot is only taken once the rebuilt layout is on screen.
    await go('/home');
    await stop('06-home', 'Categories');

    await go('/documents');
    await stop('08-documents', 'Tracked');

    await go('/profile');
    await stop('09-profile', 'Manage subscription');

    // ── Money: the collapsible sheet index, then Credit expanded ──────────
    await go('/money');
    await stop('07-money', 'Net this month');

    // Expand the Credit section in place. The page also carries a standalone
    // "Credit" shortcut that pushes the full Credit page, so target the
    // section header itself — the whole header row toggles its body.
    final creditHeader = find.ancestor(
      of: find.text('Credit'),
      matching: find.byType(SectionHeader),
    );
    expect(
      creditHeader,
      findsWidgets,
      reason: 'the Money sheet has no Credit section header',
    );
    await tester.ensureVisible(creditHeader.first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(creditHeader.first);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(creditHeader.first);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Still on Money (the header exists) with the section body expanded.
    expect(
      creditHeader,
      findsWidgets,
      reason: 'expanding Credit left the Money sheet',
    );
    await stop('34-money-credit', 'For rent');

    // ── Records: ledger with the credit-linked row and its chip ───────────
    await go('/records');
    await stop('13-records', 'Repaid Ahmed');

    // ── Credit book ──────────────────────────────────────────────────────
    await go('/credits');
    await stop('32-credits', 'Ahmed');

    // ── Settle sheet: the optional Money link side of a repayment ─────────
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Mark as repaid'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await stop('35-credit-settle', 'Only settle the credit');

    // ── App Lock: the passcode set-up screen (Profile → Security sheet) ───
    //    The rebuilt Settings lists it as a "Security & App Lock" row that
    //    opens a sheet, so the tour follows that path rather than the old
    //    inline section.
    await go('/profile');
    await tester.scrollUntilVisible(
      find.text('Security & App Lock'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Security & App Lock'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Set up App Lock'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await stop('33-app-lock', 'Create a passcode');

    debugPrint('==TOUR DONE==');
  });
}
