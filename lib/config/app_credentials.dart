import '../constants/app_constants.dart';

/// Central credentials file — the single source of truth for the client-safe
/// API credentials used by the app.
///
/// Replaces the previous `--dart-define-from-file=.env.local` build-time
/// injection: edit the values in [AppConstants] (or below) and rebuild.
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
  /// Your Supabase project URL, referenced from [AppConstants].
  static const String supabaseUrl = AppConstants.supabaseUrl;

  /// Your Supabase anon (publishable) key, referenced from [AppConstants].
  static const String supabaseAnonKey = AppConstants.supabaseAnonKey;
}
