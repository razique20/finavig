import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/finance.dart';
import 'package:finavig/router.dart';
import 'package:finavig/services/demo_document_service.dart';
import 'package:finavig/services/collection_service.dart';
import 'package:finavig/services/finance_service.dart';

/// Tours the real app through every headline screen on the simulator and
/// dwells on each one so the host can capture live screenshots for the
/// pitch deck (assembled by tool/build_pitch_pdf.dart).
///
/// The tour starts directly on /home (skipping splash/auth routing) with
/// onboarding flags pre-set, seeds one demo document and a small month of
/// transactions so every screen shows meaningful content.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pitch tour: capture all app screens', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', true);
    await prefs.setBool('hasSeenWelcome', true);
    // Keep the pitch screenshots free of the first-run guide banner.
    await prefs.setBool('hasSeenAppGuide', true);

    // One demo trade licence expiring in 21 days (inside the urgency band).
    final demo = (await DemoDocumentService.instance.addDemoDocument()).id;

    // A small month of activity so the Money/Budget screens look alive.
    final collectionId = DocumentCollectionService.instance.activeCollectionId;
    Future<void> add(FinanceKind kind, FinanceCategory category,
        String title, double amount, int daysAgo) {
      return FinanceService.instance.addTransaction(
        FinanceTransaction(
          id: 'pitch-${title.toLowerCase().replaceAll(' ', '-')}',
          collectionId: collectionId,
          kind: kind,
          category: category,
          title: title,
          amount: amount,
          currency: 'AED',
          occurredAt: DateTime.now().subtract(Duration(days: daysAgo)),
        ),
      );
    }

    await add(FinanceKind.income, FinanceCategory.sales, 'Client retainer',
        18500, 9);
    await add(
        FinanceKind.expense, FinanceCategory.rent, 'Warehouse rent', 4200, 8);
    await add(FinanceKind.expense, FinanceCategory.salaries, 'Team salaries',
        9600, 7);
    await add(FinanceKind.expense, FinanceCategory.suppliers,
        'Supplier restock', 3100, 5);
    await add(FinanceKind.expense, FinanceCategory.transport, 'Fleet fuel',
        640, 3);
    await add(FinanceKind.expense, FinanceCategory.foodAndBeverages,
        'Team lunch', 260, 2);
    await add(FinanceKind.expense, FinanceCategory.renewals,
        'Trade licence renewal', 2500, 1);

    // Real app, real router — but jump straight to Home so the splash's
    // auth redirect can't hijack the tour.
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Fixed-step pumps settle the screen; the real wall-clock pause after
    // gives the host a wide window to capture mid-dwell without racing.
    Future<void> dwell() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(seconds: 6));
    }

    Future<void> stop(String route, String name) async {
      debugPrint('==SCREEN: $name==');
      router.go(route);
      await dwell();
    }

    // ── Tab roots ────────────────────────────────────────────────────────
    debugPrint('==SCREEN: 01_home==');
    await dwell();

    await stop('/documents', '02_documents');
    await stop('/money', '03_money');

    // ── Document flows ───────────────────────────────────────────────────
    await stop('/document/$demo', '04_document_detail');
    await stop('/expiry-list', '05_expiry_list');
    await stop('/search', '06_global_search');

    // ── Money flows ──────────────────────────────────────────────────────
    await stop('/budgets', '07_budgets');
    await stop('/envelopes', '08_envelopes');
    await stop('/records', '09_records');
    await stop('/cash-flow-forecast', '10_cash_flow');

    // ── AI ───────────────────────────────────────────────────────────────
    await stop('/ai-summary', '11_ai_summary');
    await stop('/ai-budget-plan', '12_ai_budget_plan');

    // ── Account ──────────────────────────────────────────────────────────
    await stop('/profile', '13_profile');
    await stop('/alerts-reminders', '14_alerts');

    debugPrint('==TOUR DONE==');
  });
}
