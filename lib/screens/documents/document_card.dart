import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/indicators/department_logo.dart';

/// One document in the list — a flat row on the canvas, not a card.
///
/// The list reads as a divided ledger: the logo chip, then the document
/// identity, a muted subtitle (type + expiry date), the urgency line
/// (countdown + status pill + renewal facts), a slim urgency bar and an
/// urgent-only warning. Rows are separated by hairlines in
/// [DocumentsScreen]; there is deliberately no white rectangle around each
/// one. Actions open via long-press or the small ⋯ button.
class DocumentCard extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const DocumentCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  /// Urgency accent for a row. Expired documents keep the danger accent even
  /// when `daysRemaining` reaches other bands. Light/dark variants go through
  /// [FinavigTransition] so the colour cross-fades with the theme instead of
  /// snapping at its halfway point.
  Color _accent(FinavigTransition fade) {
    final days = item.daysRemaining;
    if (days < 0 || days <= 7) {
      return fade.color(const Color(0xFFDC2626), FinavigColors.danger);
    }
    if (days <= 30) {
      return fade.color(const Color(0xFFD97706), FinavigColors.warning);
    }
    if (days <= 60) {
      return fade.color(const Color(0xFFB45309), FinavigColors.caution);
    }
    return fade.color(const Color(0xFF059669), FinavigColors.safe);
  }

  String get _statusLabel {
    final days = item.daysRemaining;
    if (days < 0) return 'Expired ${-days}d ago';
    if (days <= 7) return 'Due now';
    if (days <= 30) return 'This month';
    if (days <= 60) return 'Within 60 days';
    return 'On track';
  }

  /// Headline countdown shown on the row.
  String get _daysLabel => item.daysRemaining < 0
      ? '${-item.daysRemaining}d overdue'
      : '${item.daysRemaining}d left';

  /// Fraction of the tracking window already elapsed (0 → just renewed,
  /// 1 → expiring now). Approximates urgency visually.
  double get _timeProgress {
    if (item.daysRemaining < 0) return 1.0;
    final window = item.docType.typicalRenewalDays;
    if (window <= 0) return 0;
    return (1 - item.daysRemaining / window).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final accent = _accent(fade);
    final currency = DocumentCollectionService.instance.activeCurrency;

    return InkWell(
      onTap: onTap,
      onLongPress: onAction,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DepartmentLogo(item: item, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Identity.
                  Text(
                    item.displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: fade.color(
                        FinavigColors.textPrimaryLight,
                        FinavigColors.textPrimary,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Type + exact expiry date.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${item.docType.displayName} · Expires '
                          '${ExpiryItem.formatDate(item.expiresAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Urgency line: countdown, status pill, then the renewal
                  // facts — wraps instead of clipping on narrow screens.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        _daysLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: accent,
                        ),
                      ),
                      _StatusPill(
                        label: _statusLabel,
                        color: accent,
                        fade: fade,
                      ),
                      if ((item.renewalFee ?? 0) > 0)
                        _meta(
                          fade,
                          Icons.payments_outlined,
                          'Fee $currency ${item.renewalFee!.toStringAsFixed(0)}',
                          strong: true,
                        ),
                      _meta(
                        fade,
                        Icons.account_balance_rounded,
                        item.docType.renewalAuthority,
                      ),
                      if (item.location != null)
                        _meta(fade, Icons.location_on_outlined, item.location!),
                      if (item.assignedTo != null)
                        _meta(
                          fade,
                          Icons.person_outline_rounded,
                          'Owner: ${item.assignedTo}',
                        ),
                    ],
                  ),
                  // Slim urgency bar — status at a glance.
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _timeProgress,
                      minHeight: 3,
                      backgroundColor: fade.color(
                        FinavigColors.mist,
                        Colors.white.withValues(alpha: 0.08),
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  // Renewal warning — expiry-aware fallback keeps this
                  // meaningful even when no warning was stored. Shown only
                  // when it matters (≤30 days).
                  if (item.daysRemaining <= 30) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.effectiveRenewalWarning,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Compact inline actions trigger.
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                onPressed: onAction,
                tooltip: 'Actions',
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: fade.color(
                    FinavigColors.textMutedLight,
                    FinavigColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(
    FinavigTransition fade,
    IconData icon,
    String text, {
    bool strong = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: fade.color(
            FinavigColors.textMutedLight,
            FinavigColors.textMuted,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: strong
                ? fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textPrimary,
                  )
                : fade.color(
                    FinavigColors.textMutedLight,
                    FinavigColors.textMuted,
                  ),
            fontSize: 11.5,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Tiny tinted pill carrying a document's status word ("Due now", "On track").
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final FinavigTransition fade;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.fade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: fade.value(0.10, 0.18)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
