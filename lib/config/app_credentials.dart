/// Central credentials file — the single source of truth for the client-safe
/// API credentials used by the app.
///
/// Replaces the previous `--dart-define-from-file=.env.local` build-time
/// injection: edit the values below and rebuild, no env file needed.
///
/// NOTE: values here are compiled into the app binary. Only the anon
/// (publishable) Supabase key may live here — never put a service_role key or
/// any other server-only secret in this file.
///
/// The Groq API key is **not** here. It is held server-side as the
/// `GROQ_API_KEY` secret of the `groq-proxy` Edge Function, which meters AI
/// usage per user; rotate it with
/// `supabase/functions/groq-proxy/rotate-key.sh`.
class AppCredentials {
  AppCredentials._();

  // ── Supabase ────────────────────────────────────────────────────────────
  /// Your Supabase project URL, e.g. 'https://YOUR-PROJECT-ref.supabase.co'.
  static const String supabaseUrl = 'https://jxyzmnaqukxvrcwolkil.supabase.co';

  /// Your Supabase anon (publishable) key.
  static const String supabaseAnonKey =
      'sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf';
}
