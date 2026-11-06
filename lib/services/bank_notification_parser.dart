import '../models/finance.dart';
import 'collection_service.dart';
import 'smart_category_engine.dart';

/// A transaction parsed from a banking notification.
class ParsedBankNotification {
  /// The raw notification body text.
  final String rawText;

  /// The app package name that posted the notification (Android only).
  final String? packageName;

  /// Bank name inferred from package name or notification content.
  final String bankName;

  /// Whether this is a debit (expense) or credit (income).
  final FinanceKind kind;

  /// The transaction amount.
  final double amount;

  /// The currency code (AED, SAR, etc.).
  final String currency;

  /// The merchant / description / payee.
  final String merchant;

  /// Auto-categorised finance category.
  final FinanceCategory category;

  /// Masked card number if present (e.g. "**1234").
  final String? cardSuffix;

  /// Available balance after the transaction, if mentioned.
  final double? availableBalance;

  /// Reference number if present.
  final String? referenceNumber;

  /// When the notification was received.
  final DateTime receivedAt;

  /// Confidence score 0.0–1.0 that this is a real transaction notification
  /// (vs. a promotional SMS or OTP).
  final double confidence;

  const ParsedBankNotification({
    required this.rawText,
    this.packageName,
    required this.bankName,
    required this.kind,
    required this.amount,
    this.currency = 'AED',
    required this.merchant,
    required this.category,
    this.cardSuffix,
    this.availableBalance,
    this.referenceNumber,
    required this.receivedAt,
    this.confidence = 0.85,
  });

  /// True if confidence is high enough to show to the user.
  bool get isViable => confidence >= 0.6;

  @override
  String toString() =>
      'ParsedBankNotification($bankName ${kind.name} $currency $amount @ $merchant, '
      'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Parses raw banking notification text into structured transaction data.
///
/// Covers GCC/UAE banks: ADCB, FAB, ENBD, Mashreq, DIB, CBD, RAKBank, ADIB,
/// HSBC, Standard Chartered, Citi, NBF, Commercial Bank of Dubai, Al Masraf,
/// Ajman Bank, UAB, etc. Also handles generic formats from Saudi, Kuwait,
/// Bahrain, Oman and Qatar banks.
class BankNotificationParser {
  BankNotificationParser._();
  static final BankNotificationParser instance = BankNotificationParser._();

  // ── Known banking app packages ──────────────────────────────────────────
  static const Map<String, String> _packageToBank = {
    'com.adcb.bank': 'ADCB',
    'com.adcbmobiletoken': 'ADCB',
    'ae.adcb.android': 'ADCB',
    'com.fab.mobile': 'FAB',
    'com.fab.android': 'FAB',
    'ae.fab.mobile': 'FAB',
    'com.firstabudhabibank.fab': 'FAB',
    'com.enbd.mobilebanking': 'Emirates NBD',
    'ae.emiratesnbd.android': 'Emirates NBD',
    'com.emiratesnbd.enbd': 'Emirates NBD',
    'com.mashreq.mob': 'Mashreq',
    'com.mashreqbank.mob': 'Mashreq',
    'ae.mashreq.android': 'Mashreq',
    'com.dib.app': 'DIB',
    'ae.dib.android': 'DIB',
    'com.cbd.mobile': 'CBD',
    'ae.cbd.android': 'CBD',
    'com.rakbank.mobile': 'RAKBank',
    'ae.rakbank.android': 'RAKBank',
    'com.adib.mobile': 'ADIB',
    'ae.adib.android': 'ADIB',
    'com.hsbc.uae': 'HSBC',
    'com.sc.uae': 'Standard Chartered',
    'com.citi.mobile': 'Citi',
    'com.nbf.mobile': 'NBF',
    'com.almasraf.mobile': 'Al Masraf',
    'com.ajmanbank.mobile': 'Ajman Bank',
    'com.uab.mobile': 'UAB',
    // Saudi
    'com.alrajhi.mobile': 'Al Rajhi',
    'com.snb.mobile': 'SNB',
    'com.riyad.mobile': 'Riyad Bank',
    'com.alinma.mobile': 'Alinma Bank',
    // Generic SMS apps that carry bank alerts
    'com.google.android.apps.messaging': '_sms',
    'com.samsung.android.messaging': '_sms',
    'com.android.mms': '_sms',
  };

