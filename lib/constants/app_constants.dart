/// Central application constants file.
///
/// Stores project-wide static constants including Supabase backend configuration.
class AppConstants {
  AppConstants._();

  // ── Environment Flag ──────────────────────────────────────────────────────
  /// Set to `true` to use staging credentials, or `false` for production.
  static const bool isStaging = true;

  // ── Staging Environment ───────────────────────────────────────────────────
  static const String stagingSupabaseUrl =
      'https://jxyzmnaqukxvrcwolkil.supabase.co';
  static const String stagingSupabaseAnonKey =
      'sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf';

  // ── Production Environment ────────────────────────────────────────────────
  static const String prodSupabaseUrl =
      'https://xyqtigapyespcasdhhul.supabase.co';
  static const String prodSupabaseAnonKey =
      'sb_publishable_2yC2sbcDdjPfcrdp5bhW9g_wSXz_xbv';

  // ── Active Supabase Configuration ─────────────────────────────────────────
  /// Active Supabase project URL based on [isStaging].
  static const String supabaseUrl = isStaging
      ? stagingSupabaseUrl
      : prodSupabaseUrl;

  /// Active Supabase anon (publishable) key based on [isStaging].
  static const String supabaseAnonKey = isStaging
      ? stagingSupabaseAnonKey
      : prodSupabaseAnonKey;

  // ── PostHog Analytics ──────────────────────────────────────────────────────
  // TODO: Replace these placeholders with your PostHog project API key from
  //       https://us.posthog.com/settings/project#variables (or EU equivalent).
  //       The API key is safe to ship in client code (it is a write-only,
  //       publishable key — equivalent to the Supabase anon key).

  /// PostHog project API key for staging.
  static const String stagingPosthogApiKey =
      'phc_nBFub4QyFf6AfKGNmcfHPkWbCgBtB7kAtVcvFTgbNqB9';

  /// PostHog project API key for production.
  static const String prodPosthogApiKey =
      'phc_nBFub4QyFf6AfKGNmcfHPkWbCgBtB7kAtVcvFTgbNqB9';

  /// Active PostHog API key based on [isStaging].
  static const String posthogApiKey = isStaging
      ? stagingPosthogApiKey
      : prodPosthogApiKey;

  /// PostHog ingest host. Change to 'https://eu.i.posthog.com' if your
  /// PostHog project is in the EU region.
  static const String posthogHost = 'https://us.i.posthog.com';

  // ── Sentry Error Monitoring ───────────────────────────────────────────────
  /// Sentry DSN for crash reporting and performance tracing.
  /// Safe to compile into client code (public ingest key).
  static const String sentryDsn =
      'https://b853020e8eca8d14e86ecb1258b4c5ae@o4512412836364288.ingest.de.sentry.io/4512412925558864';
}

/// Top-level constant aliases for convenience.
const bool kIsStaging = AppConstants.isStaging;
const String kSupabaseUrl = AppConstants.supabaseUrl;
const String kSupabaseAnonKey = AppConstants.supabaseAnonKey;
