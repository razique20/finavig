// Unified "Ask Finavig AI" sheet: routing + parsing through the real UI,
// over the full input matrix (typed input; voice driven via the service's
// @visibleForTesting debug hooks, so no platform recognizer is needed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/finance.dart';
import 'package:finavig/services/ai_intent_router_service.dart';
import 'package:finavig/services/document_scanner_service.dart';
import 'package:finavig/services/finance_service.dart';
import 'package:finavig/services/voice_input_service.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/dialogs/ask_finavig_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiIntentRouterService.groqEnabled = false; // hermetic: no Groq calls
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FinavigTheme.dark(), // home-matching dark/violet theme
        home: Scaffold(body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () => AskFinavigSheet.show(context),
              child: const Text('OPEN'),
            ),
          );
        })),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  Future<void> typeUtterance(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // >250ms debounce in the sheet.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('routing through the UI', () {
    testWidgets('money utterance shows the money confirmation card',
        (tester) async {
      await pumpSheet(tester);
      await typeUtterance(tester, 'Log DEWA bill of 450 AED');

      expect(find.text('Utilities'), findsOneWidget);
      expect(find.text('EXPENSE'), findsOneWidget);
      expect(find.text('Confirm & Save'), findsOneWidget);
    });

    testWidgets('document utterance shows the document card + alert ladder',
        (tester) async {
      await pumpSheet(tester);
      await typeUtterance(tester, 'Add Emirates ID expiring 14 Oct 2027');

      expect(find.textContaining('days left'), findsOneWidget);
      expect(find.textContaining('Expiry alerts scheduled'), findsOneWidget);
      expect(find.text('Confirm & Save'), findsOneWidget);
    });

    testWidgets('unclear utterance offers a manual flow choice',
        (tester) async {
      await pumpSheet(tester);
      await typeUtterance(tester, 'hello there');

      expect(find.text('Which one is it?'), findsOneWidget);
      expect(find.text('Money record'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
    });

    testWidgets('document-like utterance without money/date offers choice',
        (tester) async {
      await pumpSheet(tester);
      await typeUtterance(tester, 'my paperwork');
      expect(find.text('Which one is it?'), findsOneWidget);

      await tester.tap(find.text('Money record'));
      await tester.pumpAndSettle();

      // Manual override parses whatever is in the field.
      expect(find.text('Confirm & Save'), findsOneWidget);
    });

    testWidgets('document with no date still routes + warns', (tester) async {
      await pumpSheet(tester);
      await typeUtterance(tester, 'Add Emirates ID');

      expect(find.textContaining('days left'), findsOneWidget);
      // The doc parser defaults to +365 days; card must show it.
      expect(find.textContaining('Expiry:'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('money confirm does NOT persist — returns unpersisted result',
        (tester) async {
      FinanceService.instance; // touch singleton in local-only mode
      await pumpSheet(tester);
      await typeUtterance(tester, 'Log DEWA bill of 450 AED');

      await tester.tap(find.text('Confirm & Save'));
      await tester.pumpAndSettle();

      // Sheet closed, nothing written to FinanceService by the sheet itself.
      expect(FinanceService.instance.activeTransactions, isEmpty);
      expect(find.text('Ask Finavig AI'), findsNothing);
    });

    testWidgets('recurring utterance returns a recurring template too',
        (tester) async {
      AskFinavigResult? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: FinavigTheme.dark(),
          home: Scaffold(
            body: Builder(builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await AskFinavigSheet.show(context);
                  },
                  child: const Text('OPEN'),
                ),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await typeUtterance(tester, 'Office rent 15,000 AED recurring monthly');
      await tester.tap(find.text('Confirm & Save'));
      await tester.pumpAndSettle();

      expect(captured, isA<AskMoneyResult>());
      final money = captured! as AskMoneyResult;
      expect(money.recurringTemplate, isNotNull);
      expect(money.recurringTemplate!.frequency, RecurrenceFrequency.monthly);
      expect(money.transaction.title, isNotEmpty);
    });

    testWidgets('document confirm persists through DocumentScannerService',
        (tester) async {
      AskFinavigResult? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: FinavigTheme.dark(),
          home: Scaffold(
            body: Builder(builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await AskFinavigSheet.show(context);
                  },
                  child: const Text('OPEN'),
                ),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await typeUtterance(tester, 'Add Emirates ID expiring 14 Oct 2027');
      await tester.tap(find.text('Confirm & Save'));
      await tester.pumpAndSettle();

      expect(captured, isA<AskDocumentResult>());
      final doc = (captured! as AskDocumentResult).item;
      expect(doc.displayName, isNotEmpty);
      expect(doc.docType.displayName, contains('Emirates'));
      // Expiry alerts: item saved with a future expiry and reminder ladder.
      expect(doc.daysRemaining, greaterThan(0));
      expect(doc.expiresAt.year, 2027);

      final all = await DocumentScannerService.instance.getAllItems();
      expect(all.any((i) => i.id == doc.id), isTrue);
    });
  });

  group('voice plumbing', () {
    testWidgets('final transcript lands normalized in the field and routes',
        (tester) async {
      await pumpSheet(tester);

      // Simulate a finalized voice session: "four hundred fifty dirhams".
      VoiceInputService.instance.debugEmitTranscript(
        const VoiceUpdate(
          text: 'Log DEWA bill of four hundred fifty dirhams',
          partialText: '',
          isListening: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Log DEWA bill of 450 AED'),
        findsOneWidget,
      );
      expect(find.text('Utilities'), findsOneWidget);
    });

    testWidgets('partial transcript shows in the listening banner',
        (tester) async {
      await pumpSheet(tester);

      VoiceInputService.instance.debugEmitStatus(VoiceStatus.listening);
      VoiceInputService.instance.debugEmitTranscript(
        const VoiceUpdate(text: '', partialText: 'paid fifty', isListening: true),
      );
      await tester.pump(); // flush stream microtasks (listeners setState)
      await tester.pump(); // render the rebuilt banner

      // The banner shows the NORMALIZED partial: spoken numbers become digits.
      expect(find.textContaining('paid 50'), findsOneWidget);
    });
  });

  group('sample chips', () {
    testWidgets('tapping a chip fills and routes it', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Log DEWA bill of 450 AED'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Utilities'), findsOneWidget);
    });
  });
}
