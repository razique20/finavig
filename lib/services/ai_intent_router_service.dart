import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'groq_api_service.dart';

/// Which flow the user's freeform request should land in.
enum AskIntent { logMoney, addDocument, unclear }

/// What the intent router decided for a freeform input.
class AskRouting {
  /// Flow to open.
  final AskIntent intent;

  /// Confidence 0..1 (1.0 for the local keyword path, from the model otherwise).
  final double confidence;

  /// Where the decision came from — surfaced in the sheet + tests.
  final AskRoutingSource source;

  /// Optional one-line human explanation ("Sounds like an expense — DEWA is
  /// a utility bill"). Null when the router has nothing useful to add.
  final String? note;

  /// True when the input clearly names something to track (document keywords)
  /// but carries no date at all — the money parser would log a wrong record
  /// from it, so the sheet should show a hint instead of saving.
  final bool missingDate;

  const AskRouting({
    required this.intent,
    required this.confidence,
    required this.source,
    this.note,
    this.missingDate = false,
  });

  /// Safe default when no signal at all: ask the user which flow they want.
  static const AskRouting fallback = AskRouting(
    intent: AskIntent.unclear,
    confidence: 0,
    source: AskRoutingSource.fallback,
  );

  @override
  String toString() =>
      'AskRouting(${intent.name}, ${(confidence * 100).toStringAsFixed(0)}%, '
      '${source.name}${note == null ? '' : ', note: "$note"'})';
}

/// Where a routing decision came from.
enum AskRoutingSource {
  /// Local keyword/lexicon decision (offline, instant, testable).
  localKeywords,

  /// Groq AI classified the input.
  groq,

  /// No signal — caller should ask the user.
  fallback,
}

/// Universal intent router for the "Ask Finavig AI" sheet.
///
/// Given one freeform utterance ("Log DEWA bill of 450 AED", "Add Emirates ID
/// expiring 14 Oct 2027") it decides whether the request is a money flow, a
/// document flow, or unclear.
///
/// **Local-first, AI-assist:** a deterministic lexicon decides instantly and
/// for free — it confidently resolves the overwhelming majority of real
/// utterances, so no tokens are spent. Groq is only escalated for the
/// ambiguous remainder (when the lexicon returns [AskIntent.unclear]), and if
/// Groq is unreachable the sheet falls back to asking the user. The feature
/// never hard-fails and token usage stays near zero.
class AiIntentRouterService {
  AiIntentRouterService._();

  static final AiIntentRouterService instance = AiIntentRouterService._();

  /// When false, [route] never escalates to Groq — it resolves with the local
  /// lexicon alone and returns [AskRouting.fallback] for anything the lexicon
  /// can't classify. Widget tests flip this off so the suite stays hermetic.
  static bool groqEnabled = true;

  /// Test/preview seam: when non-null, [route] calls this instead of the Groq
  /// HTTP client. Lets the suite exercise the escalation path (memo, budget,
  /// JSON parsing end-to-end) with zero network and zero token spend.
  @visibleForTesting
  static Future<String> Function(String userInput)? escalationOverride;

  // --------------------------------------------------------------------------
  // Token-consumption guards
  // --------------------------------------------------------------------------

  /// How many Groq escalations a rolling day may spend before the router
  /// stops asking the network and resolves locally — shared across every
  /// AI entry point (Ask Finavig sheet, money form, document form), not
  /// just one sheet session. The lexicon already resolves the overwhelming
  /// majority of inputs, so this only caps a pathological burst, and one
  /// utterance never costs more than one request thanks to the memo.
  static const int maxEscalationsPerDay = 12;

  /// Kept as an alias for older call sites/tests.
  @Deprecated('Renamed to maxEscalationsPerDay — the budget is now daily')
  static const int maxEscalationsPerSession = maxEscalationsPerDay;

  static const String _budgetPrefsKey = 'ai.router.budget.v1';
  static const String _memoPrefsKey = 'ai.router.memo.v1';

  /// In-memory mirrored escalation count for today. Loaded from prefs on
  /// first use; persisted on every increment so app restarts keep the
  /// budget honest.
  int _escalationsToday = 0;

  /// Local midnight of the day the current [_escalationsToday] count belongs
  /// to. A different day resets the counter to zero.
  DateTime? _budgetDay;

  bool _prefsLoaded = false;

  /// Exact-input memo — [maxMemoEntries] LRU entries mirrored to disk.
  /// Re-analyzing the same utterance (debounce re-fire, sheet re-open,
  /// app restart, chip re-tap) replays the previous verdict instead of
  /// paying for a second identical request.
  static const int maxMemoEntries = 200;
  final Map<String, AskRouting> _routeMemo = {};

