import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/finance.dart';
import '../services/bank_notification_parser.dart';
import '../services/collection_service.dart';
import '../services/finance_service.dart';
import '../services/pending_transaction_service.dart';
import '../services/transaction_notification_listener.dart';
import '../theme/app_theme.dart';
import 'bento_icon_tile.dart';

/// Overlay that shows a confirmation card when a banking notification is
/// detected. The card slides in from the top with the parsed transaction
/// pre-filled, and the user can confirm (✓) or dismiss (✕) with one tap.
///
/// Wrap this around your main app scaffold (inside [MaterialApp.builder]).
class TransactionDetectionOverlay extends StatefulWidget {
  final Widget child;

  const TransactionDetectionOverlay({super.key, required this.child});

  @override
  State<TransactionDetectionOverlay> createState() =>
      _TransactionDetectionOverlayState();
}

class _TransactionDetectionOverlayState
    extends State<TransactionDetectionOverlay> with TickerProviderStateMixin {
  StreamSubscription<PendingTransaction>? _subscription;
  PendingTransaction? _currentPending;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _subscription = TransactionNotificationListener
        .instance.onTransactionDetected
        .listen(_onDetected);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _autoDismissTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onDetected(PendingTransaction pending) {
    if (!mounted) return;
    // If a card is already showing, queue this one (the pending service keeps it)
    if (_currentPending != null) return;

    setState(() => _currentPending = pending);
    _slideController.forward();
    HapticFeedback.mediumImpact();

    // Auto-dismiss after 30 seconds
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _currentPending != null) {
        _dismissCard();
      }
    });
  }

  Future<void> _confirmTransaction() async {
    final pending = _currentPending;
    if (pending == null) return;

    HapticFeedback.lightImpact();

    // Log it as a real transaction
    final tx = FinanceTransaction(
      id: const Uuid().v4(),
      collectionId: DocumentCollectionService.instance.personalCollectionId,
      kind: pending.parsed.kind,
      category: pending.parsed.category,
      title: pending.parsed.merchant,
      amount: pending.parsed.amount,
      currency: pending.parsed.currency,
      occurredAt: pending.parsed.receivedAt,
      note:
          '${pending.parsed.bankName}${pending.parsed.cardSuffix != null ? ' ${pending.parsed.cardSuffix}' : ''} · Auto-detected',
    );

    await FinanceService.instance.addTransaction(tx);
    await PendingTransactionService.instance.markConfirmed(pending.id);

    await _hideCard();
    _showNextPendingIfAny();
  }

  Future<void> _dismissCard() async {
    final pending = _currentPending;
    if (pending == null) return;

    HapticFeedback.lightImpact();
    await PendingTransactionService.instance.markDismissed(pending.id);
    await _hideCard();
    _showNextPendingIfAny();
  }

  Future<void> _hideCard() async {
    _autoDismissTimer?.cancel();
    await _slideController.reverse();
    if (mounted) {
      setState(() => _currentPending = null);
    }
  }

  void _showNextPendingIfAny() {
    final nextPending = PendingTransactionService.instance.pending;
    if (nextPending.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _onDetected(nextPending.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentPending != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnimation,
              child: _DetectionCard(
                pending: _currentPending!,
                pulseAnimation: _pulseController,
                onConfirm: _confirmTransaction,
                onDismiss: _dismissCard,
              ),
            ),
          ),
      ],
    );
  }
}

