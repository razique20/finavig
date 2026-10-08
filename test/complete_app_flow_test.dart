// Complete app flow + UI flow coverage.
//
// Two layers, one file:
//  1. "Complete user flows" walks the real router the way a user does —
//     bottom-nav tabs, document lifecycle, money lifecycle, every full-screen
//     route, and the settings surface — asserting the screen that actually
//     appears at each step.
//  2. "UI flow — screen by screen" mounts every routed screen directly and
//     guards its primary UI contract (heading + key controls + no exceptions).
//
// The app is fully usable offline/signed-out (local-only mode), so Supabase is
// absent in tests and the auth gate is off, exactly like the existing widget
// tests in test/.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/finance.dart';
import 'package:finavig/models/gcc_country.dart';
import 'package:finavig/router.dart';
import 'package:finavig/screens/ai_budget_plan_screen.dart';
import 'package:finavig/screens/ai_summary_screen.dart';
import 'package:finavig/screens/alerts_reminders_screen.dart';
import 'package:finavig/screens/budgets_screen.dart';
import 'package:finavig/screens/cash_flow_forecast_screen.dart';
import 'package:finavig/screens/document_scan_screen.dart';
import 'package:finavig/screens/documents_screen.dart';
import 'package:finavig/screens/envelopes_screen.dart';
import 'package:finavig/screens/expiry_list_screen.dart';
import 'package:finavig/screens/global_search_screen.dart';
import 'package:finavig/screens/home_screen.dart';
import 'package:finavig/screens/login_screen.dart';
import 'package:finavig/screens/money_screen.dart';
import 'package:finavig/screens/profile_screen.dart';
import 'package:finavig/screens/records_screen.dart';
import 'package:finavig/screens/welcome_screen.dart';
import 'package:finavig/widgets/finavig_wordmark.dart';
import 'package:finavig/services/demo_document_service.dart';
import 'package:finavig/services/document_scanner_service.dart';
import 'package:finavig/services/finance_service.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'hasOnboarded': true,
      'hasSeenWelcome': true,
      'hasSeenAppGuide': true,
    });
    // Singletons cache data across tests — clear so seeded state is isolated.
    DocumentScannerService.instance.clearCache();
    FinanceService.instance.clearCache();
  });

  /// Mounts the real app router and lands on [route], letting the splash
  /// animation (1.8s) and its navigation future fully elapse first.
  Future<void> pumpAt(WidgetTester tester, String route) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2)); // splash settles
    router.go(route);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> go(WidgetTester tester, String route) async {
    router.go(route);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> addTx(
    FinanceKind kind,
    FinanceCategory category,
    String title,
    double amount,
  ) {
    return FinanceService.instance.addTransaction(
      FinanceTransaction(
        id: 'flow-${title.toLowerCase().replaceAll(' ', '-')}',
        collectionId: 'personal',
        kind: kind,
        category: category,
        title: title,
        amount: amount,
        currency: 'AED',
        occurredAt: DateTime.now(),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 1. Complete user flows through the real router
  // ────────────────────────────────────────────────────────────────────────
  group('Complete user flows', () {
    testWidgets('bottom-nav round-trip visits all four tabs', (tester) async {
      await pumpAt(tester, '/home');
      expect(find.text('Net this month'), findsOneWidget); // Home dashboard

      await tester.tap(find.byTooltip('Money'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Money'), findsWidgets);

      await tester.tap(find.byTooltip('Documents'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Documents'), findsWidgets);
      expect(find.textContaining('tracked'), findsWidgets);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Settings'), findsWidgets);

      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Net this month'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'document lifecycle: seed → listed in vault → open detail → renew',
      (tester) async {
        // A document created by the scanner lands in the local vault.
        final demo = await DemoDocumentService.instance.addDemoDocument();
        expect(demo.displayName, contains('Demo: '));

        await pumpAt(tester, '/documents');
        // The vault lists the tracked document (and its demo affordance).
        expect(find.textContaining('Sample Trade Licence'), findsWidgets);

        // Opening a document goes through the deep-link route the notification
        // tap service uses.
        await go(tester, '/document/${demo.id}');
        expect(find.text(demo.displayName), findsWidgets);

        // The renew action is offered from the detail screen's overflow menu.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Mark as renewed'), findsWidgets);

        // Cancel out of the popup without mutating the document.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'money lifecycle: log income + expense into records and money',
      (tester) async {
        await addTx(
          FinanceKind.income,
          FinanceCategory.sales,
          'Client retainer',
          18500,
        );
        await addTx(
          FinanceKind.expense,
          FinanceCategory.rent,
          'Warehouse rent',
          4200,
        );
        await addTx(
          FinanceKind.expense,
          FinanceCategory.transport,
          'Fleet fuel',
          640,
        );

        await pumpAt(tester, '/money');
        expect(find.text('Net this month'), findsOneWidget);

        // The ledger shows the logged line items.
        await go(tester, '/records');
        expect(find.text('Records'), findsWidgets);
        expect(find.text('Client retainer'), findsWidgets);
        expect(find.text('Warehouse rent'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('budget + envelope flows surface their created items', (
      tester,
    ) async {
      await FinanceService.instance.upsertBudget(FinanceCategory.rent, 5000);
      await FinanceService.instance.addEnvelope('New Laptop', 6000, 500);

      await pumpAt(tester, '/budgets');
      expect(find.text('Budgets'), findsWidgets);
      expect(find.textContaining('Rent'), findsWidgets);

      await go(tester, '/envelopes');
      expect(find.text('Savings envelopes'), findsWidgets);
      expect(find.text('New Laptop'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every full-screen route resolves to its heading', (
      tester,
    ) async {
      await pumpAt(tester, '/home');

      const routes = <String, String>{
        '/expiry-list': 'Upcoming Expiries',
        '/cash-flow-forecast': '90-Day Cash-Flow Forecast',
        '/ai-summary': 'AI Executive Summary',
        '/ai-budget-plan': 'AI Budget Planner',
        '/alerts-reminders': 'Alerts & Reminders',
        '/search': 'Search all your documents',
      };

      for (final entry in routes.entries) {
        await go(tester, entry.key);
        expect(
          find.text(entry.value),
          findsWidgets,
          reason: 'route ${entry.key} should show "${entry.value}"',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'route ${entry.key} threw during build',
        );
      }
    });

    testWidgets('settings surface exposes the core sections', (tester) async {
      await pumpAt(tester, '/profile');
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Manage profile'), findsWidgets);
      expect(find.text('Manage subscription'), findsWidgets);
      expect(find.text('My Collections'), findsWidgets);
      expect(find.text('Manage notifications'), findsWidgets);
      expect(find.text('AI Summary'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quick action sheet opens from the shell (+) orb', (
      tester,
    ) async {
      await pumpAt(tester, '/home');

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      // The 1-tap menu offers every core creation flow.
      expect(find.textContaining('document'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quick action orb (+) is flat — no shadow around it', (
      tester,
    ) async {
      await pumpAt(tester, '/home');

      // The orb is the only tooltip-badged widget in the nav pill, so locate it
      // by its tooltip rather than by icon position in the tree.
      final orbTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Quick actions'),
      );
      expect(orbTooltip, findsOneWidget);

      final orbContainers = find.descendant(
        of: orbTooltip,
        matching: find.byType(Container),
      );
      expect(orbContainers, findsWidgets);

      var gradientCircles = 0;
      for (final element in orbContainers.evaluate()) {
        final decoration = (element.widget as Container).decoration;
        if (decoration is! BoxDecoration) continue;
        expect(
          decoration.boxShadow,
          isNull,
          reason: 'the + orb must not draw a shadow',
        );
        final gradient = decoration.gradient;
        if (gradient is LinearGradient) {
          gradientCircles++;
          // The orb is the brand ink plate, not the old violet accent.
          expect(gradient.colors, [
            FinavigColors.ink,
            FinavigColors.inkDeep,
          ], reason: 'the + orb must wear the dark brand ink');
        }
      }
      // The (now ink) gradient circle stays; only its shadow was removed.
      expect(gradientCircles, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bottom nav marks the active tab with its glyph, not a plate', (
      tester,
    ) async {
      await pumpAt(tester, '/home');

      // Locate the dock's Home destination by its tooltip: `home_rounded` also
      // appears in category lists, so the icon alone is ambiguous here.
      final homeTab = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Home',
      );
      expect(homeTab, findsOneWidget);

      // Home is the active branch, so its filled glyph is the brand ink.
      final glyph = tester.widget<Icon>(
        find.descendant(of: homeTab, matching: find.byType(Icon)).first,
      );
      expect(
        glyph.color,
        FinavigColors.ink,
        reason: 'the active tab glyph carries the selection colour',
      );

      // …and nothing draws a circular selection backdrop behind it.
      expect(
        find.descendant(
          of: homeTab,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsNothing,
        reason: 'the dock selects with the glyph, not a circle',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // 2. UI flow — screen by screen
  // ────────────────────────────────────────────────────────────────────────
  group('UI flow — screen by screen', () {
    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('WelcomeScreen shows brand and CTA', (tester) async {
      await pumpScreen(tester, const WelcomeScreen());
      // Dotless "i": the brand-blue dot is drawn over the gap.
      expect(find.text(FinavigWordmark.dotlessText), findsOneWidget);
      expect(find.byKey(FinavigWordmark.dotKey), findsOneWidget);
      expect(
        find.text(
          'Do not save what is left after spending; '
          'spend what is left after saving.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Continue to Login'),
        findsOneWidget,
      );
    });

    testWidgets('LoginScreen shows the user-type quiz', (tester) async {
      await pumpScreen(tester, const LoginScreen());

      // The header pill shows all six GCC flags instead of a "GCC Edition"
      // label — one bundled asset each, so it renders the same everywhere.
      expect(find.text('GCC Edition'), findsNothing);
      for (final country in GccCountry.values) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == country.flagAsset,
          ),
          findsOneWidget,
          reason: '${country.displayName} flag missing from the header pill',
        );
      }

      expect(find.text('What type of user are you?'), findsWidgets);
      expect(find.text('New to Finavig'), findsWidgets);
      expect(find.text('Already a member?'), findsWidgets);
      expect(find.text('Continue'), findsWidgets);

      // Every description line and the security cue wear the brand blue.
      for (final label in const [
        'Tap once to choose — double-tap to continue.',
        'Create a free account',
        'Sign in to your account',
        'Secure sign-in — your data stays private',
      ]) {
        expect(
          tester.widget<Text>(find.text(label)).style?.color,
          FinavigColors.accent,
          reason: '"$label" must carry the brand blue',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeScreen shows hero and categories grid', (tester) async {
      await pumpScreen(tester, const HomeScreen());
      expect(find.text('Net this month'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Record'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DocumentsScreen shows hero header and search', (tester) async {
      await pumpScreen(tester, const DocumentsScreen());
      expect(find.text('Documents'), findsWidgets);
      expect(find.text('Search documents…'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MoneyScreen shows summary and action tiles', (tester) async {
      await pumpScreen(tester, const MoneyScreen());
      expect(find.text('Money'), findsWidgets);
      expect(find.text('Net this month'), findsOneWidget);
      expect(find.text('Add Record'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen shows settings sections', (tester) async {
      await pumpScreen(tester, const ProfileScreen());
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Manage subscription'), findsWidgets);
      expect(find.text('My Collections'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BudgetsScreen renders header and add action', (tester) async {
      await pumpScreen(tester, const BudgetsScreen());
      expect(find.text('Budgets'), findsWidgets);
      expect(find.text('Add category'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EnvelopesScreen renders header and new-envelope action', (
      tester,
    ) async {
      await pumpScreen(tester, const EnvelopesScreen());
      expect(find.text('Savings envelopes'), findsWidgets);
      expect(find.text('New envelope'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecordsScreen renders header', (tester) async {
      await pumpScreen(tester, const RecordsScreen());
      expect(find.text('Records'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlobalSearchScreen shows the empty-state prompt', (
      tester,
    ) async {
      await pumpScreen(tester, const GlobalSearchScreen());
      expect(find.text('Search all your documents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExpiryListScreen renders header', (tester) async {
      await pumpScreen(tester, const ExpiryListScreen());
      expect(find.text('Upcoming Expiries'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CashFlowForecastScreen renders header and filters', (
      tester,
    ) async {
      await pumpScreen(tester, const CashFlowForecastScreen());
      expect(find.text('90-Day Cash-Flow Forecast'), findsWidgets);
      expect(find.text('All Events'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AiSummaryScreen renders header', (tester) async {
      await pumpScreen(tester, const AiSummaryScreen());
      expect(find.text('AI Executive Summary'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AiBudgetPlanScreen renders header', (tester) async {
      await pumpScreen(tester, const AiBudgetPlanScreen());
      expect(find.text('AI Budget Planner'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AlertsRemindersScreen renders notification switches', (
      tester,
    ) async {
      await pumpScreen(tester, const AlertsRemindersScreen());
      expect(find.text('Alerts & Reminders'), findsWidgets);
      expect(find.text('Renewal notifications'), findsWidgets);
      expect(find.text('Budget alerts'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DocumentScanScreen renders the upload form', (tester) async {
      await pumpScreen(tester, const DocumentScanScreen());
      expect(find.text('Upload document'), findsWidgets);
      expect(find.text('Document Title *'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