  /// Per-user input cap on what we send to the model. Routing only needs
  /// intent signals (keywords, amount, date) — the first 160 characters
  /// carry them all.
  static const int _maxUserInputChars = 160;

  /// Test hook: reset the in-memory budget and memo between tests. Disk
  /// state is untouched — tests simulate persistence by re-seeding
  /// `SharedPreferences.setMockInitialValues` and calling this to force a
  /// reload, mirroring an app restart.
  @visibleForTesting
  void resetSession() {
    _escalationsToday = 0;
    _budgetDay = null;
    _routeMemo.clear();
    _prefsLoaded = false;
  }

  DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Loads persisted memo + budget once per process. After a restart the
  /// memo replays previous verdicts for free and the daily budget resumes
  /// where the user left off (a new calendar day resets it).
  Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // --- Memo ---
      final rawMemo = prefs.getString(_memoPrefsKey);
      if (rawMemo != null && rawMemo.isNotEmpty) {
        final decoded = jsonDecode(rawMemo);
        if (decoded is List) {
          // Stored oldest-first; replay in order so the most recent entries
          // are most-recently-used in the LRU map.
          for (final entry in decoded) {
            if (entry is! Map<String, dynamic>) continue;
            final input = entry['i'] as String?;
            final routing = _decodeRouting(entry['r']);
            if (input != null && routing != null) {
              _routeMemo[input] = routing;
            }
          }
        }
      }