/// The actual card UI for a detected transaction.
class _DetectionCard extends StatelessWidget {
  final PendingTransaction pending;
  final AnimationController pulseAnimation;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _DetectionCard({
    required this.pending,
    required this.pulseAnimation,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parsed = pending.parsed;
    final isExpense = parsed.kind == FinanceKind.expense;

    // Card colors
    final cardBg = isDark ? FinavigColors.charcoal : Colors.white;
    final borderColor = isExpense
        ? (isDark ? Colors.red.shade300 : Colors.red.shade200)
        : (isDark ? Colors.green.shade300 : Colors.green.shade200);
    final accentColor = isExpense ? Colors.red.shade400 : Colors.green.shade500;
    final subtleAccent = isExpense
        ? (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50)
        : (isDark
            ? Colors.green.shade900.withValues(alpha: 0.3)
            : Colors.green.shade50);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row: live dot + label ─────────────────────────
              Row(
                children: [
                  // Animated pulse dot
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(
                              alpha: 0.6 + (pulseAnimation.value * 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(
                                  alpha: pulseAnimation.value * 0.5),
                              blurRadius: 6 + (pulseAnimation.value * 4),
                              spreadRadius: pulseAnimation.value * 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transaction Detected',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  // Bank badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: subtleAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      parsed.bankName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Body: icon + merchant + amount ───────────────────────
              Row(
                children: [
                  // Category icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: subtleAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      parsed.category.icon,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Merchant + category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed.merchant,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : FinavigColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              parsed.category.displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: isDark
                                    ? FinavigColors.textSecondary
                                    : FinavigColors.textMutedLight,
                              ),
                            ),
                            if (parsed.cardSuffix != null) ...[
                              Text(
                                '  •  ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? FinavigColors.textSecondary
                                      : FinavigColors.textMutedLight,
                                ),
                              ),
                              Text(
                                parsed.cardSuffix!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: isDark
                                      ? FinavigColors.textSecondary
                                      : FinavigColors.textMutedLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isExpense ? '-' : '+'}${parsed.currency} ${_formatAmount(parsed.amount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: accentColor,
                        ),
                      ),
                      if (parsed.availableBalance != null)
                        Text(
                          'Bal: ${parsed.currency} ${_formatAmount(parsed.availableBalance!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: isDark
                                ? FinavigColors.textSecondary
                                : FinavigColors.textMutedLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Action buttons ──────────────────────────────────────
              Row(
                children: [
                  // Dismiss
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.close_rounded,
                      label: 'Dismiss',
                      color: isDark ? FinavigColors.slate : FinavigColors.fog,
                      textColor: isDark
                          ? FinavigColors.textSecondary
                          : FinavigColors.textMutedLight,
                      onTap: onDismiss,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Confirm
                  Expanded(
                    flex: 2,
                    child: _ActionButton(
                      icon: Icons.check_rounded,
                      label: 'Log Transaction',
                      color: accentColor,
                      textColor: Colors.white,
                      filled: true,
                      onTap: onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (m) => '${m[1]},',
        );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: color, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? textColor : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? textColor : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pending Transactions List Widget (for Money tab or Settings) ──────────

/// Full list of pending transactions for batch review.
class PendingTransactionsList extends StatefulWidget {
  final bool isBottomSheet;

  const PendingTransactionsList({super.key, this.isBottomSheet = true});

  @override
  State<PendingTransactionsList> createState() =>
      _PendingTransactionsListState();
}

class _PendingTransactionsListState extends State<PendingTransactionsList> {
  @override
  void initState() {
    super.initState();
    PendingTransactionService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    PendingTransactionService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pending = PendingTransactionService.instance.pending;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? FinavigColors.charcoal : Colors.white;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
      child: Row(
        children: [
          const BentoIconTile(
            icon: Icons.notifications_active_rounded,
            color: FinavigColors.accent,
            size: 38,
            iconSize: 20,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pending Review Queue',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : FinavigColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pending.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: FinavigColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pending.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: FinavigColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pending.isEmpty
                      ? 'All detected alerts have been reviewed'
                      : 'Swipe right to log, left to dismiss',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: isDark
                        ? FinavigColors.textSecondary
                        : FinavigColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          if (pending.isNotEmpty)
            TextButton(
              onPressed: () => _confirmAll(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Log All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FinavigColors.logoGreen,
                ),
              ),
            ),
          if (widget.isBottomSheet)
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );

    final emptyContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FinavigColors.logoGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 30,
              color: FinavigColors.logoGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'All Caught Up!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : FinavigColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No banking transactions awaiting review.\nNew SMS and push notifications will appear here automatically.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? FinavigColors.textSecondary
                  : FinavigColors.textMutedLight,
              height: 1.4,
            ),
          ),
          if (widget.isBottomSheet) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );

    final listContent = Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final p = pending[index];
          return _PendingRow(
            pending: p,
            onConfirm: () => _confirm(p),
            onDismiss: () => _dismiss(p),
          );
        },
      ),
    );

    if (!widget.isBottomSheet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Divider(
            height: 1,
            color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
          ),
          if (pending.isEmpty) emptyContent else listContent,
        ],
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              header,
              Divider(
                height: 1,
                color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              ),
              if (pending.isEmpty) emptyContent else listContent,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(PendingTransaction pending) async {
    HapticFeedback.lightImpact();
    final tx = FinanceTransaction(
      id: const Uuid().v4(),
      collectionId: DocumentCollectionService.instance.personalCollectionId,
      kind: pending.parsed.kind,
      category: pending.parsed.category,
      title: pending.parsed.merchant,
      amount: pending.parsed.amount,
      currency: pending.parsed.currency,
      occurredAt: pending.parsed.receivedAt,
      note:
          '${pending.parsed.bankName}${pending.parsed.cardSuffix != null ? ' ${pending.parsed.cardSuffix}' : ''} · Auto-detected',
    );
    await FinanceService.instance.addTransaction(tx);
    await PendingTransactionService.instance.markConfirmed(pending.id);
  }

  Future<void> _dismiss(PendingTransaction pending) async {
    HapticFeedback.lightImpact();
    await PendingTransactionService.instance.markDismissed(pending.id);
  }

  Future<void> _confirmAll(BuildContext context) async {
    final pending = PendingTransactionService.instance.pending;
    for (final p in pending) {
      await _confirm(p);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pending.length} transactions logged'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _PendingRow extends StatelessWidget {
  final PendingTransaction pending;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _PendingRow({
    required this.pending,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final parsed = pending.parsed;
    final isExpense = parsed.kind == FinanceKind.expense;
    final accentColor = isExpense ? Colors.red.shade400 : Colors.green.shade500;

    return Dismissible(
      key: ValueKey(pending.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onConfirm();
          return true;
        } else {
          onDismiss();
          return true;
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text('Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade500,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            SizedBox(width: 6),
            Icon(Icons.close_rounded, color: Colors.white),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? FinavigColors.slate : FinavigColors.cloud,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                parsed.category.icon,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parsed.merchant,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : FinavigColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${parsed.bankName}  •  ${parsed.category.displayName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? FinavigColors.textSecondary
                          : FinavigColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              '${isExpense ? '-' : '+'}${parsed.currency} ${parsed.amount.toStringAsFixed(parsed.amount == parsed.amount.truncateToDouble() ? 0 : 2)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── iOS SMS Paste Import Widget ──────────────────────────────────────────

/// A text field + parse button for iOS users to paste banking SMS text.
class SmsPasteImport extends StatefulWidget {
  final VoidCallback? onTransactionAdded;
  final bool isBottomSheet;

  const SmsPasteImport({
    super.key,
    this.onTransactionAdded,
    this.isBottomSheet = true,
  });

  @override
  State<SmsPasteImport> createState() => _SmsPasteImportState();
}

class _SmsPasteImportState extends State<SmsPasteImport> {
  final _controller = TextEditingController();
  ParsedBankNotification? _preview;
  bool _parseAttempted = false;
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parseAttempted = false;
        _preview = null;
      });
      return;
    }

    final parsed = TransactionNotificationListener.instance.parseText(text);
    setState(() {
      _parseAttempted = true;
      _preview = parsed;
    });
  }

  Future<void> _confirm() async {
    if (_preview == null) return;
    setState(() => _processing = true);

    final tx = FinanceTransaction(
      id: const Uuid().v4(),
      collectionId: DocumentCollectionService.instance.personalCollectionId,
      kind: _preview!.kind,
      category: _preview!.category,
      title: _preview!.merchant,
      amount: _preview!.amount,
      currency: _preview!.currency,
      occurredAt: _preview!.receivedAt,
      note: '${_preview!.bankName} · Imported from SMS',
    );

    await FinanceService.instance.addTransaction(tx);

    if (mounted) {
      setState(() {
        _processing = false;
        _preview = null;
        _controller.clear();
        _parseAttempted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${tx.title} · ${tx.currency} ${tx.amount.toStringAsFixed(tx.amount == tx.amount.truncateToDouble() ? 0 : 2)} to Personal',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onTransactionAdded?.call();

      if (widget.isBottomSheet) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? FinavigColors.charcoal : Colors.white;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtitle / instructions
          Text(
            'Copy any transaction SMS or banking alert from your phone and paste it below. Finavig will automatically parse the amount, merchant, and category into your Personal Account.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? FinavigColors.textSecondary
                  : FinavigColors.textMutedLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Input field container
          Container(
            decoration: BoxDecoration(
              color: isDark ? FinavigColors.slate : FinavigColors.cloud,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: isDark ? Colors.white : FinavigColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Purchase of AED 142.50 with card **4092 at CARREFOUR…',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? FinavigColors.textSecondary.withValues(alpha: 0.6)
                          : FinavigColors.textMutedLight,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    if (_preview != null || _parseAttempted) {
                      setState(() {
                        _preview = null;
                        _parseAttempted = false;
                      });
                    }
                  },
                ),
                // Quick paste bar at the bottom of the input container
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FinavigColors.slateLight.withValues(alpha: 0.4)
                        : FinavigColors.mist.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null &&
                              data!.text!.trim().isNotEmpty) {
                            _controller.text = data.text!.trim();
                            _parse();
                          }
                        },
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text(
                          'Paste from clipboard',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: FinavigColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Detect Transaction button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _parse,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Detect Transaction',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: FinavigColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // Failed parse notice
          if (_parseAttempted && _preview == null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not detect transaction details. Ensure the text includes an amount (e.g. AED 120) and merchant or bank name.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Preview card
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _PreviewCard(
              parsed: _preview!,
              processing: _processing,
              onConfirm: _confirm,
            ),
          ],
        ],
      ),
    );

    if (!widget.isBottomSheet) {
      return content;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                child: Row(
                  children: [
                    const BentoIconTile(
                      icon: Icons.content_paste_rounded,
                      color: FinavigColors.orange,
                      size: 38,
                      iconSize: 18,
                      radius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Paste Bank SMS / Alert',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : FinavigColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manually parse transaction text',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: isDark
                                  ? FinavigColors.textSecondary
                                  : FinavigColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? FinavigColors.slateLight : FinavigColors.fog,
              ),

              Flexible(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ParsedBankNotification parsed;
  final bool processing;
  final VoidCallback onConfirm;

  const _PreviewCard({
    required this.parsed,
    required this.processing,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = parsed.kind == FinanceKind.expense;
    final accentColor = isExpense ? Colors.red.shade400 : Colors.green.shade500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.charcoal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(parsed.category.icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.merchant,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${parsed.bankName}  •  ${parsed.category.displayName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? FinavigColors.textSecondary
                            : FinavigColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isExpense ? '-' : '+'}${parsed.currency} ${parsed.amount.toStringAsFixed(parsed.amount == parsed.amount.truncateToDouble() ? 0 : 2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: processing ? null : onConfirm,
              icon: processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(processing ? 'Logging…' : 'Log Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
