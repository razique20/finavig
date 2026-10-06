import 'finance.dart';

/// Which side of a credit obligation the user is on.
enum CreditDirection { borrowed, lent }

extension CreditDirectionX on CreditDirection {
  String get label => this == CreditDirection.borrowed ? 'Borrowed' : 'Lent';

  /// Who the counterparty is from the user's perspective.
  String get counterpartyRole =>
      this == CreditDirection.borrowed ? 'Creditor' : 'Debtor';

  /// Short money-flow label, e.g. "I owe" / "Owed to me".
  String get flowLabel =>
      this == CreditDirection.borrowed ? 'I owe' : 'Owed to me';

  /// Label for the date the obligation began, from the user's view.
  String get startLabel =>
      this == CreditDirection.borrowed ? 'Borrowed on' : 'Lent on';

  /// Field label for the date the obligation began.
  String get startDateFieldLabel =>
      this == CreditDirection.borrowed ? 'Borrowed date' : 'Lent date';
}

/// One recorded deadline extension: the deadline moved from [from] to
/// [to], decided at [at]. Kept forever — the repayment-behaviour
/// trail is the input for the future credit-giving mechanism.
class CreditExtension {
  final DateTime from;
  final DateTime to;
  final DateTime at;

  const CreditExtension({
    required this.from,
    required this.to,
    required this.at,
  });

  factory CreditExtension.fromJson(Map<String, dynamic> json) {
    return CreditExtension(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'at': at.toIso8601String(),
  };
}

/// A credit obligation inside a collection: money the user borrowed
/// from someone ([CreditDirection.borrowed]) or lent to someone
/// ([CreditDirection.lent]). An obligation, not a money movement —
/// repayments are logged as transactions separately.
class CreditEntry {
  final String id;
  final String collectionId;
  final CreditDirection direction;
  final String counterpartyName;
  final String? counterpartyPhone;
  final double amount;
  final String currency;
  DateTime deadline;

  /// When the money actually changed hands — the date the user
  /// borrowed or lent it, which the user can set. Distinct from
  /// [createdAt] (when the record was entered).
  final DateTime startDate;

  /// Short free-text note explaining why the obligation exists,
  /// e.g. "Borrowed for car repair". Optional.
  final String? description;

  /// Deadline extensions, oldest first. Empty when the deadline was
  /// never moved. The first entry's `from` is the original deadline.
  final List<CreditExtension> extensionHistory;
  final DateTime createdAt;

  /// When the obligation was closed (money repaid / received back).
  /// Null while the entry is still outstanding. Settled entries drop
  /// out of the totals, overdue math and the AI prompts, but stay in
  /// history so the extension trail is preserved.
  final DateTime? settledAt;

  /// The Money transaction that mirrored the principal changing hands,
  /// when the user opted to sync the origin into Money.
  final String? disbursementTransactionId;

  /// The Money transaction that settled this obligation, when the user
  /// opted to log the repayment in Money.
  final String? settlementTransactionId;

  CreditEntry({
    required this.id,
    required this.collectionId,
    required this.direction,
    required this.counterpartyName,
    required this.amount,
    required this.deadline,
    required this.startDate,
    this.counterpartyPhone,
    this.currency = 'AED',
    this.description,
    this.extensionHistory = const [],
    required this.createdAt,
    this.settledAt,
    this.disbursementTransactionId,
    this.settlementTransactionId,
  });

  /// Whether the obligation has been closed.
  bool get isSettled => settledAt != null;

  /// Number of times the deadline has been extended.
  int get extensionCount => extensionHistory.length;

  /// The deadline the entry was created with, before any extensions.
  DateTime get originalDeadline =>
      extensionHistory.isEmpty ? deadline : extensionHistory.first.from;

