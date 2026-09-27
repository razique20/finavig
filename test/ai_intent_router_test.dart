import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/services/ai_intent_router_service.dart';

void main() {
  // Keep the suite hermetic — no network, ever.
  setUp(() {
    AiIntentRouterService.groqEnabled = false;
  });

  group('money inputs route to logMoney', () {
    const moneyInputs = [
      'Log DEWA bill of 450 AED',
      'Paid 450 AED for DEWA electricity yesterday',
      'spent 50 on coffee',
      'grocery shopping 250 dirhams',
      'Received 12,000 AED client payment from Acme',
      'Office rent 15,000 AED recurring monthly on 1st',
      'salary 25000',
      'Uber ride 34 AED today',
      'Etisalat bill 299',
      'Salik recharge 100',
      'DEWA 450', // bare biller + amount, no verb
    ];

    for (final input in moneyInputs) {
      test('"$input"', () {
        final r = AiIntentRouterService.instance.routeLocally(input);
        expect(r.intent, AskIntent.logMoney, reason: input);
        expect(r.source, AskRoutingSource.localKeywords);
        expect(r.confidence, greaterThan(0.5));
      });
    }
  });

  group('document inputs route to addDocument', () {
    const docInputs = [
      'Add Emirates ID expiring 14 Oct 2027',
      'Add my trade licence, expires 12 March 2027 cost 1500 AED',
      'Dubai Ejari contract expires in 60 days fee 2500 AED',
      'Visa renewal for John Doe expires 2026-11-15',
      'Vehicle Mulkiya expires next month cost 800 AED Abu Dhabi',
      'passport expires 05 Aug 2028',
      'renew my driving licence next year',
      'health insurance valid until Dec 2027',
      'trade license expiring soon',
      'labour card expires in 3 months',
    ];

    for (final input in docInputs) {
      test('"$input"', () {
        final r = AiIntentRouterService.instance.routeLocally(input);
        expect(r.intent, AskIntent.addDocument, reason: input);
      });
    }
  });

  group('missing-date documents are flagged', () {
    const noDateInputs = [
      'Add Emirates ID',
      'track my passport',
      'renew my trade licence',
    ];

    for (final input in noDateInputs) {
      test('"$input" → addDocument + missingDate', () {
        final r = AiIntentRouterService.instance.routeLocally(input);
        expect(r.intent, AskIntent.addDocument, reason: input);
        expect(r.missingDate, isTrue, reason: input);
        expect(r.note, isNotNull);
      });
    }
  });

  group('ambiguous / unclear inputs', () {
    test('empty input falls back', () {
      expect(
        AiIntentRouterService.instance.routeLocally(''),
        AskRouting.fallback,
      );
      expect(
        AiIntentRouterService.instance.routeLocally('   '),
        AskRouting.fallback,
      );
    });

    const unclearInputs = [
      'hello there',
      'what can you do',
      'help me',
      'thanks',
    ];

    for (final input in unclearInputs) {
      test('"$input" → unclear', () {
        final r = AiIntentRouterService.instance.routeLocally(input);
        expect(r.intent, AskIntent.unclear, reason: input);
      });
    }

    test('route() without Groq mirrors routeLocally for known flows',
        () async {
      final r = await AiIntentRouterService.instance.route(
        'Paid 450 AED for DEWA electricity yesterday',
      );
      expect(r.intent, AskIntent.logMoney);
      expect(r.source, AskRoutingSource.localKeywords);
    });

    test('route() without Groq returns fallback for unclear input',
        () async {
      final r = await AiIntentRouterService.instance.route('hello there');
      expect(r.intent, AskIntent.unclear);
      expect(r.source, AskRoutingSource.fallback);
    });
  });

  group('conflict cases: both lexicons match', () {
    test('amount without date → money', () {
      final r = AiIntentRouterService.instance.routeLocally(
        'Log DEWA bill of 450 AED for my visa renewal',
      );
      expect(r.intent, AskIntent.logMoney);
    });

    test('date without amount → document', () {
      // "pay" is a money word, "visa renewal" a document word; the expiry
      // date and the absence of any amount tip it to the document flow.
      final r = AiIntentRouterService.instance.routeLocally(
        'pay my visa renewal, expires 12 oct 2027',
      );
      expect(r.intent, AskIntent.addDocument);
      // Sanity: the date branch fired, not the both-signals default.
      expect(r.confidence, 0.8);
    });

    test('both amount and date → money (safer to have logged the expense)',
        () {
      final r = AiIntentRouterService.instance.routeLocally(
        'pay the 500 AED insurance renewal fee, expires 12 oct',
      );
      expect(r.intent, AskIntent.logMoney);
      expect(r.confidence, 0.6);
    });
  });

  group('token-consumption guards (offline, no network)', () {
    setUp(() {
      AiIntentRouterService.instance.resetSession();
    });

    tearDown(() {
      AiIntentRouterService.groqEnabled = false;
      AiIntentRouterService.escalationOverride = null;
      AiIntentRouterService.instance.resetSession();
    });

    test('identical utterance escalates once — memo replays the verdict',
        () async {
      AiIntentRouterService.groqEnabled = true;
      var calls = 0;
      AiIntentRouterService.escalationOverride = (_) async {
        calls++;
        return '{"intent":"ADD_DOCUMENT","confidence":0.8,"reason":"doc add"}';
      };
      const input = 'gibberish ambiguous thing here';

      final first = await AiIntentRouterService.instance.route(input);
      final second = await AiIntentRouterService.instance.route(input);

      expect(calls, 1, reason: 'second identical call must hit the memo');
      expect(first.source, AskRoutingSource.groq);
      expect(second.source, AskRoutingSource.groq);
      expect(second.confidence, first.confidence);
    });

    test('session budget caps escalations and degrades gracefully', () async {
      AiIntentRouterService.groqEnabled = true;
      var calls = 0;
      AiIntentRouterService.escalationOverride = (_) async {
        calls++;
        return '{"intent":"UNCLEAR","confidence":0.4}';
      };

      for (var i = 0; i < AiIntentRouterService.maxEscalationsPerSession; i++) {
        final r = await AiIntentRouterService.instance.route('unclear $i');
        expect(r.source, AskRoutingSource.groq);
      }
      expect(calls, AiIntentRouterService.maxEscalationsPerSession);

      // Budget spent — the next ambiguous input must NOT escalate. It
      // resolves instantly with the pause note instead.
      final capped = await AiIntentRouterService.instance.route('unclear after cap');
      expect(calls, AiIntentRouterService.maxEscalationsPerSession,
          reason: 'no escalation past the budget');
      expect(capped.source, AskRoutingSource.fallback);
      expect(capped.note, contains('paused'));
    });

    test('known flows never count against the budget', () async {
      AiIntentRouterService.groqEnabled = true;
      var calls = 0;
      AiIntentRouterService.escalationOverride = (_) async {
        calls++;
        return '{"intent":"UNCLEAR","confidence":0.4}';
      };

      final r = await AiIntentRouterService.instance
          .route('Log DEWA bill of 450 AED');
      expect(r.source, AskRoutingSource.localKeywords);
      expect(calls, 0, reason: 'lexicon verdicts never hit the network');
    });

    test('long input is trimmed before it reaches the model', () async {
      AiIntentRouterService.groqEnabled = true;
      String? received;
      AiIntentRouterService.escalationOverride = (input) async {
        received = input;
        return '{"intent":"UNCLEAR","confidence":0.4}';
      };

      final longText = 'unclear ${'x' * 500}';
      await AiIntentRouterService.instance.route(longText);

      expect(received, isNotNull);
      // _maxUserInputChars: routing only needs intent signals, so the payload
      // is capped at 160 characters regardless of input length.
      expect(received!.length, 160);
    });
  });

  group('Groq JSON parsing (offline, no network)', () {
    test('parses a clean LOG_MONEY reply', () {
      final r = AiIntentRouterService.instance.parseGroqRouting(
        '{"intent":"LOG_MONEY","confidence":0.93,"reason":"expense with amount"}',
        userInput: 'paid 40 for shawarma',
      );
      expect(r, isNotNull);
      expect(r!.intent, AskIntent.logMoney);
      expect(r.source, AskRoutingSource.groq);
      expect(r.confidence, closeTo(0.93, 0.001));
    });

    test('parses ADD_DOCUMENT and re-checks missing date on user input', () {
      final r = AiIntentRouterService.instance.parseGroqRouting(
        '{"intent":"ADD_DOCUMENT","confidence":0.88,"reason":"no date given"}',
        userInput: 'Add Emirates ID',
      );
      expect(r!.intent, AskIntent.addDocument);
      expect(r.missingDate, isTrue);
    });

    test('ADD_DOCUMENT with date in user input is not flagged', () {
      final r = AiIntentRouterService.instance.parseGroqRouting(
        '{"intent":"ADD_DOCUMENT","confidence":0.88,"reason":"document add"}',
        userInput: 'Add Emirates ID expiring 14 Oct 2027',
      );
      expect(r!.missingDate, isFalse);
    });

    test('strips markdown fences and prose around JSON', () {
      final r = AiIntentRouterService.instance.parseGroqRouting(
        'Here you go:\n```json\n{"intent":"LOG_MONEY","confidence":0.7}\n```\nDone.',
        userInput: 'x',
      );
      expect(r!.intent, AskIntent.logMoney);
    });

    test('returns null for garbage', () {
      expect(
        AiIntentRouterService.instance.parseGroqRouting('not json at all'),
        isNull,
      );
      expect(
        AiIntentRouterService.instance.parseGroqRouting('{"intent":"WEIRD"}'),
        isNull,
      );
      expect(
        AiIntentRouterService.instance.parseGroqRouting(''),
        isNull,
      );
    });

    test('unknown intent label returns null', () {
      expect(
        AiIntentRouterService.instance.parseGroqRouting(
          '{"intent":"DELETE_EVERYTHING","confidence":0.9}',
        ),
        isNull,
      );
    });
  });
}
