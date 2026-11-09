import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expiry_item.dart';
import '../models/finance.dart';
import 'document_scanner_service.dart';
import 'finance_service.dart';

/// Tracks user activity days and calculates persistent streaks.
class StreakService extends ChangeNotifier {
  StreakService._();
  static final StreakService instance = StreakService._();

  static const String _activeDatesKey = 'finavig_streak_active_dates';
  static const String _longestStreakKey = 'finavig_streak_longest';

  final Set<String> _activeDates = {};
  int _longestStreak = 0;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int get longestStreak => _longestStreak;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Initialise streak service and load persisted activity history.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_activeDatesKey) ?? [];
      _activeDates.addAll(savedList);
      _longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
      _initialized = true;

      // Automatically record today as an active visit upon opening.
      await recordActivity();
    } catch (e) {
      debugPrint('StreakService.init error: $e');
      _initialized = true;
    }
  }

  /// Records active participation for a given day (defaults to today).
  Future<void> recordActivity([DateTime? date]) async {
    final d = (date ?? DateTime.now()).toLocal();
    final dateStr = _dateFormat.format(d);

    final wasAdded = _activeDates.add(dateStr);
    final streak = currentStreak;
    if (streak > _longestStreak) {
      _longestStreak = streak;
    }

    if (!wasAdded && _initialized) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_activeDatesKey, _activeDates.toList());
      await prefs.setInt(_longestStreakKey, _longestStreak);
    } catch (e) {
      debugPrint('StreakService.recordActivity error: $e');
    }

    notifyListeners();
  }

  /// Returns whether a given day had recorded user activity.
  bool isDateActive(DateTime date, {
    List<ExpiryItem>? items,
    List<FinanceTransaction>? transactions,
  }) {
    final dateStr = _dateFormat.format(date.toLocal());
    if (_activeDates.contains(dateStr)) return true;

    // Check transactions occurred on this calendar date
    final txs = transactions ?? (FinanceService.instance.activeTransactions);
    for (final tx in txs) {
      if (_dateFormat.format(tx.occurredAt.toLocal()) == dateStr) {
        return true;
      }
    }

    // Check documents created or updated on this calendar date
    final docs = items ?? (DocumentScannerService.instance.activeItems);
    for (final doc in docs) {
      final up = doc.updatedAt;
      if (up != null && _dateFormat.format(up.toLocal()) == dateStr) {
        return true;
      }
      final history = doc.renewalHistory;
      if (history != null) {
        for (final r in history) {
          if (_dateFormat.format(r.renewedAt.toLocal()) == dateStr) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Calculates the current consecutive streak (in days).
  int get currentStreak {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Check if user was active today or yesterday (streak still alive)
    final activeToday = isDateActive(today);
    final activeYesterday = isDateActive(yesterday);

    if (!activeToday && !activeYesterday) {
      return 0;
    }

    int streak = 0;
    DateTime cursor = activeToday ? today : yesterday;

    while (isDateActive(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      // Cap at 3650 days to prevent infinite loops in unforeseen edge-cases
      if (streak > 3650) break;
    }

    if (streak > _longestStreak) {
      _longestStreak = streak;
    }

    return streak;
  }

  /// Returns 7 booleans for Monday..Sunday of the current week indicating
  /// which days were active.
  List<bool> weekActivity({
    List<ExpiryItem>? items,
    List<FinanceTransaction>? transactions,
  }) {
    final now = DateTime.now();
    // In Dart weekday is 1 for Monday..7 for Sunday
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final todayIndex = now.weekday - 1;

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      // Current day is active since user is inside the app
      if (i == todayIndex) return true;
      // Future days of this week are false
      if (i > todayIndex) return false;
      return isDateActive(day, items: items, transactions: transactions);
    });
  }

  /// Calculates distinct active days in the last [periodDays] days.
  int activeDaysInPeriod(
    int periodDays, {
    List<ExpiryItem>? items,
    List<FinanceTransaction>? transactions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int count = 0;

    for (int i = 0; i < periodDays; i++) {
      final day = today.subtract(Duration(days: i));
      if (isDateActive(day, items: items, transactions: transactions)) {
        count++;
      }
    }

    return count.clamp(1, periodDays);
  }
}
