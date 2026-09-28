import 'package:flutter/material.dart';

import '../../models/document_collection.dart';
import '../../models/subscription_tier.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'profile_sections.dart';

/// Collections section of the Profile (Settings) screen — group documents
/// per company: switch active workspace, rename, delete, and tier locks.
class ProfileCollectionsSection extends StatelessWidget {
  final List<DocumentCollection> collections;
  final String activeId;
  final VoidCallback onCreate;
  final void Function(DocumentCollection) onRename;
  final void Function(DocumentCollection) onDelete;
  final void Function(DocumentCollection) onSwitch;

  const ProfileCollectionsSection({
    super.key,
    required this.collections,
    required this.activeId,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final entitlements = EntitlementService.instance;
    return ProfileSectionGroup(
      title: 'My Collections',
      action: IconButton(
        onPressed: onCreate,
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'New collection',
        visualDensity: VisualDensity.compact,
      ),
      children: [
        for (final collection in collections)
          Builder(
            builder: (ctx) {
              final isLocked = entitlements.isCollectionLocked(collection);
              final reqTier =
                  entitlements.requiredTierForCollection(collection);
              final reqFeature =
                  entitlements.requiredFeatureForCollection(collection);

              return ProfileSettingsTile(
                icon: isLocked ? Icons.lock_rounded : collection.icon,
                iconColor: isLocked ? FinavigColors.warning : null,
                title: collection.name,
                subtitle: isLocked
                    ? 'Locked • Requires ${TierInfo.all[reqTier]!.name} Plan'
                    : (collection.isPersonal
                        ? 'Your own documents — always here'
                        : 'Company collection'),
                highlighted: activeId == collection.id && !isLocked,
                trailing: isLocked
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FinavigColors.warning.withAlpha(35),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: FinavigColors.warning.withAlpha(120),
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
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDelete(collection),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ],
                      )
                    : (activeId == collection.id
                        ? const Tooltip(
                            message: 'Active collection',
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Personal collection cannot be renamed/deleted.
                              if (!collection.isPersonal) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  tooltip: 'Rename',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onRename(collection),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onDelete(collection),
                                ),
                              ],
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ],
                          )),
                onTap: isLocked
                    ? () => showUpgradeDialog(ctx, reqFeature)
                    : (activeId == collection.id
                        ? null
                        : () => onSwitch(collection)),
              );
            },
          ),
      ],
    );
  }
}
