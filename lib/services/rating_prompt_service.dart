import 'package:shared_preferences/shared_preferences.dart';

/// Soft "Rate Finavig" prompt policy.
///
/// Pure logic separated from UI so the trigger rules are unit-testable.
/// The prompt is a native in-app review sheet; the policy decides *when*
/// asking is appropriate so the app never nags:
///
/// - never before 2 renewals logged (first success moment earns trust first)
/// - at most once every 90 days
/// - at most 3 times per install, ever
/// - never on builds where the platform sheet is unavailable (tests)
class RatingPromptPolicy {
  RatingPromptPolicy._();

  static const int minRenewalsBeforeAsk = 2;
  static const int cooldownDays = 90;
  static const int maxAsksPerInstall = 3;

  /// Decide whether to show the prompt now.
  ///
  /// [renewalCount] — how many documents the user has marked renewed.
  /// [lastAskedAt] — epoch millis of the last prompt, null if never.
  /// [askCount] — prompts shown so far on this install.
  /// [canPrompt] — false when the platform review sheet is unavailable.
  static bool shouldAsk({
    required int renewalCount,
    required int? lastAskedAt,
    required int askCount,
    bool canPrompt = true,
  }) {
    if (!canPrompt) return false;
    if (renewalCount < minRenewalsBeforeAsk) return false;
    if (askCount >= maxAsksPerInstall) return false;
    if (lastAskedAt != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastAskedAt;
      if (elapsed < cooldownDays * 24 * 60 * 60 * 1000) return false;
    }
    return true;
  }
}

/// Persists the rating-prompt state and owns the ask counter. Call
/// [maybeAsk] from success moments (e.g. after a document is renewed); the
/// UI layer supplies the actual review-sheet builder via the callback.
class RatingPromptService {
  RatingPromptService._();

  static final RatingPromptService instance = RatingPromptService._();

  static const String _keyLastAsked = 'finavig.rating.lastAskedAt';
  static const String _keyAskCount = 'finavig.rating.askCount';
  static const String _keyRenewalCount = 'finavig.rating.renewalCount';

  /// Platform capability probe — overridden in tests.
  Future<bool> Function()? canPromptOverride;

  /// The actual prompt. The UI layer injects this (keeps this service
  /// widget-free); production wires the native in-app review sheet.
  Future<void> Function()? showPrompt;

  /// Record one completed renewal (a success moment worth asking after).
  Future<void> recordRenewal() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyRenewalCount) ?? 0;
    await prefs.setInt(_keyRenewalCount, current + 1);
  }

  /// Evaluate the policy and, if it says so, show the prompt once.
  ///
  /// Returns true when the prompt was shown. Never throws, never blocks
  /// the caller's flow — failures degrade to "don't ask".
  Future<bool> maybeAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final renewalCount = prefs.getInt(_keyRenewalCount) ?? 0;
      final lastAskedAt = prefs.getInt(_keyLastAsked);
      final askCount = prefs.getInt(_keyAskCount) ?? 0;

      final canPrompt =
          await (canPromptOverride?.call() ?? Future.value(true));

      final should = RatingPromptPolicy.shouldAsk(
        renewalCount: renewalCount,
        lastAskedAt: lastAskedAt,
        askCount: askCount,
        canPrompt: canPrompt,
      );
      if (!should) return false;

      await prefs.setInt(_keyLastAsked, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_keyAskCount, askCount + 1);

      await showPrompt?.call();
      return true;
    } catch (_) {
      return false;
    }
  }
}
