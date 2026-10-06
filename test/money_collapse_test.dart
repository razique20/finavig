// Money tab section collapsing: every section in the light sheet
// minimizes to its header (chevron) and expands on demand.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/screens/money/money_sections.dart';
import 'package:finavig/screens/money_screen.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/cards/monthly_summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpMoney(WidgetTester tester) async {
    // Tall viewport: the sheet is long, and these tests tap
    // sections deep in the list, which must be on-screen to
    // receive the tap (the default 800x600 window cannot).
    tester.view.physicalSize = const Size(1179, 12000);
    tester.view.devicePixelRatio = 3.0; // logical ≈ 393 x 4000
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: FinavigTheme.light(), home: const MoneyScreen()),
    );
    await tester.pump(); // finance init
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('every section header carries a minimize chevron', (
    tester,
  ) async {
    await pumpMoney(tester);

    // Headers stay visible — they are the collapse controls now.
    // Matched through SectionHeader so the hero pills ("Budgets",
    // "Envelopes", "Transactions") and the Credit shortcut card
    // (also titled "Credit") don't collide with section headers.
    for (final header in [
      'Monthly budgets',
      'Last 6 weeks',
      'Where money goes',
      'Biggest expenses',
      'Recurring',
      'Savings envelopes',
      'Credit',
      'Transactions',
    ]) {
      expect(find.widgetWithText(SectionHeader, header), findsOneWidget);
    }

    // The cash-flow forecast rolls its own header row.
    expect(find.text('Cash-Flow Forecast'), findsOneWidget);

    // The 90-day renewal outlook section was removed from the sheet.
    expect(find.text('90-Day Renewal Outlook'), findsNothing);

    // One chevron per collapsible section — the renewal breakdown
    // hides itself entirely when nothing is upcoming, and the
    // cash-flow forecast is a plain tap-through card (no chevron).
    expect(find.byType(SectionCollapseChevron), findsNWidgets(9));
  });

  testWidgets('sections read top to bottom in a logical order', (tester) async {
    await pumpMoney(tester);

    // At a glance → budgets → spending analysis → planning & history.
    // The two "Credit" entries are told apart by their unique text:
    // the shortcut card by its subtitle, the section by its header.
    final order = <String, Finder>{
      'Executive Summary': find.text('Executive Summary'),
      'Cash-Flow Forecast': find.text('Cash-Flow Forecast'),
      'Credit shortcut': find.text('Borrowed, lent & deadlines'),
      'Spending pace': find.textContaining('Spending pace'),
      'Monthly budgets': find.text('Monthly budgets'),
      'Last 6 weeks': find.text('Last 6 weeks'),
      'Where money goes': find.text('Where money goes'),
      'Biggest expenses': find.text('Biggest expenses'),
      'Recurring': find.text('Recurring'),
      'Savings envelopes': find.text('Savings envelopes'),
      'Credit': find.widgetWithText(SectionHeader, 'Credit'),
      'Transactions': find.widgetWithText(SectionHeader, 'Transactions'),
    };

    var previous = double.negativeInfinity;
    for (final entry in order.entries) {
      expect(entry.value, findsOneWidget, reason: entry.key);
      final dy = tester.getTopLeft(entry.value).dy;
      expect(
        dy,
        greaterThan(previous),
        reason: '${entry.key} should sit below the section before it',
      );
      previous = dy;
    }
  });

  testWidgets('at-a-glance cards stack flush with no gap between them', (
    tester,
  ) async {
    await pumpMoney(tester);

    // Empty data hides the renewals breakdown, so Executive Summary,
    // Cash-Flow Forecast and the Credit shortcut sit edge to edge.
    // Measured on the cards' Material surfaces — a Card's margin sits
    // outside them, so this catches a stray margin as well as a spacer.
    final summary = tester.getRect(
      find
          .descendant(
            of: find.byType(MonthlySummaryCard),
            matching: find.byType(Material),
          )
          .first,
    );
    final cashFlow = tester.getRect(
      find
          .descendant(
            of: find.widgetWithText(Card, 'Cash-Flow Forecast'),
            matching: find.byType(Material),
          )
          .first,
    );
    final credit = tester.getRect(
      find
          .ancestor(
            of: find.text('Borrowed, lent & deadlines'),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(cashFlow.top - summary.bottom, closeTo(0, 0.01));
    expect(credit.top - cashFlow.bottom, closeTo(0, 0.01));
  });

  testWidgets('spending pace chevron lines up with the other sections', (
    tester,
  ) async {
    await pumpMoney(tester);

    // The pace header used to sit inside its tinted card, which pushed
    // its chevron in from the gutter every other section uses.
    final paceChevron = find.descendant(
      of: find
          .ancestor(
            of: find.textContaining('Spending pace'),
            matching: find.byType(InkWell),
          )
          .first,
      matching: find.byType(SectionCollapseChevron),
    );
    final budgetsChevron = find.descendant(
      of: find.widgetWithText(SectionHeader, 'Monthly budgets'),
      matching: find.byType(SectionCollapseChevron),
    );

    expect(
      tester.getRect(paceChevron).right,
      closeTo(tester.getRect(budgetsChevron).right, 0.01),
    );
  });

  testWidgets('tapping a section header expands and re-minimizes it', (
    tester,
  ) async {
    await pumpMoney(tester);

    const recordsHint = 'No records yet. Add your first expense or income.';
    // Minimized by default: header only, body hidden.
    expect(find.text(recordsHint), findsNothing);

    // Expand Transactions from its header (not the hero pill).
    await tester.tap(find.widgetWithText(SectionHeader, 'Transactions'));
    await tester.pumpAndSettle();

    // Header remains, body is back.
    expect(find.widgetWithText(SectionHeader, 'Transactions'), findsOneWidget);
    expect(find.text(recordsHint), findsOneWidget);

    // Minimizing hides the body again.
    await tester.tap(find.widgetWithText(SectionHeader, 'Transactions'));
    await tester.pumpAndSettle();
    expect(find.text(recordsHint), findsNothing);
  });

  testWidgets('budgets section expands from its header too', (tester) async {
    await pumpMoney(tester);

    const budgetHint =
        'Set a monthly limit for any category to see progress here.';
    expect(find.text(budgetHint), findsNothing);

    // Tap the chevron, not the header's center — the
    // 'Add category' action button sits at the row's
    // trailing edge and wins the gesture arena there.
    final budgetsChevron = find.descendant(
      of: find.widgetWithText(SectionHeader, 'Monthly budgets'),
      matching: find.byType(SectionCollapseChevron),
    );
    await tester.tap(budgetsChevron);
    await tester.pumpAndSettle();
    expect(find.text(budgetHint), findsOneWidget);
    expect(find.text('Monthly budgets'), findsOneWidget);

    await tester.tap(budgetsChevron);
    await tester.pumpAndSettle();
    expect(find.text(budgetHint), findsNothing);
  });

  testWidgets('cash-flow forecast is a bare tap-through card', (tester) async {
    await pumpMoney(tester);

    // The forecast has its own page, so the card carries no detail of
    // its own and no collapse chevron — just the tappable strip.
    expect(
      find.text('Plus feature — project your balance 90 days ahead'),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(Card, 'Cash-Flow Forecast'),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(Card, 'Cash-Flow Forecast'),
        matching: find.byType(SectionCollapseChevron),
      ),
      findsNothing,
    );

    // Tapping the strip still routes: Free tier gets the upsell.
    await tester.tap(find.text('Cash-Flow Forecast'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('credit shortcut carries no arrow icon', (tester) async {
    await pumpMoney(tester);

    // The credit shortcut's decorative right-arrow is gone; the card
    // itself stays tappable through its own InkWell.
    final creditRow = find
        .ancestor(
          of: find.text('Borrowed, lent & deadlines'),
          matching: find.byType(Row),
        )
        .first;
    expect(
      find.descendant(
        of: creditRow,
        matching: find.byIcon(Icons.arrow_forward_ios_rounded),
      ),
      findsNothing,
    );
  });
}
