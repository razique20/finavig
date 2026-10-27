import 'package:flutter/material.dart';

import '../../models/document_folder.dart';
import '../../models/expiry_item.dart';
import '../../models/subscription_tier.dart';
import '../../services/document_folder_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/create_folder_dialog.dart';
import '../dialogs/upgrade_dialog.dart';

/// Flat, card-free ledger row for a folder inside the Documents workspace.
///
/// Matches Finavig's divided-row aesthetic: icon chip, folder name, document count,
/// rollup urgency badge, and chevron/options.
class FolderListTile extends StatelessWidget {
  final DocumentFolder folder;
  final List<ExpiryItem> items;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const FolderListTile({
    super.key,
    required this.folder,
    required this.items,
    required this.onTap,
    required this.onAction,
  });

  /// Computes the highest priority urgency among documents inside this folder.
  UrgencyLevel? get _highestUrgency {
    if (items.isEmpty) return null;
    var highest = items.first.urgency;
    for (final item in items) {
      if (item.urgency.priority > highest.priority) {
        highest = item.urgency;
      }
    }
    return highest;
  }

  /// Nearest upcoming document in this folder.
  ExpiryItem? get _nearestDue {
    if (items.isEmpty) return null;
    final active = items.where((i) => i.isActive).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return active.isEmpty ? null : active.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final urgency = _highestUrgency;
    final nearest = _nearestDue;

    // Subtitle preview: doc count and summary
    final subtitleText = items.isEmpty
        ? '0 documents · Empty folder'
        : items.length == 1
            ? '1 document · ${items.first.displayName}'
            : '${items.length} documents · ${items.take(2).map((i) => i.displayName).join(", ")}${items.length > 2 ? "..." : ""}';

    return InkWell(
      onTap: onTap,
      onLongPress: onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Folder Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: folder.color.withValues(alpha: isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: folder.color.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(
                folder.iconData,
                color: folder.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Title & Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          folder.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pill showing count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: folder.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${items.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: folder.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textMuted,
                      ),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Urgency Rollup Badge (if any active item)
            if (nearest != null && urgency != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: urgency.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: urgency.color.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(urgency.icon, size: 12, color: urgency.color),
                    const SizedBox(width: 4),
                    Text(
                      nearest.daysRemaining < 0
                          ? '${-nearest.daysRemaining}d overdue'
                          : '${nearest.daysRemaining}d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: urgency.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Action / Chevron
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: fade.color(
                  FinavigColors.textMutedLight,
                  FinavigColors.textMuted,
                ),
              ),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action row button to add a new folder or prompt upgrade if limit reached.
class AddFolderListTile extends StatelessWidget {
  final int currentCount;
  final ValueChanged<DocumentFolder>? onFolderCreated;

  const AddFolderListTile({
    super.key,
    required this.currentCount,
    this.onFolderCreated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entitlements = EntitlementService.instance;
    final isFree = entitlements.tier == SubscriptionTier.free;
    final maxFolders = entitlements.limits.maxFolders;
    final atLimit = maxFolders != null && currentCount >= maxFolders;

    final hintText = isFree
        ? 'Unlock custom folders with Plus'
        : atLimit
            ? 'Folder limit reached ($maxFolders/$maxFolders) · Upgrade to Business'
            : maxFolders != null
                ? '$currentCount of $maxFolders folders used'
                : 'Unlimited folders with Business';

    return InkWell(
      onTap: () async {
        if (isFree) {
          await showUpgradeDialog(context, EntitlementFeature.documentFolders);
        } else if (atLimit) {
          await showUpgradeDialog(
            context,
            EntitlementFeature.documentFolders,
            requestedTier: SubscriptionTier.business,
          );
        } else {
          final created = await showCreateFolderDialog(context);
          if (created != null && onFolderCreated != null) {
            onFolderCreated!(created);
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? FinavigColors.slate.withValues(alpha: 0.5)
                    : FinavigColors.cloud,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isFree || atLimit)
                      ? Colors.amber.shade700.withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                  width: 1,
                ),
              ),
              child: Icon(
                isFree || atLimit
                    ? Icons.lock_outline_rounded
                    : Icons.create_new_folder_outlined,
                color: (isFree || atLimit)
                    ? Colors.amber.shade700
                    : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFree
                        ? 'Create custom folder'
                        : atLimit
                            ? 'Create new folder'
                            : 'New folder',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (isFree || atLimit)
                          ? Colors.amber.shade800
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hintText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: fade.color(
                        FinavigColors.textMutedLight,
                        FinavigColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isFree || atLimit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFree ? 'PLUS' : 'UPGRADE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