      // --- Daily budget ---
      final rawBudget = prefs.getString(_budgetPrefsKey);
      if (rawBudget != null) {
        final decoded = jsonDecode(rawBudget);
        if (decoded is Map<String, dynamic>) {
          final day = DateTime.tryParse(decoded['day'] as String? ?? '');
          final count = decoded['count'] as int? ?? 0;
          if (day != null && count >= 0) {
            if (day == _todayMidnight()) {
              _budgetDay = day;
              _escalationsToday = count;
            }
            // A stale day simply stays at zero — no reset write needed.
          }
        }
      }
    } catch (e) {
      debugPrint('AiIntentRouterService: failed to load persisted state ($e)');
      // Corrupt state = default to empty; guards still work in-memory.
    }
  }

  /// Persists the memo (LRU-capped, oldest evicted first) and the daily
  /// counter. Best-effort — a failed write only costs cache warmth.
  Future<void> _persistAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Keep only the newest [maxMemoEntries], serialized oldest-first.
      final entries = _routeMemo.entries.toList();
      final kept = entries.length > maxMemoEntries
          ? entries.sublist(entries.length - maxMemoEntries)
          : entries;
      final encoded = jsonEncode(
        kept
            .map((e) => {
                  'i': e.key,
                  'r': _encodeRouting(e.value),
                })
            .toList(),
      );
      await prefs.setString(_memoPrefsKey, encoded);
      await prefs.setString(
        _budgetPrefsKey,
        jsonEncode({
          'day': (_budgetDay ?? _todayMidnight()).toIso8601String(),
          'count': _escalationsToday,
        }),
      );
    } catch (e) {
      debugPrint('AiIntentRouterService: failed to persist state ($e)');
    }
  }

  Map<String, dynamic> _encodeRouting(AskRouting r) => {
        if (r.intent == AskIntent.logMoney)
          'i': 'LOG_MONEY'
        else if (r.intent == AskIntent.addDocument)
          'i': 'ADD_DOCUMENT'
        else
          'i': 'UNCLEAR',
        'c': r.confidence,
        's': r.source.name,
        if (r.note != null) 'n': r.note,
        if (r.missingDate) 'd': true,
      };

  AskRouting? _decodeRouting(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final intentRaw = (raw['i'] ?? '').toString().trim().toUpperCase();
    final intent = switch (intentRaw) {
      'LOG_MONEY' => AskIntent.logMoney,
      'ADD_DOCUMENT' => AskIntent.addDocument,
      'UNCLEAR' => AskIntent.unclear,
      _ => null,
    };
    if (intent == null) return null;
    final sourceRaw = (raw['s'] ?? '').toString();
    final source = AskRoutingSource.values
        .where((s) => s.name == sourceRaw)
        .firstOrNull;
    return AskRouting(
      intent: intent,
      confidence: (raw['c'] as num? ?? 0.0).clamp(0.0, 1.0).toDouble(),
      source: source ?? AskRoutingSource.fallback,
      note: raw['n'] as String?,
      missingDate: raw['d'] as bool? ?? false,
    );
  }

  /// Escalations already spent today, across all entry points and app
  /// restarts. Exposed so the UI can show remaining budget.
  Future<int> escalationsUsedToday() async {
    await _ensurePrefsLoaded();
    if (_budgetDay != _todayMidnight()) return 0;
    return _escalationsToday;
  }

  /// Remaining escalations for today across all AI entry points.
  Future<int> escalationsRemainingToday() async {
    await _ensurePrefsLoaded();
    if (_budgetDay != _todayMidnight()) return maxEscalationsPerDay;
    return (maxEscalationsPerDay - _escalationsToday).clamp(0, maxEscalationsPerDay);
  }

  // --------------------------------------------------------------------------
  // Local lexicon (also the fallback when Groq is unreachable)
  // --------------------------------------------------------------------------

  /// Words that almost always mean "track a document's expiry".
  static const List<String> _documentKeywords = [
    // Identity & residency
    'emirates id', 'emirate id', 'eid', 'national id', 'identity card',
    'passport', 'visa', 'residence visa', 'residency', 'entry permit',
    // Vehicles & driving
    'driving licence', 'driving license', "driver's licence", 'mulkiya',
    'mulkya', 'vehicle registration', 'car registration',
    // Housing & business
    'ejari', 'tenancy', 'tenancy contract', 'lease', 'trade licence',
    'trade license', 'commercial license', 'business license',
    'establishment card', 'labour card', 'labor card', 'labor contract',
    'labour contract', 'mohre',
    // Other tracked papers
    'insurance', 'insurance policy', 'health card', 'vehicle insurance',
    'certificate', 'certification', 'permit', 'license plate',
    'distinguish', 'wheel cap',
    // Expiry language without a named document still leans document when
    // paired with these verbs:
    'expires', 'expiry', 'expire', 'expiring', 'valid until', 'valid till',
    'renew my', 'renewal of',
  ];

  /// Words that almost always mean "log a money movement". Checked after the
  /// document lexicon so "pay for my visa renewal fee" doesn't misroute —
  /// though a bare "visa renewal" with no money signal does.
  static const List<String> _moneyKeywords = [
    'paid', 'pay', 'payment', 'spent', 'spend', 'bought', 'purchase',
    'received', 'receive', 'got', 'income', 'salary', 'salaries', 'earned',
    'earning', 'refund', 'refunded', 'credited', 'revenue', 'invoice',
    'client payment', 'customer payment', 'deposit', 'bill', 'recurring',
    'subscription', 'budget', 'transfer', 'withdraw', 'withdrew',
    'log an expense', 'log expense', 'log income', 'log a bill',
  ];

  /// Known biller/utility names that scream "money" even when the sentence
  /// has no verb — "DEWA 450" is an expense, not a document.
  static const List<String> _moneyEntityHints = [
    'dewa', 'sewa', 'fewa', 'etisalat', 'du bill', 'salik', 'uber', 'careem',
    'talabat', 'deliveroo', 'noon', 'amazon', 'starbucks', 'mcdonalds',
    'netflix', 'spotify', 'aws', 'google cloud', 'rent',
  ];

  static final RegExp _amountRegex = RegExp(
    r'(^|\s)(aed|sar|kwd|qar|bhd|omr|dirhams?|dhs?|riyals?|dinars?|rupees?|'
    r'\$|€|£)\s*\d|\d\s*(aed|sar|kwd|qar|bhd|omr|dirhams?|dhs?|riyals?|'
    r'dinars?|rupees?)($|\s)',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,2}(st|nd|rd|th)?[\s,./-]*(jan|feb|mar|apr|may|jun|jul|aug|sep|'
    r'oct|nov|dec)[a-z]*([\s,./-]*(20)?\d{2})?'
    r'|(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s,./-]*'
    r'\d{1,2}(st|nd|rd|th)?([\s,./-]*(20)?\d{2})?'
    r'|(20\d{2})[-/.](0?[1-9]|1[012])[-/.](0?[1-9]|[12][0-9]|3[01])'
    r'|\bin\s+\d+\s+(days?|weeks?|months?|years?)\b'
    r'|\b(today|yesterday|tomorrow|next month|next year|last week)\b'
    r'|\b\d+\s+days?\s+ago\b'
    r'|(0?[1-9]|[12][0-9]|3[01])[-/.](0?[1-9]|1[012])[-/.](20\d{2}))',
    caseSensitive: false,
  );

  bool _hasDate(String text) => _dateRegex.hasMatch(text);

  bool _hasAmount(String text) => _amountRegex.hasMatch(text);

  bool _mentionsDocument(String lower) =>
      _documentKeywords.any(lower.contains);

  bool _mentionsMoney(String lower) =>
      _moneyKeywords.any(lower.contains) ||
      _moneyEntityHints.any(lower.contains);

  /// Deterministic offline routing. Exposed publicly for tests.
  AskRouting routeLocally(String input) {
    final text = input.trim();
    if (text.isEmpty) return AskRouting.fallback;
    final lower = text.toLowerCase();

    final isDoc = _mentionsDocument(lower);
    final isMoney = _mentionsMoney(lower);

    if (isDoc && !isMoney) {
      return AskRouting(
        intent: AskIntent.addDocument,
        confidence: _hasDate(lower) ? 0.9 : 0.72,
        source: AskRoutingSource.localKeywords,
        note: _hasDate(lower)
            ? null
            : 'No expiry date found — add one before saving.',
        missingDate: !_hasDate(lower),
      );
    }
    if (isMoney && !isDoc) {
      return AskRouting(
        intent: AskIntent.logMoney,
        confidence: _hasAmount(lower) || _hasDate(lower) ? 0.9 : 0.75,
        source: AskRoutingSource.localKeywords,
      );
    }

    // Both or neither — let the concrete details break the tie.
    if (isDoc && isMoney) {
      // "Log DEWA bill of 450 for my visa renewal" — an amount next to a
      // biller is a money record; an expiry date is a document.
      if (_hasAmount(lower) && !_hasDate(lower)) {
        return const AskRouting(
          intent: AskIntent.logMoney,
          confidence: 0.8,
          source: AskRoutingSource.localKeywords,
        );
      }
      if (_hasDate(lower) && !_hasAmount(lower)) {
        return const AskRouting(
          intent: AskIntent.addDocument,
          confidence: 0.8,
          source: AskRoutingSource.localKeywords,
        );
      }
      // Both signals present ("insurance renewal fee 500 expires 12 oct") —
      // money wins because the parser extracts a clean record either way and
      // an expense is the safer thing to have logged.
      return const AskRouting(
        intent: AskIntent.logMoney,
        confidence: 0.6,
        source: AskRoutingSource.localKeywords,
      );
    }

    // Neither lexicon matched — rely on bare structure.
    if (_hasAmount(lower)) {
      return const AskRouting(
        intent: AskIntent.logMoney,
        confidence: 0.55,
        source: AskRoutingSource.localKeywords,
      );
    }
    return AskRouting.fallback;
  }

  // --------------------------------------------------------------------------
  // Groq-backed routing (token-optimized)
  // --------------------------------------------------------------------------

  /// Escalation model: Groq's cheapest production classifier. Routing is a
  /// 3-way label pick — no reasoning chain, no long output — so a small fast
  /// model is strictly better here than the 120B workhorse used for prose
  /// generation (~8x cheaper per token, higher free-tier RPM).
  static const String _escalationModel = 'openai/gpt-oss-20b';

  /// Completion cap: the reply is one small JSON object. Tokens beyond this
  /// can only be runaway reasoning — cut them off.
  static const int _maxCompletionTokens = 60;

  /// Compact system prompt (~90 tokens vs ~330 for the previous draft).
  /// Same contract: one JSON object, three labels, no prose.
  static const String _groqSystemPrompt =
      'Classify the user request for Finavig, a GCC finance + document-expiry '
      'app. Reply ONLY with JSON: '
      '{"intent":"LOG_MONEY|ADD_DOCUMENT|UNCLEAR","confidence":0.0-1.0}. '
      'LOG_MONEY = expense, income, bill, salary, any money moved. '
      'ADD_DOCUMENT = tracking a document expiry (Emirates ID, visa, '
      'passport, licence, mulkiya, ejari, insurance...). '
      'UNCLEAR = not enough information.';

  /// Route [input].
  ///
  /// Primary: the free local lexicon ([routeLocally]). Secondary: Groq, and
  /// only when the lexicon has no confident signal — so tokens are spent on
  /// the rare genuinely-ambiguous utterance, never the common case. Falls
  /// back cleanly on any Groq failure (offline, rate limit, malformed reply).
  /// Never throws.
  Future<AskRouting> route(String input) async {
    final text = input.trim();
    if (text.isEmpty) return AskRouting.fallback;

    // 1. Local lexicon — free, instant, offline. Handles the common case.
    final local = routeLocally(text);
    if (local.intent != AskIntent.unclear) return local;

    // 2. Escalate only the ambiguous remainder to Groq.
    if (!groqEnabled) return local;

    // 3. Token guards — in order: never pay twice for the same utterance
    //    (memo survives app restarts), then never spend past the rolling
    //    daily budget shared by every AI entry point. Both fall back to the
    //    local verdict (unclear → the sheet asks the user), so behavior is
    //    always defined and costs stay bounded.
    await _ensurePrefsLoaded();
    final memoHit = _routeMemo[text];
    if (memoHit != null) return memoHit;
    if (_budgetDay != _todayMidnight()) {
      // New calendar day — the rolling budget resets.
      _budgetDay = _todayMidnight();
      _escalationsToday = 0;
    }
    if (_escalationsToday >= maxEscalationsPerDay) {
      return AskRouting(
        intent: AskIntent.unclear,
        confidence: 0,
        source: AskRoutingSource.fallback,
        note: 'Daily AI assist limit reached — pick a flow below.',
      );
    }

    _escalationsToday++;
    await _persistAll();
    try {
      final raw = escalationOverride != null
          ? await escalationOverride!(
              text.length > _maxUserInputChars
                  ? text.substring(0, _maxUserInputChars)
                  : text,
            )
          : await GroqApiService.instance.generateSummary(
              systemPrompt: _groqSystemPrompt,
              // Trim the payload: routing needs intent signals, not the full text.
              userPrompt: text.length > _maxUserInputChars
                  ? text.substring(0, _maxUserInputChars)
                  : text,
              feature: 'intent',
              maxTokens: _maxCompletionTokens,
              temperature: 0,
              model: _escalationModel,
            );
      final routing = _parseGroqRouting(raw, userInput: text);
      if (routing != null) {
        // Persist the verdict so a re-analysis of the same utterance never
        // pays for a second identical request — even after an app restart.
        _routeMemo[text] = routing;
        await _persistAll();
        return routing;
      }
      // Model reachable but unparseable — we only got here because the local
      // lexicon was unclear, so ask the user rather than guess.
      final unclear = AskRouting(
        intent: AskIntent.unclear,
        confidence: 0,
        source: AskRoutingSource.fallback,
        note: 'Could not understand that request.',
      );
      _routeMemo[text] = unclear;
      await _persistAll();
      return unclear;
    } catch (e) {
      debugPrint('AiIntentRouterService: Groq escalation failed ($e)');
      // Don't memoize transport failures: a transient network drop shouldn't
      // pin a dead verdict for the rest of the session.
      return AskRouting(
        intent: AskIntent.unclear,
        confidence: 0,
        source: AskRoutingSource.fallback,
        note: 'AI assist unavailable — pick a flow below.',
      );
    }
  }

  /// Parses the model's JSON reply. Public for tests.
  AskRouting? parseGroqRouting(String raw, {String userInput = ''}) =>
      _parseGroqRouting(raw, userInput: userInput);

  AskRouting? _parseGroqRouting(String raw, {required String userInput}) {
    if (raw.isEmpty) return null;
    // Strip markdown fences / stray prose around the JSON object.
    var body = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(body);
    if (fence != null) body = fence.group(1)!.trim();
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    body = body.substring(start, end + 1);

    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final intentRaw = (json['intent'] ?? '').toString().trim().toUpperCase();
      final confidence = (json['confidence'] is num)
          ? (json['confidence'] as num).clamp(0.0, 1.0).toDouble()
          : 0.5;
      final reason = (json['reason'] ?? '').toString().trim();

      switch (intentRaw) {
        case 'LOG_MONEY':
          return AskRouting(
            intent: AskIntent.logMoney,
            confidence: confidence,
            source: AskRoutingSource.groq,
            note: reason.isEmpty ? null : reason,
          );
        case 'ADD_DOCUMENT':
          return AskRouting(
            intent: AskIntent.addDocument,
            confidence: confidence,
            source: AskRoutingSource.groq,
            note: reason.isEmpty ? null : reason,
            // The model cannot be trusted to notice a missing date — re-check
            // the user's own words, not the model's restatement.
            missingDate: userInput.isEmpty ? false : !_hasDate(userInput),
          );
        case 'UNCLEAR':
          // We only escalate when the local lexicon was already unclear, so
          // accept the model's verdict and let the sheet ask the user.
          return AskRouting(
            intent: AskIntent.unclear,
            confidence: confidence,
            source: AskRoutingSource.groq,
            note: reason.isEmpty ? null : reason,
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

/// Convenience top-level used by the sheet so both services stay singletons.
AskRouting routeInputLocally(String input) =>
    AiIntentRouterService.instance.routeLocally(input);
