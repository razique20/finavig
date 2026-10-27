import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finavig/models/document_folder.dart';
import 'package:finavig/models/subscription_tier.dart';
import 'package:finavig/screens/documents_screen.dart';
import 'package:finavig/services/document_folder_service.dart';
import 'package:finavig/services/document_scanner_service.dart';
import 'package:finavig/services/entitlement_service.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/documents/folder_list_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentFolder Model', () {
    test('serializes to and from JSON correctly', () {
      final now = DateTime.utc(2026, 10, 27, 12, 0);
      final folder = DocumentFolder(
        id: 'folder-123',
        collectionId: 'col-456',
        name: 'Family Passports',
        iconKey: 'family',
        colorValue: 0xFF2563EB,
        createdAt: now,
      );

      final json = folder.toJson();
      expect(json['id'], 'folder-123');
      expect(json['collection_id'], 'col-456');
      expect(json['name'], 'Family Passports');
      expect(json['icon'], 'family');
      expect(json['color'], 0xFF2563EB);

      final restored = DocumentFolder.fromJson(json);
      expect(restored.id, folder.id);
      expect(restored.collectionId, folder.collectionId);
      expect(restored.name, folder.name);
      expect(restored.iconKey, folder.iconKey);
      expect(restored.colorValue, folder.colorValue);
    });

    test('copyWith updates properties correctly', () {
      final folder = DocumentFolder(
        id: '1',
        collectionId: 'c1',
        name: 'Cars',
        createdAt: DateTime.now().toUtc(),
      );

      final updated = folder.copyWith(name: 'Fleet Vehicles', iconKey: 'car');
      expect(updated.name, 'Fleet Vehicles');
      expect(updated.iconKey, 'car');
      expect(updated.id, '1');
    });
  });

  group('Folder Entitlements by Subscription Tier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      EntitlementService.instance.reset();
      await EntitlementService.instance.init();
    });

    test('Free tier allows 0 custom folders', () {
      expect(SubscriptionTier.free.limits.maxFolders, 0);
      expect(EntitlementService.instance.tier, SubscriptionTier.free);
      expect(EntitlementService.instance.allowsCustomFolders, isFalse);
      expect(EntitlementService.instance.canAddFolders(0), isFalse);
      expect(EntitlementService.instance.remainingFolders(0), 0);
    });

    test('Plus tier allows up to 5 folders', () async {
      expect(SubscriptionTier.plus.limits.maxFolders, 5);

      await EntitlementService.instance.setLocalOverride(SubscriptionTier.plus);
      expect(EntitlementService.instance.tier, SubscriptionTier.plus);
      expect(EntitlementService.instance.allowsCustomFolders, isTrue);

      expect(EntitlementService.instance.canAddFolders(0), isTrue);
      expect(EntitlementService.instance.canAddFolders(4), isTrue);
      expect(EntitlementService.instance.canAddFolders(5), isFalse);
      expect(EntitlementService.instance.remainingFolders(3), 2);
      expect(EntitlementService.instance.remainingFolders(5), 0);
    });

    test('Business tier allows unlimited folders', () async {
      expect(SubscriptionTier.business.limits.maxFolders, isNull);

      await EntitlementService.instance.setLocalOverride(SubscriptionTier.business);
      expect(EntitlementService.instance.tier, SubscriptionTier.business);
      expect(EntitlementService.instance.allowsCustomFolders, isTrue);

      expect(EntitlementService.instance.canAddFolders(0), isTrue);
      expect(EntitlementService.instance.canAddFolders(100), isTrue);
      expect(EntitlementService.instance.remainingFolders(50), isNull);
    });
  });

  group('DocumentFolderService CRUD and Safe Deletion', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      EntitlementService.instance.reset();
      await EntitlementService.instance.init();
      // Enable Plus tier for folder operations
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.plus);
      DocumentFolderService.instance.reset();
      await DocumentFolderService.instance.init();
    });

    test('creates and retrieves folders for collection', () async {
      final folder = await DocumentFolderService.instance.createFolder(
        collectionId: 'col-1',
        name: 'Office Leases',
        iconKey: 'home',
        colorValue: 0xFFD97706,
      );

      expect(folder.name, 'Office Leases');
      expect(folder.collectionId, 'col-1');
      expect(folder.iconKey, 'home');

      final list = DocumentFolderService.instance.foldersForCollection('col-1');
      expect(list.length, 1);
      expect(list.first.id, folder.id);
    });

    test('throws FolderLimitReachedException when quota exceeded', () async {
      // Free tier allows 0 folders
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.free);

      expect(
        () => DocumentFolderService.instance.createFolder(
          collectionId: 'col-1',
          name: 'Should Fail',
        ),
        throwsA(isA<FolderLimitReachedException>()),
      );
    });

    test('updates folder name and styling', () async {
      final folder = await DocumentFolderService.instance.createFolder(
        collectionId: 'col-1',
        name: 'Initial Name',
      );

      await DocumentFolderService.instance.updateFolder(
        folder.id,
        name: 'Updated Name',
        iconKey: 'star',
      );

      final updated = DocumentFolderService.instance.folderById(folder.id);
      expect(updated?.name, 'Updated Name');
      expect(updated?.iconKey, 'star');
    });

    test('deleting folder removes folder safely', () async {
      final folder = await DocumentFolderService.instance.createFolder(
        collectionId: 'col-1',
        name: 'Temp Folder',
      );

      expect(DocumentFolderService.instance.allFolders.length, 1);

      await DocumentFolderService.instance.deleteFolder(folder.id);
      expect(DocumentFolderService.instance.allFolders, isEmpty);
      expect(DocumentFolderService.instance.folderById(folder.id), isNull);
    });
  });

  group('Folder UI and Drill-Down Navigation', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DocumentScannerService.instance.clearCache();
      DocumentFolderService.instance.reset();
      EntitlementService.instance.reset();
      await EntitlementService.instance.init();
      await EntitlementService.instance.setLocalOverride(SubscriptionTier.plus);
      await DocumentFolderService.instance.init();
    });

    testWidgets('renders folder list tile in ledger and drills down on tap', (
      tester,
    ) async {
      // 1. Create a folder in local store
      final folder = await DocumentFolderService.instance.createFolder(
        collectionId: 'personal',
        name: 'Work Contracts',
        iconKey: 'briefcase',
        colorValue: 0xFF2563EB,
      );

      // 2. Seed documents: one in folder, one unassigned
      final d1 = DateTime.now().add(const Duration(days: 15));
      final d2 = DateTime.now().add(const Duration(days: 60));
      final y1 = d1.year;
      final m1 = d1.month.toString().padLeft(2, '0');
      final day1 = d1.day.toString().padLeft(2, '0');
      final y2 = d2.year;
      final m2 = d2.month.toString().padLeft(2, '0');
      final day2 = d2.day.toString().padLeft(2, '0');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'local_documents_v1',
        jsonEncode([
          {
            'collectionId': 'personal',
            'id': 'doc-work',
            'displayName': 'Employment Agreement',
            'docType': 'contract',
            'folderId': folder.id,
            'expiryDate': '$y1-$m1-$day1',
            'daysRemaining': 15,
            'isActive': true,
            'urgencyPriority': 1,
            'expiresAt': d1.toIso8601String(),
          },
          {
            'collectionId': 'personal',
            'id': 'doc-personal',
            'displayName': 'Gym Membership',
            'docType': 'other',
            'folderId': null,
            'expiryDate': '$y2-$m2-$day2',
            'daysRemaining': 60,
            'isActive': true,
            'urgencyPriority': 0,
            'expiresAt': d2.toIso8601String(),
          },
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FinavigTheme.light(),
          home: const DocumentsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Root view: Shows "Folders" section with the folder tile
      expect(find.text('Folders'), findsOneWidget);
      expect(find.byType(FolderListTile), findsOneWidget);
      expect(find.text('Work Contracts'), findsOneWidget);

      // Shows "Unassigned" section with unassigned doc
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('Gym Membership'), findsOneWidget);

      // Tap on the folder tile to drill down
      await tester.tap(find.text('Work Contracts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Inside folder: Breadcrumb header displays folder name and document count
      expect(find.text('1 documents'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Document list scoped to this folder
      expect(find.text('Employment Agreement'), findsOneWidget);
      expect(find.text('Gym Membership'), findsNothing);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Back at root view
      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('Work Contracts'), findsOneWidget);
      expect(find.text('Gym Membership'), findsOneWidget);
    });
  });
}

