import 'package:flutter/material.dart';

import '../../models/subscription_tier.dart';
import '../../services/entitlement_service.dart';
import '../../services/upgrade_request_service.dart';
import '../../theme/app_theme.dart';

/// The Track 1 paywall.
///
/// Shown whenever a user hits a tier gate. Displays the locked feature, the
/// current tier and the tier that unlocks it, then offers exactly one
/// primary action: **Request Upgrade** — which opens the mail client with a
/// pre-filled request (user id, account email, current tier, requested tier,
/// feature, device, timestamp) addressed to
/// [UpgradeRequestService.supportEmail]. If no mail client is available the
/// message is copied to the clipboard instead.
///
/// Usage:
/// ```dart
/// if (!EntitlementService.instance.allows(EntitlementFeature.reportExport)) {
///   await showUpgradeDialog(context, EntitlementFeature.reportExport);
///   return;
/// }
/// ```
Future<void> showUpgradeDialog(
  BuildContext context,
  EntitlementFeature feature, {
  SubscriptionTier? requestedTier,
}) {
  return showDialog(
    context: context,
    useRootNavigator: true,
    builder: (ctx) =>
        UpgradeDialog(feature: feature, requestedTier: requestedTier),
  );
}

/// Convenience for the document-count gate: returns true when adding a
/// document is allowed; otherwise shows the paywall and returns false.
Future<bool> enforceDocumentLimit(
  BuildContext context, {
  int additional = 1,
}) async {
  final entitlements = EntitlementService.instance;
  final used = await entitlements.documentsInUse();
  if (entitlements.canAddDocuments(used, additional: additional)) return true;

  if (context.mounted) {
    await showUpgradeDialog(context, EntitlementFeature.moreDocuments);
  }
  return false;
}

/// Convenience for the company-collection gate: returns true when adding a
/// company collection is allowed; otherwise shows the paywall and returns false.
Future<bool> enforceCompanyCollectionLimit(
  BuildContext context, {
  int additional = 1,
}) async {
  final entitlements = EntitlementService.instance;
  final used = await entitlements.companyCollectionsInUse();
  if (entitlements.canAddCompanyCollections(used, additional: additional)) {
    return true;
  }

  if (context.mounted) {
    final feature = (entitlements.limits.maxCompanyCollections ?? 0) == 0
        ? EntitlementFeature.companyCollection
        : EntitlementFeature.multipleCompanyCollections;
    await showUpgradeDialog(context, feature);
  }
  return false;
}

/// General tier-upgrade sheet for the profile's subscription section: pick
/// Plus or Business, pick a billing period (1 / 3 / 12 months), then send the
/// pre-filled request email. The admin replies with a payment link; after
/// payment the tier + expiry are set in `user_tiers` and the app picks the
/// new plan up on the next Profile visit.
Future<void> showTierRequestSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _TierRequestSheet(),
  );
}

class _TierRequestSheet extends StatefulWidget {
  const _TierRequestSheet();

  @override
  State<_TierRequestSheet> createState() => _TierRequestSheetState();
}

class _TierRequestSheetState extends State<_TierRequestSheet> {
  PlanDuration _duration = PlanDuration.oneMonth;
  SubscriptionTier? _selected;

  /// Tiers above the current one — dynamic, so a Free user sees both Plus
  /// and Business while a Plus user only sees Business.
  List<SubscriptionTier> get _eligibleTiers {
    final current = EntitlementService.instance.tier;
    return [
      SubscriptionTier.plus,
      SubscriptionTier.business,
    ].where((t) => t > current).toList();
  }

  @override
  void initState() {
    super.initState();
    final tiers = _eligibleTiers;
    _selected = tiers.isEmpty ? null : tiers.first;
  }

