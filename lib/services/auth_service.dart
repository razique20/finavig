import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'collection_service.dart';
import 'custom_document_type_service.dart';
import 'document_scanner_service.dart';
import 'entitlement_service.dart';
import 'finance_service.dart';

import 'supabase_service.dart';

/// Thin wrapper around Supabase Auth.
///
/// Supabase persists the session automatically (secure platform storage via
/// supabase_flutter), so [currentUserId] is available on cold start without
/// any extra work. All data access in this app is scoped by `auth.uid()`
/// through Row Level Security — see supabase/schema.sql.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool get isAvailable => SupabaseService.isInitialized;

  Session? get _session => SupabaseService.clientOrNull?.auth.currentSession;

  /// Whether a signed-in session exists (restored automatically on cold
  /// start by supabase_flutter).
  bool get isSignedIn => _session != null;

  /// The authenticated user's id — the value RLS policies compare against
  /// `auth.uid()`. Null when not signed in or Supabase isn't configured.
  String? get currentUserId => _session?.user.id;

  String? get userEmail => _session?.user.email;

  /// Sign in with email + password. Throws [AuthException] on failure with a
  /// user-presentable message.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account. Email confirmation is controlled by the Supabase
  /// Auth provider settings; if enabled the user must click the link in the
  /// email before signing in (the login screen surfaces that error).
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await SupabaseService.client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    await SupabaseService.client.auth.signOut();
  }

  /// Permanently delete the signed-in user's account and all their data.
  ///
  /// Calls the `delete_own_account` security-definer Postgres function (see
  /// supabase/delete_account_function.sql): the auth.users row is removed and
  /// every business table cascades via owner_id ON DELETE CASCADE. Then the
  /// session is signed out and local caches/preferences are cleared so no
  /// trace of the account remains on this device.
  ///
  /// Throws [AuthException] when Supabase is unreachable or the RPC fails.
  /// No-op in local-only mode (no Supabase configured).
  Future<void> deleteAccount() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return; // local-only mode: nothing to delete server-side

    // 1. Server-side deletion (auth user + all cascaded rows).
    await client.rpc('delete_own_account');

    // 2. Sign out. The auth row is already gone, so server-side token
    //    revocation inside signOut may fail with AuthException — ignore it;
    //    local session cleanup is what matters now.
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {
      // Best-effort — local session is cleared by supabase_flutter regardless.
    }

    // 3. Clear every local cache/pref that could hold account remnants.
    await _clearLocalAccountData();
  }

  /// Removes all device-local data tied to the (now-deleted) account:
  /// document/finance caches, quota counters, AI keys, profile fields and
  /// the local-mode stores. Best-effort per key — deletion must succeed
  /// even if one pref read fails.
  Future<void> _clearLocalAccountData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        try {
          await prefs.remove(key);
        } catch (_) {}
      }
    } catch (_) {
      // SharedPreferences unavailable — proceed with sign-out anyway.
    }

    // Reset in-memory service caches (same set as sign-out plus the
    // collection scope) so a new sign-up starts from a clean slate.
    // Server-side rows are already gone via CASCADE and prefs are wiped,
    // so the per-feature quota clearers are not needed here.
    DocumentScannerService.instance.clearCache();
    FinanceService.instance.clearCache();
    EntitlementService.instance.reset();
    await CustomDocumentTypeService.instance.reset();
    await DocumentCollectionService.instance.reset();
  }

  /// Listen to auth changes (sign-in, sign-out, token refresh). Used by the
  /// splash screen and router to react to session changes.
  Stream<AuthState> get onAuthStateChange =>
      isAvailable ? SupabaseService.client.auth.onAuthStateChange : const Stream.empty();
}
