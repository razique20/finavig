import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'document_scanner_service.dart';
import 'finance_service.dart';

/// Bundles the signed-in user's tracked data into one portable JSON file —
/// the "Download my data" right under UAE PDPL / GDPR-style rules.
///
/// Includes documents (metadata + renewal history), finance ledger
/// (transactions, budgets, envelopes, recurring templates) and the small
/// profile fields stored in SharedPreferences. Attachment *files* stay
/// device-local by design — the export carries metadata only.
class UserDataExportService {
  UserDataExportService._();

  static final UserDataExportService instance = UserDataExportService._();

  /// Keys we own in SharedPreferences that carry user data worth exporting.
  static const List<String> _profilePrefKeys = [
    'userRole',
    'userPhone',
    'hasOnboarded',
    'hasSeenWelcome',
    'wazy.support_requests.v1',
  ];

  /// Build the export payload. Pure data — the caller decides how to save
  /// or share it. Never throws on partial data: sections degrade to empty.
  Future<Map<String, dynamic>> buildExport() async {
    final documents = await DocumentScannerService.instance
        .getAllItems(includeExpired: true);

    final finance = FinanceService.instance;

    final prefs = await SharedPreferences.getInstance();
    final profile = <String, dynamic>{};
    for (final key in _profilePrefKeys) {
      final value = prefs.get(key);
      if (value != null) profile[key] = value;
    }

    return {
      'format': 'finavig-user-data-export',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'finance': {
        'transactions':
            finance.transactions.map((t) => t.toJson()).toList(),
        'budgets': finance.budgets.map((b) => b.toJson()).toList(),
        'envelopes': finance.envelopes.map((e) => e.toJson()).toList(),
        'recurring': finance.recurring.map((r) => r.toJson()).toList(),
      },
      'profile': profile,
    };
  }

  /// JSON string ready to save/share.
  Future<String> buildExportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await buildExport());
}