  /// Returns a copy with the deadline moved to [newDeadline],
  /// recording the move in [extensionHistory]. The original deadline
  /// and every prior extension stay on record.
  CreditEntry extendDeadline(DateTime newDeadline, {DateTime? at}) {
    assert(
      newDeadline.isAfter(deadline),
      'New deadline must be later than the current one',
    );
    return CreditEntry(
      id: id,
      collectionId: collectionId,
      direction: direction,
      counterpartyName: counterpartyName,
      counterpartyPhone: counterpartyPhone,
      amount: amount,
      currency: currency,
      deadline: newDeadline,
      startDate: startDate,
      description: description,
      extensionHistory: [
        ...extensionHistory,
        CreditExtension(
          from: deadline,
          to: newDeadline,
          at: at ?? DateTime.now(),
        ),
      ],
      createdAt: createdAt,
      settledAt: settledAt,
      disbursementTransactionId: disbursementTransactionId,
      settlementTransactionId: settlementTransactionId,
    );
  }

  CreditEntry copyWith({
    String? collectionId,
    CreditDirection? direction,
    String? counterpartyName,
    Object? counterpartyPhone = _unset,
    double? amount,
    String? currency,
    DateTime? deadline,
    DateTime? startDate,
    Object? description = _unset,
    List<CreditExtension>? extensionHistory,
    Object? settledAt = _unset,
    Object? disbursementTransactionId = _unset,
    Object? settlementTransactionId = _unset,
  }) {
    return CreditEntry(
      id: id,
      collectionId: collectionId ?? this.collectionId,
      direction: direction ?? this.direction,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyPhone: identical(counterpartyPhone, _unset)
          ? this.counterpartyPhone
          : counterpartyPhone as String?,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      deadline: deadline ?? this.deadline,
      startDate: startDate ?? this.startDate,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      extensionHistory: extensionHistory ?? this.extensionHistory,
      createdAt: createdAt,
      settledAt: identical(settledAt, _unset)
          ? this.settledAt
          : settledAt as DateTime?,
      disbursementTransactionId: identical(disbursementTransactionId, _unset)
          ? this.disbursementTransactionId
          : disbursementTransactionId as String?,
      settlementTransactionId: identical(settlementTransactionId, _unset)
          ? this.settlementTransactionId
          : settlementTransactionId as String?,
    );
  }

  /// Marks this obligation settled at [at], optionally linking the Money
  /// transaction that mirrors the repayment.
  CreditEntry markSettled({
    required DateTime at,
    String? transactionId,
  }) =>
      copyWith(settledAt: at, settlementTransactionId: transactionId);

  static const Object _unset = Object();

