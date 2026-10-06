import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../models/credit.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'supabase_service.dart';

/// Store for the signed-in user's credit obligations (money borrowed
/// from or lent to someone) — all scoped to a [DocumentCollection].
///
/// Follows the same pattern as FinanceService:
/// * Singleton + [ChangeNotifier] so screens can listen.
/// * Supabase-backed when credentials exist (table: credit_entries —
///   see supabase/credit_schema.sql).
/// * Local-only mode: records persist to SharedPreferences as JSON so
///   the credit tracker stays fully usable offline.
class CreditService extends ChangeNotifier {
  CreditService._();

  static final CreditService instance = CreditService._();

  factory CreditService() => instance;

  static const String _localStoreKey = 'creditEntries.v1';

  /// Null in local-only mode (unconfigured, or Supabase not
  /// initialised — e.g. unit tests). clientOrNull never throws.
  final SupabaseClient? _client = SupabaseService.clientOrNull;

  final List<CreditEntry> _credits = [];
  bool _initialized = false;

  /// Whether credit records have been loaded into memory.
  bool get isInitialized => _initialized;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  List<CreditEntry> get credits => List.unmodifiable(_credits);

  /// All records scoped to the active collection.
  List<CreditEntry> get activeCredits {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return _credits.where((c) => c.collectionId == activeId).toList();
  }

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client == null || userId == null) {
      await _loadLocal();
      return;
    }

    try {
      final rows = await client
          .from('credit_entries')
          .select()
          .eq('owner_id', userId)
          .order('deadline', ascending: true);
      _credits
        ..clear()
        ..addAll(rows.map(_creditRowToModel));
    } catch (_) {
      // Supabase unreachable or table missing — fall back to local
      // store so the credit tracker keeps working offline.
      await _loadLocal();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _initialized = false;
    await init();
  }

  /// Drop all cached data (used on sign-out).
  void clearCache() {
    _credits.clear();
    _initialized = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Writes
  // ------------------------------------------------------------------

  Future<void> addCredit(CreditEntry credit) async {
    final scoped = credit.collectionId.isEmpty
        ? credit.copyWith(
            collectionId: DocumentCollectionService.instance.activeCollectionId,
          )
        : credit;

    final client = _client;
    if (client != null && AuthService.instance.currentUserId != null) {
      try {
        await client
            .from('credit_entries')
            .insert(
              _creditModelToRow(
                scoped,
                ownerId: AuthService.instance.currentUserId,
              ),
            );
      } catch (_) {
        // Non-fatal: keep the record locally so nothing is lost.
      }
    }

    _credits.add(scoped);
    await _persistLocal();
    notifyListeners();
  }

  Future<void> updateCredit(CreditEntry updated) async {
    final client = _client;
    if (client != null) {
      try {
        await client
            .from('credit_entries')
            .update(_creditModelToRow(updated))
            .eq('id', updated.id);
      } catch (_) {
        // Non-fatal.
      }
    }
    final index = _credits.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _credits[index] = updated;
    } else {
      _credits.add(updated);
    }
    await _persistLocal();
    notifyListeners();
  }

  /// Move the deadline of [id] to [newDeadline], appending to the
  /// extension history so the repayment-behaviour trail stays intact.
  Future<void> extendDeadline(String id, DateTime newDeadline) async {
    final index = _credits.indexWhere((c) => c.id == id);
    if (index == -1) return;
    await updateCredit(_credits[index].extendDeadline(newDeadline));
  }

  Future<void> deleteCredit(String id) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from('credit_entries').delete().eq('id', id);
      } catch (_) {
        // Non-fatal.
      }
    }
    _credits.removeWhere((c) => c.id == id);
    await _persistLocal();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<void> _persistLocal() async {
    if (_client != null && AuthService.instance.currentUserId != null) {
      return; // Supabase is the source of truth when connected.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localStoreKey,
      jsonEncode({'credits': _credits.map((c) => c.toJson()).toList()}),
    );
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localStoreKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _credits
        ..clear()
        ..addAll(
          (decoded['credits'] as List<dynamic>? ?? const []).map(
            (json) => CreditEntry.fromJson(json as Map<String, dynamic>),
          ),
        );
    } catch (_) {
      // Ignore malformed cache — start empty rather than crash.
    }
  }

  // ------------------------------------------------------------------
  // DB row ↔ model
  // ------------------------------------------------------------------

  static CreditEntry _creditRowToModel(Map<String, dynamic> row) {
    return CreditEntry(
      id: row['id'] as String,
      collectionId: row['collection_id'] as String? ?? 'personal',
      direction: row['direction'] == 'lent'
          ? CreditDirection.lent
          : CreditDirection.borrowed,
      counterpartyName: row['counterparty_name'] as String? ?? 'Contact',
      counterpartyPhone: row['counterparty_phone'] as String?,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'AED',
      deadline:
          DateTime.tryParse(row['deadline'] as String? ?? '') ?? DateTime.now(),
      extensionHistory: _extensionsFromRow(row['extension_history']),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// PostgREST returns jsonb columns already decoded; older clients
  /// may hand them back as a JSON string — accept both.
  static List<CreditExtension> _extensionsFromRow(dynamic raw) {
    if (raw == null) return const [];
    try {
      final list = raw is String
          ? jsonDecode(raw) as List<dynamic>
          : raw as List<dynamic>;
      return list
          .map((e) => CreditExtension.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _creditModelToRow(
    CreditEntry c, {
    String? ownerId,
  }) {
    final row = <String, dynamic>{
      'id': c.id,
      'collection_id': c.collectionId,
      'direction': c.direction.name,
      'counterparty_name': c.counterpartyName,
      'counterparty_phone': c.counterpartyPhone,
      'amount': c.amount,
      'currency': c.currency,
      'deadline': c.deadline.toIso8601String().split('T').first,
      'extension_history': jsonEncode(
        c.extensionHistory.map((e) => e.toJson()).toList(),
      ),
    };
    if (ownerId != null) row['owner_id'] = ownerId;
    return row;
  }
}
