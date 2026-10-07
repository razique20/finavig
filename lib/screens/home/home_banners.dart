import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';

/// Amber banner shown when the plan expired or collections are locked.
/// Extracted from `home_screen.dart` (guarded by
/// `plan_restriction_and_collection_locking_test.dart`).
class HomePlanRestrictionBanner extends StatelessWidget {
  const HomePlanRestrictionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final entitlements = EntitlementService.instance;
    final isExpired = entitlements.isPlanExpired;
    final lockedCount = entitlements.lockedCollectionsCount;

    if (!isExpired && lockedCount == 0) {
      return const SizedBox.shrink();
    }

    // Resolved through the theme transition factor so the banner cross-fades
    // with the light↔dark animation instead of snapping halfway through it.
    final fade = FinavigTransition.of(context);
    final bannerBg = fade.color(FinavigColors.amberTint, const Color(0xFF2A2110));
    const iconColor = FinavigColors.amber;
    final textColor = fade.color(const Color(0xFF92400E), Colors.white);
    final subtitleColor =
        fade.color(const Color(0xFFB45309), const Color(0xFFFDE68A));

    final title = isExpired
        ? 'Subscription plan expired'
        : '$lockedCount collection${lockedCount == 1 ? '' : 's'} locked';
    final subtitle = isExpired
        ? 'Renew your plan to unlock all workspaces and premium features.'
        : 'Your current plan limits company collections. Upgrade to unlock all.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: () => showTierRequestSheet(context),
        borderRadius: BorderRadius.circular(FinavigRadius.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(FinavigRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: fade.value(0.15, 0.18)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: iconColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: fade.color(FinavigColors.ink, Colors.white),
                  foregroundColor: fade.color(Colors.white, FinavigColors.ink),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => showTierRequestSheet(context),
                child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red banner listing documents that need attention — collapses to zero
/// height when nothing is urgent or the user dismissed this exact count.
/// The dismiss callback receives the pending count so the banner stays
/// hidden until the data changes.
class HomeAttentionBanner extends StatelessWidget {
  final List<String> pendingActionNames;
  final int? dismissedAttentionCount;
  final void Function(int pendingCount) onDismiss;

  const HomeAttentionBanner({
    super.key,
    required this.pendingActionNames,
    required this.dismissedAttentionCount,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingActionNames;
    // Nothing urgent, or the user closed this exact alert count: render
    // nothing. (The old green "all on track" banner was dropped — the hero
    // header already carries the status, and it left a phantom gap.)
    if (pending.isEmpty || dismissedAttentionCount == pending.length) {
      return const SizedBox.shrink();
    }
    // Resolved through the theme transition factor so the banner cross-fades
    // with the light↔dark animation instead of snapping halfway through it.
    final fade = FinavigTransition.of(context);

    final bannerBg = fade.color(const Color(0xFFFEF2F2), const Color(0xFF451A1A));
    final bannerBorder = fade.color(
      const Color(0xFFFCA5A5),
      const Color(0xFFEF4444).withValues(alpha: 0.4),
    );
    final iconColor = fade.color(const Color(0xFFDC2626), const Color(0xFFF87171));
    final textColor = fade.color(const Color(0xFF991B1B), Colors.white);
    final subtitleColor =
        fade.color(const Color(0xFFB91C1C), const Color(0xFFFCA5A5));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: () => context.go('/documents'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pending.length} renewal${pending.length == 1 ? '' : 's'} need attention',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pending.take(2).join(', ') +
                          (pending.length > 2 ? ' +${pending.length - 2}' : ''),
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withOpacity(0.7),
              ),
              if (pending.isNotEmpty)
                // Close button: hides the banner until the pending count
                // changes (or the app restarts).
                Tooltip(
                  message: 'Dismiss alert',
                  child: InkWell(
                    onTap: () => onDismiss(pending.length),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red-tinted alert card summarising documents already past expiry, tapping
/// through to the most urgent one.
class HomeExpiredAlert extends StatelessWidget {
  final List<HomeExpiredItem> expiredItems;

  const HomeExpiredAlert({super.key, required this.expiredItems});

  @override
  Widget build(BuildContext context) {
    if (expiredItems.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final expired = expiredItems;
    final worst = expired.first;

    // Dark mode uses the deep-red surface + lighter accent (same treatment as
    // [HomeAttentionBanner]); light mode keeps the soft red tint. Resolved
    // through the theme transition factor so the swap cross-fades.
    final fade = FinavigTransition.of(context);
    final cardBg = fade.color(FinavigColors.redTint, FinavigColors.dangerBg);
    final accentColor =
        fade.color(FinavigColors.red, const Color(0xFFFCA5A5));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: InkWell(
        onTap: () => context.push('/document/${worst.id}'),
        borderRadius: BorderRadius.circular(FinavigRadius.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(FinavigRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${expired.length} document${expired.length == 1 ? '' : 's'} already expired',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expired.length == 1
                          ? '${worst.displayName} — expired ${-worst.daysRemaining} day${-worst.daysRemaining == 1 ? '' : 's'} ago'
                          : 'Most urgent: ${worst.displayName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fade.color(
                          theme.colorScheme.outline,
                          const Color(0xFFFECACA),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal expired-document view model for [HomeExpiredAlert] — decouples
/// the banner from the full [ExpiryItem] model.
class HomeExpiredItem {
  final String id;
  final String displayName;
  final int daysRemaining;

  const HomeExpiredItem({
    required this.id,
    required this.displayName,
    required this.daysRemaining,
  });
}
