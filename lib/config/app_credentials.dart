/// Central credentials file — the single source of truth for all API
/// credentials used by the app.
///
/// Replaces the previous `--dart-define-from-file=.env.local` build-time
/// injection: edit the values below and rebuild, no env file needed.
///
/// NOTE: values here are compiled into the app binary. That is fine for the
/// anon (publishable) Supabase key, but never put a service_role key or any
/// other server-only secret in this file.
class AppCredentials {
  AppCredentials._();

  // ── Supabase ────────────────────────────────────────────────────────────
  /// Your Supabase project URL, e.g. 'https://YOUR-PROJECT-ref.supabase.co'.
  static const String supabaseUrl = 'https://jxyzmnaqukxvrcwolkil.supabase.co';

  /// Your Supabase anon (publishable) key.
  static const String supabaseAnonKey =
      'sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf';

  // ── Groq ───────────────────────────────────────────────────────────────
  /// In-app default Groq API key (AI summaries, budget plans, Ask Finavig
  /// routing). Users can override it at runtime in Settings; this constant
  /// is the out-of-the-box fallback.
  ///
  /// NOTE: like every client-embedded value this can be extracted from the
  /// binary — it is protected only by Groq-side spend limits and the app's
  /// per-user quota counters. Move AI calls behind a Supabase Edge Function
  /// (key stored server-side) before scaling beyond the pilot.
  static const String groqApiKey =
      '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';
}
