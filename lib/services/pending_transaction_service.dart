import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/finance.dart';
import 'bank_notification_parser.dart';
import 'finance_service.dart';

/// A detected transaction awaiting user confirmation.
class PendingTransaction {
  final String id;
  final ParsedBankNotification parsed;
  final DateTime detectedAt;

  /// Whether the user has acted on this (confirmed or dismissed).
  bool isHandled;

  /// True if the user dismissed it, false if confirmed, null if pending.
  bool? wasDismissed;

  PendingTransaction({
    String? id,
    required this.parsed,
    DateTime? detectedAt,
    this.isHandled = false,
    this.wasDismissed,
  })  : id = id ?? const Uuid().v4(),
        detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawText': parsed.rawText,
        'packageName': parsed.packageName,
        'bankName': parsed.bankName,
        'kind': parsed.kind.name,
        'amount': parsed.amount,
        'currency': parsed.currency,
        'merchant': parsed.merchant,
        'category': parsed.category.name,
        'cardSuffix': parsed.cardSuffix,
        'availableBalance': parsed.availableBalance,
        'referenceNumber': parsed.referenceNumber,
        'receivedAt': parsed.receivedAt.toIso8601String(),
        'confidence': parsed.confidence,
        'detectedAt': detectedAt.toIso8601String(),
        'isHandled': isHandled,
        'wasDismissed': wasDismissed,
      };

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      id: json['id'] as String,
      parsed: ParsedBankNotification(
        rawText: json['rawText'] as String? ?? '',
        packageName: json['packageName'] as String?,
        bankName: json['bankName'] as String? ?? 'Bank',
        kind: json['kind'] == 'income' ? FinanceKind.income : FinanceKind.expense,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'AED',
        merchant: json['merchant'] as String? ?? 'Transaction',
        category: FinanceCategoryX.fromName(json['category'] as String?),
        cardSuffix: json['cardSuffix'] as String?,
        availableBalance: (json['availableBalance'] as num?)?.toDouble(),
        referenceNumber: json['referenceNumber'] as String?,
        receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
            DateTime.now(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      ),
      detectedAt: DateTime.tryParse(json['detectedAt'] as String? ?? '') ??
          DateTime.now(),
      isHandled: json['isHandled'] as bool? ?? false,
      wasDismissed: json['wasDismissed'] as bool?,
    );
  }
}

/// Manages detected banking transactions awaiting user confirmation.
///
/// Persists pending transactions to SharedPreferences so they survive app
/// restarts. Auto-expires items older than 7 days.
class PendingTransactionService extends ChangeNotifier {
  PendingTransactionService._();
  static final PendingTransactionService instance = PendingTransactionService._();
  factory PendingTransactionService() => instance;

  static const String _prefsKey = 'finavig_pending_transactions_v1';
  static const int _maxPendingAge = 7; // days
  static const int _maxQueueSize = 50;

  final List<PendingTransaction> _pending = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// All pending (unhandled) transactions, newest first.
  List<PendingTransaction> get pending =>
      _pending.where((p) => !p.isHandled).toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

  /// Count of unhandled pending transactions (for badge display).
  int get pendingCount => _pending.where((p) => !p.isHandled).length;

  /// Total detected today (including handled).
  int get detectedToday {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _pending.where((p) => p.detectedAt.isAfter(todayStart)).length;
  }