  /// Single request action for whichever plan + billing period the user
  /// selected above.
  Future<void> _request(BuildContext context) async {
    final tier = _selected;
    if (tier == null) return;
    final info = TierInfo.all[tier]!;
    UpgradeRequestService.instance.logAttempt(null, tier);
    final launched = await UpgradeRequestService.instance.send(
      feature: null,
      requestedTier: tier,
      duration: _duration,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: launched ? Colors.green : FinavigColors.navyPrimary,
        content: Text(
          launched
              ? 'Request for ${info.name} (${_duration.label}) opened in '
                    'your mail app — just press send. You will receive a '
                    'payment link and the plan activates after payment.'
              : 'No mail app found — request copied to clipboard, paste it '
                    'into an email to ${UpgradeRequestService.supportEmail}',
        ),
      ),
    );
    if (launched && context.mounted) Navigator.of(context).pop();
  }

  /// "save X%" chip hint when the bundle beats paying monthly.
  String? _savingHint(SubscriptionTier tier, PlanDuration duration) {
    if (duration == PlanDuration.oneMonth) return null;
    final bundle = TierInfo.priceAed[tier]?[duration];
    final monthly = TierInfo.priceAed[tier]?[PlanDuration.oneMonth];
    if (bundle == null || monthly == null) return null;
    final total = monthly * duration.months;
    if (total <= bundle) return null;
    final pct = ((1 - bundle / total) * 100).round();
    return pct > 0 ? 'save $pct%' : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTier = EntitlementService.instance.tier;
    final planEndsAt = EntitlementService.instance.planEndsAt;
    final tiers = _eligibleTiers;
    final selectedInfo = _selected == null ? null : TierInfo.all[_selected]!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your plan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are on ${TierInfo.all[currentTier]!.name}'
                '${planEndsAt != null && currentTier != SubscriptionTier.free ? ' — ends ${_formatDate(planEndsAt)}' : ''}. '
                'Pick a plan and billing period, then send one request.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 14),
              // Plan tiles — one compact row each, tap to select.
              for (final tier in tiers) ...[
                _PlanTile(
                  info: TierInfo.all[tier]!,
                  selected: _selected == tier,
                  onTap: () => setState(() => _selected = tier),
                ),
                const SizedBox(height: 8),
              ],
              if (selectedInfo != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Billing period',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in PlanDuration.values)
                      ChoiceChip(
                        label: Text(
                          _savingHint(selectedInfo.tier, d) == null
                              ? d.label
                              : '${d.label} · ${_savingHint(selectedInfo.tier, d)}',
                        ),
                        selected: _duration == d,
                        onSelected: (_) => setState(() => _duration = d),
                        selectedColor:
                            FinavigColors.navyPrimary.withAlpha(46),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _duration == d
                              ? FinavigColors.navyPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        side: BorderSide(
                          color: _duration == d
                              ? FinavigColors.navyPrimary
                              : theme.colorScheme.outlineVariant,
                        ),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Live price summary for the current selection.
                _PriceSummaryCard(info: selectedInfo, duration: _duration),
                const SizedBox(height: 14),
                // One request action — reflects plan + duration above.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _request(context),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      'Request ${selectedInfo.name} · ${_duration.label}',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: FinavigColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We reply with a payment link and activate the plan after '
                  'payment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

/// One selectable plan row: gold icon chip, name, tagline, check indicator.
/// Selection is shown with an accent border; the live price and top
/// benefits live in the summary card below so the sheet stays short.
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final TierInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? FinavigColors.tierGold : FinavigColors.tierGoldDark;
    final isBusiness = info.tier == SubscriptionTier.business;

    // Gold icon chips echo the tier-badge language: outlined gold for Plus,
    // solid gold for Business.
    final iconChip = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isBusiness ? gold : gold.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isBusiness
            ? Icons.business_center_rounded
            : Icons.workspace_premium_rounded,
        color: isBusiness
            ? (isDark ? FinavigColors.ink : Colors.white)
            : gold,
        size: 20,
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? FinavigColors.accent.withAlpha(isDark ? 40 : 18)
              : null,
          border: Border.all(
            color: selected
                ? FinavigColors.accent
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            iconChip,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    info.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? FinavigColors.accent
                  : FinavigColors.adaptiveIcon(
                      context, theme.colorScheme.outlineVariant),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Price + top benefits for the currently selected plan & billing period.
class _PriceSummaryCard extends StatelessWidget {
  const _PriceSummaryCard({required this.info, required this.duration});

  final TierInfo info;
  final PlanDuration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? FinavigColors.accentBright : FinavigColors.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: FinavigColors.accent.withAlpha(isDark ? 40 : 18),
        border: Border.all(
          color: FinavigColors.accent.withAlpha(isDark ? 110 : 70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                TierInfo.priceMain(info.tier, duration),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: accent,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  TierInfo.priceSub(info.tier, duration),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Top benefits only — the full list stays on the paywall dialog.
          ...info.benefits.take(3).map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: accent, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key, required this.feature, this.requestedTier});

  final EntitlementFeature feature;

  /// Override the advertised tier (defaults to the tier that unlocks
  /// [feature]).
  final SubscriptionTier? requestedTier;

  Future<void> _sendRequest(BuildContext context) async {
    final target = requestedTier ?? feature.requiredTier;
    UpgradeRequestService.instance.logAttempt(feature, target);
    final launched = await UpgradeRequestService.instance.send(
      feature: feature,
      requestedTier: target,
      duration: PlanDuration.oneMonth,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: launched ? Colors.green : FinavigColors.navyPrimary,
        content: Text(
          launched
              ? 'Upgrade request opened in your mail app — just press send. '
                    'You will receive a payment link for the 1 Month plan.'
              : 'No mail app found — request copied to clipboard, paste it '
                    'into an email to ${UpgradeRequestService.supportEmail}',
        ),
      ),
    );
    if (launched && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entitlements = EntitlementService.instance;
    final currentTier = entitlements.tier;
    final target = requestedTier ?? feature.requiredTier;
    final info = TierInfo.all[target]!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FinavigColors.navyPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: FinavigColors.navyPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Upgrade required')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${feature.label}" is part of the ${info.name} plan. '
              'You are currently on the ${TierInfo.all[currentTier]!.name} plan.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FinavigColors.navyPrimary, FinavigColors.navyPrimaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        info.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: FinavigColors.cyanSecondary.withAlpha(46),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            info.priceLabel,
                            style: const TextStyle(
                              color: FinavigColors.cyanSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.tagline,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...info.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: FinavigColors.cyanSecondary,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Manual upgrade for early access: tap the button below and '
              'send the pre-filled email to ${UpgradeRequestService.supportEmail}. '
              'Our team activates your tier in the admin panel and you get a '
              'confirmation email.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe later'),
        ),
        // The one-button upgrade flow.
        FilledButton.icon(
          onPressed: () => _sendRequest(context),
          icon: const Icon(Icons.upgrade_rounded, size: 18),
          label: const Text('Request Upgrade'),
          style: FilledButton.styleFrom(
            backgroundColor: FinavigColors.ink,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Compact tier badge for headers (e.g. the profile card).
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, this.tier, this.compact = false});

  final SubscriptionTier? tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolved = tier ?? EntitlementService.instance.tier;
    final info = TierInfo.all[resolved]!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? FinavigColors.tierGold : FinavigColors.tierGoldDark;

    // Paid tiers carry the logo gold as a premium highlight. Plus is an
    // outlined gold badge; Business is a solid gold pill so the two read
    // apart at a glance. Free keeps its neutral styling.
    final badgeShape = switch (resolved) {
      SubscriptionTier.free => BadgeShape.neutral,
      SubscriptionTier.plus => BadgeShape.outlined,
      SubscriptionTier.business => BadgeShape.solid,
    };
    final (color, textColor) = switch (badgeShape) {
      BadgeShape.neutral => (
        isDark ? Colors.white.withAlpha(230) : FinavigColors.textSecondaryLight,
        isDark ? Colors.white.withAlpha(230) : FinavigColors.textSecondaryLight,
      ),
      BadgeShape.outlined => (gold, gold),
      BadgeShape.solid => (gold, isDark ? FinavigColors.ink : Colors.white),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: switch (badgeShape) {
          BadgeShape.neutral => color.withAlpha(28),
          BadgeShape.outlined => gold.withAlpha(24),
          BadgeShape.solid => gold,
        },
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: switch (badgeShape) {
            BadgeShape.neutral => color.withAlpha(120),
            BadgeShape.outlined => gold.withAlpha(160),
            BadgeShape.solid => gold,
          },
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (resolved) {
              SubscriptionTier.free => Icons.person_rounded,
              SubscriptionTier.plus => Icons.workspace_premium_rounded,
              SubscriptionTier.business => Icons.business_center_rounded,
            },
            size: compact ? 11 : 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            info.name,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeShape { neutral, outlined, solid }
