import 'package:flutter/material.dart';

/// A user-created folder inside a [DocumentCollection] for grouping documents.
///
/// Documents optionally reference a folder via [ExpiryItem.folderId].
/// Folders are scoped to a collection and their count is limited by [SubscriptionTier].
class DocumentFolder {
  final String id;
  final String collectionId;
  final String name;
  final String iconKey;
  final int colorValue;
  final DateTime createdAt;

  const DocumentFolder({
    required this.id,
    required this.collectionId,
    required this.name,
    this.iconKey = 'folder',
    this.colorValue = 0xFF2563EB, // Default Royal Blue
    required this.createdAt,
  });

  /// Available icons for folders with friendly labels
  static const Map<String, (IconData, String)> availableIcons = {
    'folder': (Icons.folder_rounded, 'Folder'),
    'family': (Icons.people_alt_rounded, 'Family & Personal'),
    'car': (Icons.directions_car_rounded, 'Vehicles'),
    'home': (Icons.home_work_rounded, 'Properties & Leases'),
    'work': (Icons.business_center_rounded, 'Work & Corporate'),
    'medical': (Icons.health_and_safety_rounded, 'Health & Medical'),
    'finance': (Icons.account_balance_wallet_rounded, 'Banking & Finance'),
    'travel': (Icons.flight_takeoff_rounded, 'Travel & Visas'),
    'tax': (Icons.receipt_long_rounded, 'Tax & Compliance'),
    'star': (Icons.star_rounded, 'Important / Favorites'),
  };

  /// Preset vibrant palette colors for folder tags
  static const List<int> presetColors = [
    0xFF2563EB, // Blue
    0xFF059669, // Emerald
    0xFFD97706, // Amber
    0xFFDC2626, // Red
    0xFF7C3AED, // Violet
    0xFF0891B2, // Cyan
    0xFFDB2777, // Pink
    0xFF4B5563, // Slate
  ];

  IconData get iconData => availableIcons[iconKey]?.$1 ?? Icons.folder_rounded;

  Color get color => Color(colorValue);

  factory DocumentFolder.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val)?.toUtc() ?? DateTime.now().toUtc();
      }
      return DateTime.now().toUtc();
    }

    return DocumentFolder(
      id: json['id'] as String,
      collectionId:
          (json['collectionId'] ?? json['collection_id']) as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Folder',
      iconKey: json['icon'] as String? ?? 'folder',
      colorValue: (json['color'] as num?)?.toInt() ?? 0xFF2563EB,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'collectionId': collectionId,
      'name': name,
      'icon': iconKey,
      'color': colorValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DocumentFolder copyWith({
    String? id,
    String? collectionId,
    String? name,
    String? iconKey,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DocumentFolder && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
