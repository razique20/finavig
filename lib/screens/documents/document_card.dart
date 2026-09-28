import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../services/collection_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/indicators/department_logo.dart';

/// Detailed document card — compact, urgency-tinted left accent, time
/// progress bar, detail wrap, and an inline Actions button. Extracted from
/// `documents_screen.dart` so the list rebuilds per card.
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

  /// Fraction of the tracking window already elapsed (0 → just renewed,
  /// 1 → expiring now). Approximates urgency visually.
  double get _timeProgress {
    if (item.daysRemaining < 0) return 1.0;
    final window = item.docType.typicalRenewalDays;
    if (window <= 0) return 0;
    return (1 - item.daysRemaining / window).clamp(0.0, 1.0);
  }

  /// Human explanation of what the reminder tier means.
  String get _reminderText {
    switch (item.reminderStatus) {
      case 4:
        return 'Final alert — renew immediately';
      case 3:
        return 'Active reminders — renew this month';
      case 2:
        return 'Early reminders — plan ahead';
      case 1:
        return 'Monitoring — plenty of time left';
      default:
        return 'No reminders yet';
    }
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
                        // Header row.
                        Row(
                          children: [
                            DepartmentLogo(item: item, size: 44),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.daysRemaining < 0
                                      ? '${-item.daysRemaining}d overdue'
                                      : '${item.daysRemaining}d left',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: accent,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
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
                              ],
                            ),
                          ],
                        ),
                        // Time-remaining progress bar.
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _timeProgress,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                : FinavigColors.mist,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeProgress >= 1.0
                              ? 'Renewal window fully elapsed'
                              : '${(100 - _timeProgress * 100).toStringAsFixed(0)}% of the renewal window left',
                          style: TextStyle(
                            color: isDark
                                ? FinavigColors.textMuted
                                : FinavigColors.textMutedLight,
                            fontSize: 10,
                          ),
                        ),
                        // Detail rows.
                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: isDark
                              ? FinavigColors.slateLight.withOpacity(0.3)
                              : FinavigColors.fog.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _detail(
                              theme,
                              Icons.calendar_today_rounded,
                              'Expires ${ExpiryItem.formatDate(item.expiresAt)}',
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
                            if (item.renewalFee != null && item.renewalFee! > 0)
                              _detail(
                                theme,
                                Icons.payments_outlined,
                                'Renewal fee ${DocumentCollectionService.instance.activeCurrency} ${item.renewalFee!.toStringAsFixed(0)}',
                              ),
                            _detail(
                              theme,
                              Icons.notifications_active_outlined,
                              _reminderText,
                            ),
                          ],
                        ),
                        // Renewal warning — expiry-aware fallback keeps this
                        // meaningful even when no warning was stored.
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
                        // Inline actions.
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onAction,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: isDark
                                      ? FinavigColors.cyanSecondary
                                      : FinavigColors.navyPrimary,
                                ),
                                label: Text(
                                  'Actions',
                                  style: TextStyle(
                                    color: isDark
                                        ? FinavigColors.cyanSecondary
                                        : FinavigColors.navyPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  side: BorderSide(
                                    color: isDark
                                        ? FinavigColors.cyanSecondary
                                            .withOpacity(0.4)
                                        : FinavigColors.navyPrimary
                                            .withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _detail(ThemeData theme, IconData icon, String text) {
    final isDark = theme.brightness == Brightness.dark;
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
            color: isDark
                ? FinavigColors.textSecondary
                : FinavigColors.textPrimaryLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
