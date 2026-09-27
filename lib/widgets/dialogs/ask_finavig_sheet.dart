import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/expiry_item.dart';
import '../../models/finance.dart';
import '../../services/ai_intent_router_service.dart';
import '../../services/collection_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/finance_service.dart';
import '../../services/natural_language_parser_service.dart';
import '../../services/voice_input_service.dart';
import '../../theme/app_theme.dart';
import 'companion_suggestion_sheet.dart';
import 'upgrade_dialog.dart';

/// Result of the unified "Ask Finavig AI" sheet.
sealed class AskFinavigResult {
  const AskFinavigResult();
}

/// A money record the user confirmed (NOT yet persisted — see [_saveMoney]).
class AskMoneyResult extends AskFinavigResult {
  final FinanceTransaction transaction;
  final RecurringTransaction? recurringTemplate;
  const AskMoneyResult(this.transaction, {this.recurringTemplate});
}

/// A document the user confirmed (already persisted by the sheet, mirroring
/// the old document dialog's contract).
class AskDocumentResult extends AskFinavigResult {
  final ExpiryItem item;
  const AskDocumentResult(this.item);
}

/// The user picked a flow manually or edited text; nothing was saved.
class AskCancelled extends AskFinavigResult {
  const AskCancelled();
}

/// Unified "Ask Finavig AI" universal voice sheet.
///
/// One entry point for both quick-add flows: the user types or speaks one
/// natural sentence ("Log DEWA bill of 450 AED", "Add Emirates ID expiring
/// 14 Oct 2027") and the sheet routes it — local lexicon first, Groq AI only
/// for the ambiguous remainder — parses it with the existing NL parsers, and
/// shows a confirmation card before saving.
///
/// Replaces [NaturalLanguageMoneyAddDialog] and [NaturalLanguageAddDialog]
/// (both removed); their save logic lives here unchanged, minus the old
/// double-add bug: money results are returned unpersisted so the caller adds
/// them exactly once through [FinanceService.addTransaction].
class AskFinavigSheet extends StatefulWidget {
  const AskFinavigSheet({super.key});

  /// Opens the sheet above the root navigator.
  static Future<AskFinavigResult?> show(BuildContext context) {
    return showModalBottomSheet<AskFinavigResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AskFinavigSheet(),
    );
  }

  @override
  State<AskFinavigSheet> createState() => _AskFinavigSheetState();
}

class _AskFinavigSheetState extends State<AskFinavigSheet> {
  late final TextEditingController _inputController;
  final FocusNode _inputFocus = FocusNode();

  AskRouting _routing = AskRouting.fallback;
  ParsedMoneyItem? _money;
  ParsedNaturalLanguageItem? _document;
  bool _isRouting = false;
  bool _isSaving = false;
  Timer? _debounce;

  // Voice input state (shared VoiceInputService).
  bool _isListening = false;
  String _voicePartial = '';
  StreamSubscription<VoiceStatus>? _voiceStatusSub;
  StreamSubscription<VoiceUpdate>? _voiceTranscriptSub;

  String get _currency => DocumentCollectionService.instance.activeCurrency;

  List<String> get _samples => [
        'Log DEWA bill of 450 $_currency',
        'Add Emirates ID expiring 14 Oct 2027',
        'Received 12,000 $_currency client payment yesterday',
        'Mulkiya expires next month, cost 800 $_currency',
      ];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputController.addListener(_onInputChanged);
    _voiceStatusSub =
        VoiceInputService.instance.statusStream.listen(_onVoiceStatus);
    _voiceTranscriptSub =
        VoiceInputService.instance.transcriptStream.listen(_onVoiceUpdate);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _voiceStatusSub?.cancel();
    _voiceTranscriptSub?.cancel();
    VoiceInputService.instance.stopListening();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Voice
  // --------------------------------------------------------------------------

  void _onVoiceStatus(VoiceStatus status) {
    if (!mounted) return;
    setState(() {
      _isListening = VoiceInputService.instance.isListening;
      if (!_isListening) _voicePartial = '';
    });
    if (status == VoiceStatus.unavailable) {
      _showSnack(
        VoiceInputService.instance.lastError ?? 'Voice input is not available.',
        error: true,
      );
    }
  }

