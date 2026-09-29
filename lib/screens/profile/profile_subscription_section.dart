import 'package:flutter/material.dart';

import '../../models/document_collection.dart';
import '../../models/subscription_tier.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs/upgrade_dialog.dart';
import 'profile_sections.dart';

/// Subscription section of the Profile (Settings) screen — plan badge,
/// expiry countdown, usage meters, upgrade/renew action.
class ProfileSubscriptionSection extends StatefulWidget {
  final List<DocumentCollection> collections;

  const ProfileSubscriptionSection({super.key, required this.collections});

  @override
  State<ProfileSubscriptionSection> createState() =>
      _ProfileSubscriptionSectionState();
}

class _ProfileSubscriptionSectionState
    extends State<ProfileSubscriptionSection> {
  /// One-tick-later guard so the FutureBuilder doesn't re-fire the count on
  /// every rebuild (usage only changes when documents change).
  Future<int>? _documentCount;

  Future<int> _countDocuments() =>
      EntitlementService.instance.documentsInUse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entitlements = EntitlementService.instance;
    final tier = entitlements.tier;
    final info = TierInfo.all[tier]!;
    final limits = entitlements.limits;
    final isTopTier = TierInfo.nextTierUp(tier) == null;
    final planEndsAt = entitlements.planEndsAt;
    final daysLeft = entitlements.daysUntilPlanExpiry();
    final isExpired = entitlements.isPlanExpired;
    final isPaid = tier != SubscriptionTier.free && planEndsAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profileTileBg(theme),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TierBadge(tier: tier),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        info.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Plan expiry countdown (fetched from user_tiers.plan_ends_at).
                if (isPaid && !isExpired && daysLeft != null) ...[
                  const SizedBox(height: 10),
                  ProfilePlanNotice(
                    icon: daysLeft <= 7
                        ? Icons.notification_important_rounded
                        : Icons.event_available_rounded,
                    color:
                        daysLeft <= 7 ? FinavigColors.warning : FinavigColors.safe,
                    text: daysLeft == 0
                        ? 'Your ${info.name} plan expires today'
                        : 'Your ${info.name} plan expires in $daysLeft '
                              'day${daysLeft == 1 ? '' : 's'} — '
                              '${formatProfileDate(planEndsAt)}',
                  ),
                ],
                // Expired plan: warn + nudge to renew.
                if (isExpired) ...[
                  const SizedBox(height: 10),
                  ProfilePlanNotice(
                    icon: Icons.error_outline_rounded,
                    color: FinavigColors.danger,
                    text: 'Your ${info.name} plan expired on '
                        '${formatProfileDate(planEndsAt!)} — features are locked '
                        'again. Tap Renew Plan to resubscribe.',
                  ),
                ],
                const SizedBox(height: 12),
                // Usage meters: documents + company workspaces, mirrored from
                // the free-tier limits.
                FutureBuilder<int>(
                  future: _documentCount ??= _countDocuments(),
                  builder: (context, snap) {
                    final used = snap.data ?? 0;
                    final max = limits.maxDocuments;
                    final companyUsed = widget.collections
                        .where((c) => !c.isPersonal)
                        .length;
                    final maxCompany = limits.maxCompanyCollections;
                    // Hide the workspaces meter on Free (cap 0, none in use) —
                    // a permanent empty bar is noise, not information.
                    final showCompanyMeter =
                        companyUsed > 0 || (maxCompany != null && maxCompany > 0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileUsageMeter(
                          label: 'Documents',
                          used: used,
                          max: max,
                        ),
                        if (showCompanyMeter) ...[
                          const SizedBox(height: 8),
                          ProfileUsageMeter(
                            label: 'Company workspaces',
                            used: companyUsed,
                            max: maxCompany,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (!isTopTier)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showTierRequestSheet(context),
                      icon: const Icon(Icons.upgrade_rounded, size: 18),
                      label: Text(isExpired
                          ? 'Renew Plan'
                          : isPaid
                              ? 'Extend Plan'
                              : 'Upgrade Plan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FinavigColors.navyPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Text(
                    'You are on the highest plan — thanks for supporting Finavig!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FinavigColors.safe,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