  // ── Bank name detection from notification text ──────────────────────────
  static const Map<String, String> _textToBank = {
    'adcb': 'ADCB',
    'abu dhabi commercial': 'ADCB',
    'first abu dhabi': 'FAB',
    'fab ': 'FAB',
    'emirates nbd': 'ENBD',
    'emiratesnbd': 'ENBD',
    'enbd': 'ENBD',
    'mashreq': 'Mashreq',
    'mashreqbank': 'Mashreq',
    'dubai islamic': 'DIB',
    'dib ': 'DIB',
    'commercial bank of dubai': 'CBD',
    'cbd ': 'CBD',
    'rakbank': 'RAKBank',
    'rak bank': 'RAKBank',
    'abu dhabi islamic': 'ADIB',
    'adib ': 'ADIB',
    'hsbc': 'HSBC',
    'standard chartered': 'Standard Chartered',
    'citibank': 'Citi',
    'national bank of fujairah': 'NBF',
    'al masraf': 'Al Masraf',
    'ajman bank': 'Ajman Bank',
    'al rajhi': 'Al Rajhi',
    'saudi national bank': 'SNB',
    'snb ': 'SNB',
    'riyad bank': 'Riyad Bank',
    'alinma': 'Alinma Bank',
  };

  /// Try to parse a notification into a bank transaction.
  /// Returns null if the notification doesn't look like a banking alert.
  ParsedBankNotification? tryParse({
    required String text,
    String? packageName,
    String? title,
    DateTime? receivedAt,
  }) {
    if (text.isEmpty) return null;

    final combined = '${title ?? ''} $text';
    final lower = combined.toLowerCase();

    // ── Reject non-transactional messages ────────────────────────────────
    if (_isPromotional(lower)) return null;
    if (_isOtp(lower)) return null;

    // ── Identify bank ───────────────────────────────────────────────────
    final bankName = _identifyBank(packageName, lower);
    if (bankName == null) return null;

    // ── Extract amount ──────────────────────────────────────────────────
    final amountResult = _extractAmount(combined);
    if (amountResult == null) return null;
    final (amount, currency) = amountResult;

    // ── Determine kind (debit vs credit) ────────────────────────────────
    final kind = _extractKind(lower);

    // ── Extract merchant ────────────────────────────────────────────────
    final merchant = _extractMerchant(combined, lower);

    // ── Extract card suffix ─────────────────────────────────────────────
    final cardSuffix = _extractCardSuffix(combined);

    // ── Extract available balance ───────────────────────────────────────
    final availableBalance = _extractAvailableBalance(combined);

    // ── Extract reference number ────────────────────────────────────────
    final referenceNumber = _extractReference(combined);

    // ── Auto-categorise ─────────────────────────────────────────────────
    var prediction = SmartCategoryEngine.instance.predict(
      merchant,
      kind: kind,
    );
    if (!prediction.isHighConfidence) {
      final fallback = SmartCategoryEngine.instance.predict(
        combined,
        kind: kind,
      );
      if (fallback.isHighConfidence || prediction.category == FinanceCategory.other) {
        prediction = fallback;
      }
    }
    final category = prediction.category;

    // ── Confidence scoring ──────────────────────────────────────────────
    var confidence = 0.7;
    if (amount > 0) confidence += 0.1;
    if (merchant.isNotEmpty && merchant != 'Transaction') confidence += 0.1;
    if (cardSuffix != null) confidence += 0.05;
    if (availableBalance != null) confidence += 0.05;

    return ParsedBankNotification(
      rawText: text,
      packageName: packageName,
      bankName: bankName,
      kind: kind,
      amount: amount,
      currency: currency,
      merchant: merchant.isNotEmpty ? merchant : 'Transaction',
      category: category,
      cardSuffix: cardSuffix,
      availableBalance: availableBalance,
      referenceNumber: referenceNumber,
      receivedAt: receivedAt ?? DateTime.now(),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  String? _identifyBank(String? packageName, String lower) {
    // 1. From package name
    if (packageName != null) {
      final fromPkg = _packageToBank[packageName.toLowerCase()];
      if (fromPkg != null && fromPkg != '_sms') return fromPkg;
    }

    // 2. From notification text
    for (final entry in _textToBank.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // 3. Generic banking keywords (SMS or pasted bank alert)
    if (_hasTransactionKeywords(lower)) {
      return 'Bank';
    }

    return null;
  }

  bool _hasTransactionKeywords(String lower) {
    return lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('purchase') ||
        lower.contains('payment of') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred') ||
        lower.contains('received') ||
        lower.contains('salary') ||
        lower.contains('card ending') ||
        lower.contains('ending in') ||
        lower.contains('debit card') ||
        lower.contains('credit card') ||
        lower.contains('mada card') ||
        lower.contains('account **') ||
        lower.contains('account has been') ||
        lower.contains('txn') ||
        lower.contains('transaction') ||
        lower.contains('avl bal') ||
        lower.contains('avail bal') ||
        lower.contains('available balance');
  }

  bool _isPromotional(String lower) {
    final promoKeywords = [
      'offer',
      'cashback offer',
      'earn points',
      'apply now',
      'exclusive deal',
      'limited time',
      'upgrade your',
      'pre-approved',
      'congratulations',
      'you have been selected',
      'win a',
      'click here to',
      'subscribe',
      'unsubscribe',
    ];
    var promoHits = 0;
    for (final kw in promoKeywords) {
      if (lower.contains(kw)) promoHits++;
    }
    // A single "offer" mention alongside transaction keywords is ok (e.g.
    // "Your purchase of AED 250 at Store. Earn 3x points on this offer").
    // But 2+ promo keywords = promotional.
    return promoHits >= 2;
  }

  bool _isOtp(String lower) {
    return (lower.contains('otp') && lower.contains('do not share')) ||
        lower.contains('one time password') ||
        lower.contains('verification code') ||
        RegExp(r'\b\d{4,6}\b.*do not share', caseSensitive: false)
            .hasMatch(lower);
  }

  static const String _currencyPattern =
      r'(?:AED|SAR|KWD|QAR|BHD|OMR|USD|EUR|GBP|INR|Dhs?\.?|DH\.?|Dirhams?|SR\.?|KD\.?|QR\.?|BD\.?|RO\.?|Rs\.?|[\$€£₹])';

  String _normalizeCurrency(String raw) {
    var c = raw.trim().toUpperCase().replaceAll('.', '');
    if (c == 'DHS' || c == 'DH' || c == 'DIRHAM' || c == 'DIRHAMS') return 'AED';
    if (c == 'SR' || c == 'RIYAL' || c == 'RIYALS') return 'SAR';
    if (c == 'KD') return 'KWD';
    if (c == 'QR') return 'QAR';
    if (c == 'BD') return 'BHD';
    if (c == 'RO') return 'OMR';
    if (c == r'$') return 'USD';
    if (c == '€') return 'EUR';
    if (c == '£') return 'GBP';
    if (c == '₹' || c == 'RS') return 'INR';
    return c;
  }

  /// Extracts the transaction amount and currency with GCC-aware normalization.
  (double, String)? _extractAmount(String text) {
    // Pattern 1: Currency before amount: "AED 1,234.56" or "Dhs. 150.00" or "$45.50"
    final currencyFirstRegex = RegExp(
      '($_currencyPattern)\\s*([\\d,]+(?:\\.\\d{1,2})?)\\b',
      caseSensitive: false,
    );
    final m1 = currencyFirstRegex.firstMatch(text);
    if (m1 != null) {
      final curr = _normalizeCurrency(m1.group(1)!);
      final val = double.tryParse(m1.group(2)!.replaceAll(',', ''));
      if (val != null && val > 0) return (val, curr);
    }

    // Pattern 2: Currency after amount: "1,234.56 AED" or "150 Dhs"
    final amountFirstRegex = RegExp(
      '\\b([\\d,]+(?:\\.\\d{1,2})?)\\s*($_currencyPattern)\\b',
      caseSensitive: false,
    );
    final m2 = amountFirstRegex.firstMatch(text);
    if (m2 != null) {
      final val = double.tryParse(m2.group(1)!.replaceAll(',', ''));
      final curr = _normalizeCurrency(m2.group(2)!);
      if (val != null && val > 0) return (val, curr);
    }

    // Pattern 3: Amount after action keywords: "debited by 150.00" / "spent 200"
    final kwAmountRegex = RegExp(
      '(?:debited|credited|purchase\\s+of|payment\\s+of|spent|amount\\s+of|withdrawn|transferred)\\s*:?\\s*(?:$_currencyPattern)?\\s*([\\d,]+(?:\\.\\d{1,2})?)',
      caseSensitive: false,
    );
    final m3 = kwAmountRegex.firstMatch(text);
    if (m3 != null) {
      final val = double.tryParse(m3.group(1)!.replaceAll(',', ''));
      if (val != null && val > 0) {
        // Find if currency exists anywhere in the text
        final anyCurr =
            RegExp(_currencyPattern, caseSensitive: false).firstMatch(text);
        final curr = anyCurr != null
            ? _normalizeCurrency(anyCurr.group(0)!)
            : DocumentCollectionService.instance.activeCurrency;
        return (val, curr);
      }
    }

    return null;
  }

  FinanceKind _extractKind(String lower) {
    // Credit indicators
    if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('salary') ||
        lower.contains('deposit') ||
        lower.contains('refund') ||
        lower.contains('reversal') ||
        lower.contains('incoming') ||
        lower.contains('credit alert')) {
      return FinanceKind.income;
    }
    // Default: debit/expense
    return FinanceKind.expense;
  }

  String _extractMerchant(String text, String lower) {
    // Pattern 1: "at MERCHANT_NAME" or "at MERCHANT NAME."
    final atRegex = RegExp(
      r"\bat\s+([A-Za-z0-9][A-Za-z0-9\s&\-'\.]{1,40}?)(?:\s*[,\.]|\s+on\s|\s+for\s|\s+using\s|\s+with\s|\s+ref|\s+Avl|\s+Bal|\s*$)",
      caseSensitive: false,
    );
    final atMatch = atRegex.firstMatch(text);
    if (atMatch != null) {
      return _cleanMerchant(atMatch.group(1)!);
    }

    // Pattern 2: "to MERCHANT_NAME" (for transfers)
    final toRegex = RegExp(
      r"\bto\s+([A-Za-z][A-Za-z0-9\s&\-'\.]{1,40}?)(?:\s*[,\.]|\s+on\s|\s+ref|\s+Avl|\s+Bal|\s*$)",
      caseSensitive: false,
    );
    final toMatch = toRegex.firstMatch(text);
    if (toMatch != null) {
      final candidate = _cleanMerchant(toMatch.group(1)!);
      // Exclude card-number-like matches
      if (!RegExp(r'^\*{2}\d{4}$').hasMatch(candidate)) {
        return candidate;
      }
    }

    // Pattern 3: "from SENDER" (for income)
    final fromRegex = RegExp(
      r"\bfrom\s+([A-Za-z][A-Za-z0-9\s&\-'\.]{1,40}?)(?:\s*[,\.]|\s+on\s|\s+ref|\s+Avl|\s+Bal|\s*$)",
      caseSensitive: false,
    );
    final fromMatch = fromRegex.firstMatch(text);
    if (fromMatch != null) {
      return _cleanMerchant(fromMatch.group(1)!);
    }

    // Pattern 4: "for BILL/MERCHANT" (e.g. for DEWA electricity payment)
    final forRegex = RegExp(
      r"\bfor\s+([A-Za-z][A-Za-z0-9\s&\-'\.]{1,40}?)(?:\s+(?:bill|payment|electricity|service)|\s*[,\.]|\s+on\s|\s+ref|\s+Avl|\s+Bal|\s*$)",
      caseSensitive: false,
    );
    final forMatch = forRegex.firstMatch(text);
    if (forMatch != null) {
      return _cleanMerchant(forMatch.group(1)!);
    }

    return '';
  }

  String _cleanMerchant(String raw) {
    var cleaned = raw.trim();
    // Strip trailing periods
    while (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    // Strip leading "the"
    if (cleaned.toLowerCase().startsWith('the ')) {
      cleaned = cleaned.substring(4);
    }
    // Limit length
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40);
    return cleaned;
  }

  String? _extractCardSuffix(String text) {
    // "**1234", "x1234", "ending 1234", "card ending in 1234"
    final patterns = [
      RegExp(r'\*{2,}(\d{4})\b'),
      RegExp(r'\bx(\d{4})\b', caseSensitive: false),
      RegExp(r'ending\s+(?:in\s+)?(\d{4})\b', caseSensitive: false),
      RegExp(r'card\s*#?\s*\d*\*+(\d{4})\b'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return '**${m.group(1)}';
    }
    return null;
  }

  double? _extractAvailableBalance(String text) {
    final balRegex = RegExp(
      r'(?:Avl\.?\s*Bal\.?|Available\s+Balance|Avail\.?\s*Bal\.?|Bal\.?)\s*:?\s*(?:AED|SAR|KWD|QAR|BHD|OMR|USD|EUR|GBP)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final m = balRegex.firstMatch(text);
    if (m != null) {
      return double.tryParse(m.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  String? _extractReference(String text) {
    final refRegex = RegExp(
      r'(?:Ref\.?\s*(?:No\.?|#)?|Reference\s*#?)\s*:?\s*([A-Za-z0-9]{6,20})',
      caseSensitive: false,
    );
    final m = refRegex.firstMatch(text);
    return m?.group(1);
  }
}
