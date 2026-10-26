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
      'sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf';

  // ── Active Supabase Configuration ─────────────────────────────────────────
  /// Active Supabase project URL based on [isStaging].
  static const String supabaseUrl =
      isStaging ? stagingSupabaseUrl : prodSupabaseUrl;

  /// Active Supabase anon (publishable) key based on [isStaging].
  static const String supabaseAnonKey =
      isStaging ? stagingSupabaseAnonKey : prodSupabaseAnonKey;
}

/// Top-level constant aliases for convenience.
const bool kIsStaging = AppConstants.isStaging;
const String kSupabaseUrl = AppConstants.supabaseUrl;
const String kSupabaseAnonKey = AppConstants.supabaseAnonKey;
