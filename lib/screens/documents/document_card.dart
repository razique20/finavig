import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/indicators/department_logo.dart';

/// Document card — urgency-tinted left edge, then a scannable hierarchy of
/// the main details: document identity, headline days-remaining with status,
/// exact expiry date, renewal fee and authority, slim progress bar and an
/// urgent-only warning. Actions open via long-press or the small ⋯ button.
/// Extracted from `documents_screen.dart` so the list rebuilds per card.
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

  Color _accentColor(bool isDark) {
    final days = item.daysRemaining;
    if (isDark) {
      if (days <= 7) return FinavigColors.danger;
      if (days <= 30) return FinavigColors.warning;
      if (days <= 60) return FinavigColors.caution;
      return FinavigColors.safe;
    } else {
      if (days <= 7) return const Color(0xFFDC2626); // Dark red
      if (days <= 30) return const Color(0xFFD97706); // Dark amber
      if (days <= 60) return const Color(0xFFB45309); // Dark ochre
      return const Color(0xFF059669); // Dark emerald
    }
  }

  /// Accent used for the left edge tint. Expired documents keep the danger
  /// accent even when `daysRemaining` reaches other bands.
  Color _edgeAccent(bool isDark) =>
      item.daysRemaining < 0 ? FinavigColors.danger : _accentColor(isDark);

  String get _statusLabel {
    final days = item.daysRemaining;
    if (days < 0) return 'Expired ${-days}d ago';
    if (days <= 7) return 'Due now';
    if (days <= 30) return 'This month';
    if (days <= 60) return 'Within 60 days';
    return 'On track';
  }

  /// Headline countdown shown large on the card.
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
    final isDark = theme.brightness == Brightness.dark;
    final accent = _edgeAccent(isDark);

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.35)
          : Colors.white,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onAction,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? FinavigColors.slateLight.withOpacity(0.3)
                  : FinavigColors.fog.withOpacity(0.5),
            ),
          ),
          // IntrinsicHeight: the colored edge must stretch to the card's
          // height, but the card sits in an unbounded scroll context where
          // CrossAxisAlignment.stretch alone would force infinite height.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored urgency edge.
                Container(width: 4, color: accent.withOpacity(0.8)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: identity + menu.
                        Row(
                          children: [
                            DepartmentLogo(item: item, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark
                                          ? FinavigColors.textPrimary
                                          : FinavigColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.docType.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? FinavigColors.textMuted
                                          : FinavigColors.textSecondaryLight,
                                    ),
                                  ),
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
                                  color: isDark
                                      ? FinavigColors.cyanSecondary
                                      : FinavigColors.navyPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Headline: countdown + status on the left, exact
                        // expiry date on the right.
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _daysLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(
                                  isDark ? 0.15 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: isDark
                                        ? FinavigColors.textMuted
                                        : FinavigColors.textSecondaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Expires ${ExpiryItem.formatDate(item.expiresAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? FinavigColors.textSecondary
                                            : FinavigColors.textPrimaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Main facts: renewal fee first (the number people
                        // plan around), then authority and assignment.
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (item.renewalFee != null &&
                                item.renewalFee! > 0)
                              _detail(
                                theme,
                                Icons.payments_outlined,
                                'Fee ${DocumentCollectionService.instance.activeCurrency} ${item.renewalFee!.toStringAsFixed(0)}',
                                bold: true,
                              ),
                            _detail(
                              theme,
                              Icons.account_balance_rounded,
                              item.docType.renewalAuthority,
                            ),
                            if (item.location != null)
                              _detail(
                                theme,
                                Icons.location_on_outlined,
                                item.location!,
                              ),
                            if (item.assignedTo != null)
                              _detail(
                                theme,
                                Icons.person_outline_rounded,
                                'Owner: ${item.assignedTo}',
                              ),
                          ],
                        ),
                        // Slim progress bar — urgency at a glance.
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _timeProgress,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                : FinavigColors.mist,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        // Renewal warning — expiry-aware fallback keeps this
                        // meaningful even when no warning was stored. Shown
                        // only when it matters (≤30 days).
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(
    ThemeData theme,
    IconData icon,
    String text, {
    bool bold = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final color = bold
        ? (isDark ? FinavigColors.textPrimary : FinavigColors.textPrimaryLight)
        : (isDark
            ? FinavigColors.textSecondary
            : FinavigColors.textPrimaryLight);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark
              ? FinavigColors.textMuted
              : FinavigColors.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