  /// Initialise — load from disk and prune stale entries.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromDisk();
    _pruneExpired();
    notifyListeners();
  }

  /// Add a newly detected transaction to the pending queue.
  /// Returns true if it was added (not a duplicate).
  Future<bool> addDetected(ParsedBankNotification parsed) async {
    await init();

    if (_isDuplicate(parsed)) {
      debugPrint(
        'PendingTransactionService: dropping duplicate ${parsed.bankName} ${parsed.amount} ${parsed.currency} @ ${parsed.merchant}',
      );
      return false;
    }

    final pendingTx = PendingTransaction(parsed: parsed);
    _pending.insert(0, pendingTx);

    // Cap the queue size
    while (_pending.length > _maxQueueSize) {
      _pending.removeLast();
    }

    await _persistToDisk();
    notifyListeners();
    return true;
  }

  /// Multi-signal de-duplication:
  /// 1. Checks recent notifications within a 15-minute window (both handled and unhandled).
  /// 2. Matches exact raw text, reference numbers, or card suffix + amount.
  /// 3. Matches similar merchant + compatible bank + matching amount.
  /// 4. Checks against already logged transactions in FinanceService.
  bool _isDuplicate(ParsedBankNotification parsed) {
    final now = DateTime.now();
    final windowCutoff = now.subtract(const Duration(minutes: 15));

    // 1. Check against recent items in the pending queue
    for (final existing in _pending) {
      if (existing.detectedAt.isBefore(windowCutoff)) continue;

      // Exact raw text match
      if (existing.parsed.rawText.trim().isNotEmpty &&
          existing.parsed.rawText.trim() == parsed.rawText.trim()) {
        return true;
      }

      // Exact reference number match
      if (parsed.referenceNumber != null &&
          existing.parsed.referenceNumber != null &&
          parsed.referenceNumber == existing.parsed.referenceNumber) {
        return true;
      }

      // Matching amount & currency
      final sameAmount = (existing.parsed.amount - parsed.amount).abs() < 0.01;
      final sameCurrency = existing.parsed.currency.toUpperCase() ==
          parsed.currency.toUpperCase();

      if (sameAmount && sameCurrency) {
        // Strong signal 1: Card suffix matches (e.g. push + SMS for same card)
        if (parsed.cardSuffix != null &&
            existing.parsed.cardSuffix != null &&
            parsed.cardSuffix == existing.parsed.cardSuffix) {
          return true;
        }

        // Strong signal 2: Merchant matches or is closely related
        final m1 = existing.parsed.merchant.toLowerCase().trim();
        final m2 = parsed.merchant.toLowerCase().trim();
        final sameMerchant = m1 == m2 ||
            (m1.isNotEmpty &&
                m2.isNotEmpty &&
                (m1.contains(m2) || m2.contains(m1))) ||
            m1 == 'transaction' ||
            m2 == 'transaction';

        // Bank compatibility (one may be 'Bank' from generic SMS, other named)
        final b1 = existing.parsed.bankName.toLowerCase();
        final b2 = parsed.bankName.toLowerCase();
        final compatibleBank = b1 == b2 || b1 == 'bank' || b2 == 'bank';

        if (sameMerchant && compatibleBank) {
          return true;
        }
      }
    }

    // 2. Check against already logged transactions in FinanceService
    if (FinanceService.instance.isInitialized) {
      final loggedTransactions = FinanceService.instance.transactions;
      final today = DateTime(now.year, now.month, now.day);
      for (final tx in loggedTransactions) {
        final txDate =
            DateTime(tx.occurredAt.year, tx.occurredAt.month, tx.occurredAt.day);
        if (txDate.isBefore(today)) continue;

        final sameAmount = (tx.amount - parsed.amount).abs() < 0.01;
        final sameKind = tx.kind == parsed.kind;
        if (sameAmount && sameKind) {
          final txTitle = tx.title.toLowerCase().trim();
          final m2 = parsed.merchant.toLowerCase().trim();
          if (txTitle == m2 ||
              (txTitle.isNotEmpty &&
                  m2.isNotEmpty &&
                  (txTitle.contains(m2) || m2.contains(txTitle)))) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Mark a pending transaction as confirmed (will be logged by the caller).
  Future<void> markConfirmed(String id) async {
    final index = _pending.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _pending[index].isHandled = true;
    _pending[index].wasDismissed = false;
    await _persistToDisk();
    notifyListeners();
  }

  /// Mark a pending transaction as dismissed.
  Future<void> markDismissed(String id) async {
    final index = _pending.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _pending[index].isHandled = true;
    _pending[index].wasDismissed = true;
    await _persistToDisk();
    notifyListeners();
  }

  /// Dismiss all pending transactions at once.
  Future<void> dismissAll() async {
    for (final p in _pending) {
      if (!p.isHandled) {
        p.isHandled = true;
        p.wasDismissed = true;
      }
    }
    await _persistToDisk();
    notifyListeners();
  }

  /// Clear all data (used on sign-out / data wipe).
  Future<void> clearAll() async {
    _pending.clear();
    await _persistToDisk();
    notifyListeners();
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  void _pruneExpired() {
    final cutoff = DateTime.now().subtract(Duration(days: _maxPendingAge));
    _pending.removeWhere((p) => p.detectedAt.isBefore(cutoff));
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => PendingTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
      _pending
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('PendingTransactionService load error: $e');
    }
  }

  Future<void> _persistToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_pending.map((p) => p.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      debugPrint('PendingTransactionService persist error: $e');
    }
  }
}