  factory CreditEntry.fromJson(Map<String, dynamic> json) {
    return CreditEntry(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'personal',
      direction: json['direction'] == 'lent'
          ? CreditDirection.lent
          : CreditDirection.borrowed,
      counterpartyName: json['counterpartyName'] as String? ?? 'Contact',
      counterpartyPhone: json['counterpartyPhone'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'AED',
      deadline:
          DateTime.tryParse(json['deadline'] as String? ?? '') ??
          DateTime.now(),
      // Older records predate startDate — fall back to when the
      // record was created rather than losing the date entirely.
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      description: json['description'] as String?,
      extensionHistory: (json['extensionHistory'] as List<dynamic>? ?? const [])
          .map((e) => CreditExtension.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      settledAt: DateTime.tryParse(json['settledAt'] as String? ?? ''),
      disbursementTransactionId:
          json['disbursementTransactionId'] as String?,
      settlementTransactionId: json['settlementTransactionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'direction': direction.name,
    'counterpartyName': counterpartyName,
    'counterpartyPhone': counterpartyPhone,
    'amount': amount,
    'currency': currency,
    'deadline': deadline.toIso8601String(),
    'startDate': startDate.toIso8601String(),
    'description': description,
    'extensionHistory': extensionHistory.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'settledAt': settledAt?.toIso8601String(),
    'disbursementTransactionId': disbursementTransactionId,
    'settlementTransactionId': settlementTransactionId,
  };
}

/// Pure (UI-free, I/O-free) rules for the credit tracker — unit-tested
/// in test/credit_test.dart.
class CreditMath {
  CreditMath._();

  static int daysUntil(CreditEntry entry, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return DateTime(
      entry.deadline.year,
      entry.deadline.month,
      entry.deadline.day,
    ).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  /// Settled obligations are never "overdue" — they are closed.
  static bool isOverdue(CreditEntry entry, {DateTime? now}) =>
      !entry.isSettled && daysUntil(entry, now: now) < 0;

  /// The open (unsettled) subset — what the totals, deadlines and AI
  /// prompts care about.
  static List<CreditEntry> openOnly(List<CreditEntry> credits) =>
      credits.where((c) => !c.isSettled).toList();

  /// Human deadline label: "Overdue by N days", "Due today",
  /// "Due tomorrow", "Due in N days" (next two weeks) or a date.
  static String deadlineLabel(CreditEntry entry, {DateTime? now}) {
    final days = daysUntil(entry, now: now);
    if (days < 0) {
      final overdue = -days;
      return overdue == 1 ? 'Overdue by 1 day' : 'Overdue by $overdue days';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days <= 13) return 'Due in $days days';
    return 'Due ${formatDate(entry.deadline)}';
  }

  /// Deterministic d/M/yyyy formatting (kept locale-free so the pure
  /// helpers stay unit-testable without intl).
  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Outstanding totals only — settled entries are skipped so the strip
  /// shows what is still owed / still to come back.
  static ({double borrowed, double lent, double net}) totals(
    List<CreditEntry> credits,
  ) {
    var borrowed = 0.0;
    var lent = 0.0;
    for (final c in credits) {
      if (c.isSettled) continue;
      if (c.direction == CreditDirection.borrowed) {
        borrowed += c.amount;
      } else {
        lent += c.amount;
      }
    }
    return (borrowed: borrowed, lent: lent, net: lent - borrowed);
  }

  /// Overdue entries first (most overdue at the top), then soonest
  /// deadline first. Settled entries sink to the bottom — kept visible as
  /// history, but never ahead of an open obligation.
  static List<CreditEntry> sortedForDisplay(
    List<CreditEntry> credits, {
    DateTime? now,
  }) {
    final list = [...credits];
    list.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      return daysUntil(a, now: now).compareTo(daysUntil(b, now: now));
    });
    return list;
  }

  // ------------------------------------------------------------------
  // WhatsApp follow-up templates
  // ------------------------------------------------------------------

  /// Pre-filled follow-up message for the counterparty. [friendly]
  /// picks the warm nudge; otherwise the formal reminder.
  static String followUpMessage(CreditEntry entry, {bool friendly = true}) {
    final name = entry.counterpartyName.trim();
    final amount = MoneyFormat.format(
      entry.amount,
      symbol: '${entry.currency} ',
    );
    final due = formatDate(entry.deadline);

    if (entry.direction == CreditDirection.borrowed) {
      if (friendly) {
        return 'Hi $name 👋 Just checking in — I\'ll settle the $amount '
            'I owe you by $due. Thanks for your patience!';
      }
      return 'Hello $name, this is a reminder that $amount borrowed on '
          '${formatDate(entry.startDate)} is due on $due. Please let me '
          'know your preferred repayment date.';
    }
    if (friendly) {
      return 'Hi $name 👋 Hope you\'re well! A gentle nudge about the '
          '$amount you borrowed — due $due, whenever works for you, '
          'thanks!';
    }
    return 'Hello $name, this is a reminder that $amount lent on '
        '${formatDate(entry.startDate)} was due on $due. Please arrange '
        'repayment at your earliest convenience.';
  }

  /// wa.me deep link for [phone] with a pre-filled [message]. The
  /// phone number is stripped to digits (country code, no "+").
  static Uri whatsappLink(String phone, String message) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return Uri.parse(
      'https://wa.me/$digits?text='
      '${Uri.encodeComponent(message)}',
    );
  }

  /// wa.me deep link carrying the chosen follow-up template.
  static Uri followUpLink(CreditEntry entry, {bool friendly = true}) =>
      whatsappLink(
        entry.counterpartyPhone ?? '',
        followUpMessage(entry, friendly: friendly),
      );
}