  void _onVoiceUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.text.isNotEmpty) {
      // Final transcript: normalize spoken numbers/currency into the field;
      // the controller listener routes + parses automatically.
      final normalized = VoiceInputService.normalizeTranscript(update.text);
      _inputController.text = normalized;
      setState(() => _voicePartial = '');
      _inputFocus.requestFocus();
    } else if (update.partialText.isNotEmpty) {
      setState(() {
        _voicePartial = VoiceInputService.normalizeTranscript(update.partialText);
      });
    }
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await VoiceInputService.instance.stopListening();
      return;
    }
    FocusScope.of(context).unfocus();
    final started = await VoiceInputService.instance.startListening();
    if (started && mounted) {
      setState(() {
        _isListening = true;
        _voicePartial = '';
      });
    }
  }

  // --------------------------------------------------------------------------
  // Routing + parsing
  // --------------------------------------------------------------------------

  void _onInputChanged() {
    _debounce?.cancel();
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _routing = AskRouting.fallback;
        _money = null;
        _document = null;
        _isRouting = false;
      });
      return;
    }
    // Small debounce so mid-sentence typing doesn't spam the router.
    _debounce = Timer(const Duration(milliseconds: 250), () => _analyze(text));
  }

  Future<void> _analyze(String text) async {
    setState(() => _isRouting = true);
    final routing = await AiIntentRouterService.instance.route(text);

    // Input changed (or cleared) while routing — drop the stale result.
    if (!mounted || _inputController.text.trim() != text) return;

    switch (routing.intent) {
      case AskIntent.logMoney:
        setState(() {
          _routing = routing;
          _money = NaturalLanguageParserService.instance.parseMoney(text);
          _document = null;
          _isRouting = false;
        });
      case AskIntent.addDocument:
        setState(() {
          _routing = routing;
          _document = NaturalLanguageParserService.instance.parse(text);
          _money = null;
          _isRouting = false;
        });
      case AskIntent.unclear:
        setState(() {
          _routing = routing;
          _money = null;
          _document = null;
          _isRouting = false;
        });
    }
  }

  /// User overrode the routed flow from the unclear/confirmation UI.
  void _forceFlow(AskIntent intent) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _routing = AskRouting(
        intent: intent,
        confidence: 1,
        source: AskRoutingSource.localKeywords,
      );
      if (intent == AskIntent.logMoney) {
        _money = NaturalLanguageParserService.instance.parseMoney(text);
        _document = null;
      } else {
        _document = NaturalLanguageParserService.instance.parse(text);
        _money = null;
      }
    });
  }

  // --------------------------------------------------------------------------
  // Save: money (returned unpersisted — caller adds exactly once)
  // --------------------------------------------------------------------------

  Future<void> _saveMoney() async {
    final item = _money;
    if (item == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final collectionId = DocumentCollectionService.instance.activeCollectionId;
      final newTransaction = FinanceTransaction(
        id: const Uuid().v4(),
        collectionId: collectionId,
        kind: item.kind,
        category: item.category,
        title: item.title,
        amount: item.amount,
        currency: item.currency,
        occurredAt: item.occurredAt,
        note: 'Added via Ask Finavig AI: "${item.rawInput}"',
      );

      RecurringTransaction? recurringTemplate;
      if (item.isRecurring) {
        recurringTemplate = RecurringTransaction(
          id: const Uuid().v4(),
          collectionId: collectionId,
          kind: item.kind,
          category: item.category,
          title: item.title,
          amount: item.amount,
          currency: item.currency,
          frequency: item.frequency,
          dayOfMonth: item.dayOfMonth,
          startDate: item.occurredAt,
        );
      } else {
        // Duplicate guard (same as TransactionFormSheet).
        final duplicate = FinanceMath.findDuplicateTransaction(
          FinanceService.instance.activeTransactions,
          newTransaction,
        );
        if (duplicate != null && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Possible Duplicate Transaction'),
              content: Text(
                'A similar expense "${duplicate.title}" (${MoneyFormat.aed(duplicate.amount)}) was already logged. Log this record anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Log Anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        AskMoneyResult(newTransaction, recurringTemplate: recurringTemplate),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not prepare the record: $e', error: true);
      setState(() => _isSaving = false);
    }
  }

  // --------------------------------------------------------------------------
  // Save: document (persisted here, mirroring the old dialog's contract)
  // --------------------------------------------------------------------------

  Future<void> _saveDocument() async {
    final item = _document;
    if (item == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final daysOffset = item.expiryDate.difference(now).inDays;
      final docId = const Uuid().v4();

      final newItem = ExpiryItem(
        id: docId,
        collectionId: DocumentCollectionService.instance.activeCollectionId,
        displayName: item.title,
        docType: item.docType,
        expiryDate: DateFormat('dd MMM yyyy').format(item.expiryDate),
        daysRemaining: daysOffset,
        isExpired: daysOffset < 0,
        isNotified: false,
        notifiedDays: null,
        description: 'Added via Ask Finavig AI: "${item.rawInput}"',
        location: item.authority,
        reminderStatus: _reminderStatus(daysOffset),
        urgency: _urgency(daysOffset),
        assignedTo: null,
        documentDate: DateFormat('dd MMM yyyy').format(now),
        renewalFee: item.renewalFee,
        renewalSteps: [
          'Gather required documentation',
          'Prepare renewal application',
          'Submit to relevant authority',
          'Pay renewal fees',
          'Receive renewed document',
        ],
        renewalAuthorities: [item.authority],
        renewalWarning:
            daysOffset <= 30 ? 'Expires soon — renew to avoid penalties' : null,
        expiresAt: item.expiryDate,
      );

      // Track 1 gate: respect the Free plan's 10-document quota.
      if (!await enforceDocumentLimit(context)) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      await DocumentScannerService.instance.addItem(newItem);

      if (!mounted) return;
      _showSnack('${newItem.displayName} saved & tracked!');
      Navigator.pop(context, AskDocumentResult(newItem));
      // Companion suggestions are best-effort and fire after the sheet
      // closes; the helper keeps the per-pick document-quota paywall intact.
      unawaited(_maybeSuggestCompanions(newItem));
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save document: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _maybeSuggestCompanions(ExpiryItem newItem) async {
    try {
      await CompanionSuggestionSheet.maybeSuggestCompanions(context, newItem);
    } catch (_) {
      // Suggestions are best-effort; never block the saved document.
    }
  }

  static UrgencyLevel _urgency(int days) {
    if (days <= 7) return UrgencyLevel.critical;
    if (days <= 30) return UrgencyLevel.high;
    if (days <= 60) return UrgencyLevel.medium;
    return UrgencyLevel.low;
  }

  static int _reminderStatus(int days) {
    if (days <= 7) return 4;
    if (days <= 30) return 3;
    if (days <= 60) return 2;
    if (days <= 90) return 1;
    return 0;
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? FinavigColors.danger : null,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? FinavigColors.charcoal : Colors.white;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FinavigRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildHeader(theme, isDark),
                const SizedBox(height: 16),
                if (_inputController.text.trim().isEmpty) ...[
                  _buildHandsFreeStrip(theme, isDark),
                  const SizedBox(height: 12),
                ],
                _buildInputField(theme),
                if (_isListening) ...[
                  const SizedBox(height: 10),
                  _buildListeningBanner(theme),
                ],
                const SizedBox(height: 12),
                _buildSampleChips(theme),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildBody(theme, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: FinavigGradients.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask Finavig AI',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Say or type it once — money or documents',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, const AskCancelled()),
        ),
      ],
    );
  }

  /// Hands-free first: a big tappable mic strip above an always-visible
  /// field, so typing never costs a mode switch.
  Widget _buildHandsFreeStrip(ThemeData theme, bool isDark) {
    return InkWell(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        onTap: _toggleVoice,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark
                ? FinavigColors.slate.withOpacity(0.55)
                : FinavigColors.cloud,
            borderRadius: BorderRadius.circular(FinavigRadius.field),
            border: Border.all(
              color: FinavigColors.accent.withOpacity(isDark ? 0.5 : 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FinavigColors.accent.withOpacity(isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded,
                    color: FinavigColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap to speak',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"Log DEWA bill of 450 $_currency"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_rounded,
                  size: 20, color: theme.colorScheme.outline),
            ],
          ),
        ),
      );
  }

  Widget _buildInputField(ThemeData theme) {
    return TextField(
      controller: _inputController,
      focusNode: _inputFocus,
      autofocus: false,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'e.g. Paid 450 $_currency for DEWA electricity yesterday',
        prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
        suffixIcon: _isRouting
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: _isListening ? 'Stop' : 'Speak instead',
                icon: Icon(
                  _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _isListening ? FinavigColors.danger : null,
                ),
                onPressed: _toggleVoice,
              ),
      ),
    );
  }

  Widget _buildListeningBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FinavigColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FinavigColors.danger.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _voicePartial.isEmpty
                  ? 'Listening… say e.g. "Add Emirates ID expiring 14 Oct 2027"'
                  : _voicePartial,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: _voicePartial.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => VoiceInputService.instance.stopListening(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _samples
            .map(
              (prompt) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _inputController.text = prompt;
                    _inputController.selection = TextSelection.fromPosition(
                      TextPosition(offset: prompt.length),
                    );
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    final key = ValueKey(
      '${_routing.intent.name}|${_money?.title}|${_document?.title}|${_routing.missingDate}',
    );

    if (_inputController.text.trim().isEmpty) {
      return _buildEmptyHint(theme, isDark, key);
    }
    if (_isRouting && _money == null && _document == null) {
      return _buildRoutingHint(theme, key);
    }
    if (_money != null) {
      return _moneyPreview(theme, isDark, key);
    }
    if (_document != null) {
      return _documentPreview(theme, isDark, key);
    }
    return _buildUnclearCard(theme, isDark, key);
  }

  Widget _buildEmptyHint(ThemeData theme, bool isDark, Key key) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinavigColors.accent.withOpacity(isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: FinavigColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'One sentence is enough — Finavig fills in the category, '
              'amount, date, or expiry automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingHint(ThemeData theme, Key key) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Working out what you meant…',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Money confirmation card
  // --------------------------------------------------------------------------

  Widget _moneyPreview(ThemeData theme, bool isDark, Key key) {
    final p = _money!;
    final isIn = p.kind == FinanceKind.income;
    final kindColor = isIn ? FinavigColors.safe : FinavigColors.danger;

    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinavigColors.accent.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinavigColors.accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.category.icon, color: FinavigColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _tag(theme, isDark, p.kind.label.toUpperCase(), kindColor),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 16, color: FinavigColors.accent),
              const SizedBox(width: 6),
              Text(
                MoneyFormat.aed(p.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: kindColor,
                ),
              ),
              const Spacer(),
              _tag(theme, isDark, p.category.displayName,
                  theme.colorScheme.outline),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd MMMM yyyy').format(p.occurredAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              if (p.isRecurring) ...[
                const Spacer(),
                _tag(theme, isDark, 'Recurring · ${p.frequency.label}',
                    FinavigColors.lilac),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _forceFlow(AskIntent.addDocument),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Document?'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (p.amount > 0 && !_isSaving) ? _saveMoney : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Confirm & Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Document confirmation card
  // --------------------------------------------------------------------------

  Widget _documentPreview(ThemeData theme, bool isDark, Key key) {
    final p = _document!;
    final days = p.expiryDate.difference(DateTime.now()).inDays;
    final urgencyColor = FinavigColors.urgencyColor(days);

    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinavigColors.accent.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinavigColors.accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.docType.icon, color: p.docType.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _tag(theme, isDark, p.docType.displayName, p.docType.primaryColor),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: FinavigColors.accent),
              const SizedBox(width: 6),
              Text(
                'Expiry: ${DateFormat('dd MMMM yyyy').format(p.expiryDate)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                days < 0 ? 'expired' : '$days days left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: urgencyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.map_rounded, size: 16, color: FinavigColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Authority: ${p.authority}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p.renewalFee != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.payments_outlined,
                    size: 16, color: FinavigColors.accent),
                const SizedBox(width: 4),
                Text(
                  '${p.renewalFee!.toStringAsFixed(0)} $_currency',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          // Expiry-alert promise: make the reminder ladder explicit.
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: urgencyColor.withOpacity(isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: 16, color: urgencyColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expiry alerts scheduled at 90 · 60 · 30 · 7 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: urgencyColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _forceFlow(AskIntent.logMoney),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Expense?'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveDocument,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Confirm & Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Unclear card: manual flow choice + how-to hint
  // --------------------------------------------------------------------------

  Widget _buildUnclearCard(ThemeData theme, bool isDark, Key key) {
    final note = _routing.note;
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.slate.withOpacity(0.5) : FinavigColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note ?? 'Which one is it?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _flowChoice(
                  theme,
                  isDark,
                  icon: Icons.receipt_long_rounded,
                  label: 'Money record',
                  onTap: () => _forceFlow(AskIntent.logMoney),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _flowChoice(
                  theme,
                  isDark,
                  icon: Icons.badge_rounded,
                  label: 'Document',
                  onTap: () => _forceFlow(AskIntent.addDocument),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowChoice(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: FinavigColors.accent.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FinavigColors.accent.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: FinavigColors.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: FinavigColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(ThemeData theme, bool isDark, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? color.withOpacity(0.95) : color,
        ),
      ),
    );
  }
}
