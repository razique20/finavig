/// Central configuration for public-facing links used across the app
/// (Terms, Privacy, Website, WhatsApp, email).
///
/// Values point to the production destinations — update the constants here
/// when pages move and every screen follows.
class AppLinks {
  AppLinks._();

  // ── Web pages ────────────────────────────────────────────────────────────
  static const String website = 'https://wazy-admin-sgjt.vercel.app';
  static const String terms = 'https://wazy-admin-sgjt.vercel.app/terms';
  static const String privacy = 'https://wazy-admin-sgjt.vercel.app/privacy';

  // ── Direct contact ───────────────────────────────────────────────────────
  static const String supportEmail = 'aethylglobal@gmail.com';
  static const String salesEmail = 'wazyappuae@gmail.com';

  // ── Composed URLs ────────────────────────────────────────────────────────
  static String get mailtoSupport => 'mailto:$supportEmail';
  static String get mailtoSales => 'mailto:$salesEmail';
}
