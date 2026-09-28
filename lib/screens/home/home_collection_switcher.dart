import 'package:flutter/material.dart';

import '../../models/subscription_tier.dart';
import '../../services/collection_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/finance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Sentinel returned by the collection-switcher sheet when the user picks
/// "New collection" instead of an existing workspace.
const String homeCreateCollectionAction = '__create__';

/// Opens the Home collection-switcher bottom sheet and applies the
/// selection (including the tiered create flow). Returns the chosen
/// collection id, [homeCreateCollectionAction], or null when dismissed.
Future<String?> showHomeCollectionSwitcher(BuildContext context) async {
  final service = DocumentCollectionService.instance;
  final collections = service.collections;

  final theme = Theme.of(context);
  final entitlements = EntitlementService.instance;
  final companyCount = collections.where((c) => !c.isPersonal).length;
  final canCreateMore = entitlements.canAddCompanyCollections(companyCount);

  final selectedId = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Switch collection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            // Lazy builder: only the visible collection rows are built.
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: collections.length,
              itemBuilder: (tileCtx, index) {
                final collection = collections[index];
                {
                  final isLocked =
                      entitlements.isCollectionLocked(collection);
                  final reqTier =
                      entitlements.requiredTierForCollection(collection);
                  final reqFeature =
                      entitlements.requiredFeatureForCollection(collection);

                  return ListTile(
                        leading: isLocked
                            ? const Icon(Icons.lock_rounded,
                                color: FinavigColors.warning)
                            : Icon(collection.icon),
                        title: Row(
                          children: [
                            Expanded(child: Text(collection.name)),
                            if (isLocked)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FinavigColors.warning.withAlpha(35),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        FinavigColors.warning.withAlpha(120),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: FinavigColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          isLocked
                              ? 'Plan limit reached • Requires ${TierInfo.all[reqTier]!.name}'
                              : collection.subtitle,
                          style: isLocked
                              ? TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12)
                              : null,
                        ),
                        trailing: isLocked
                            ? const Icon(Icons.lock_outline_rounded,
                                size: 18, color: FinavigColors.warning)
                            : (collection.id == service.activeCollectionId
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null),
                        onTap: () {
                          if (isLocked) {
                            Navigator.pop(ctx);
                            showUpgradeDialog(tileCtx, reqFeature);
                          } else {
                            Navigator.pop(ctx, collection.id);
                          }
                        },
                      );
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              canCreateMore
                  ? Icons.add_circle_outline
                  : Icons.lock_outline_rounded,
              color: canCreateMore ? null : FinavigColors.warning,
            ),
            title: const Text('New collection'),
            trailing: !canCreateMore
                ? const TierBadge(compact: true, tier: SubscriptionTier.plus)
                : null,
            onTap: () => Navigator.pop(ctx, homeCreateCollectionAction),
          ),
        ],
      ),
    ),
  );

  return selectedId;
}

/// Applies the switcher's result: creates a tier-gated collection when the
/// user picked the create action, otherwise activates the chosen id. Then
/// refreshes documents + finance so all tabs follow the new collection.
Future<void> applyHomeCollectionSelection(
  BuildContext context,
  String selectedId,
) async {
  final service = DocumentCollectionService.instance;

  if (selectedId == homeCreateCollectionAction) {
    if (!await enforceCompanyCollectionLimit(context)) return;
    if (!context.mounted) return;
    final res = await showCreateCollectionDialog(context);
    if (!context.mounted || res == null) return;
    try {
      final created = await service.createCollection(
        res.name,
        countryCode: res.countryCode,
      );
      await service.setActive(created.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create "${res.name}": $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
  } else {
    await service.setActive(selectedId);
  }

  await DocumentScannerService.instance.refresh();
  // Notify the Money tab too: FinanceService filters by the active
  // collection and MoneyScreen listens to its ChangeNotifier.
  await FinanceService.instance.refresh();
}
