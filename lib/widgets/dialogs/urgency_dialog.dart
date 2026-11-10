import 'package:flutter/material.dart';

import '../../models/expiry_item.dart';
import '../../theme/app_theme.dart';

class UrgencyDialog extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback? onAction;

  const UrgencyDialog({super.key, required this.item, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = item.daysRemaining <= 7;
    final urgencyColor = FinavigColors.urgencyColor(item.daysRemaining);
    final urgencyBg = FinavigColors.urgencyBg(
      item.daysRemaining,
      brightness: theme.brightness,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.dialog),
      ),
      title: Row(
        children: [
          Icon(
            isCritical
                ? Icons.warning_amber_rounded
                : Icons.notifications_active_rounded,
            color: urgencyColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            isCritical ? 'Urgent renewal needed' : 'Renewal reminder',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            item.displayName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.docType.displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: urgencyBg,
              borderRadius: BorderRadius.circular(FinavigRadius.tile / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCritical
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_rounded,
                  color: urgencyColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  item.daysRemaining <= 0
                      ? 'Expired'
                      : '${item.daysRemaining} days until expiry',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: urgencyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            // Same fallback as the detail screen's renewal card.
            item.effectiveRenewalWarning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (item.renewalSteps != null && item.renewalSteps!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Renewal steps:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ...item.renewalSteps!.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Text(
                      '${entry.key + 1}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Dismiss',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onAction?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isCritical
                ? FinavigColors.danger
                : theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FinavigRadius.button),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: Text(isCritical ? 'Take action now' : 'Start renewal'),
        ),
      ],
    );
  }
}
