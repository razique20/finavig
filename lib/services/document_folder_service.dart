import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/document_folder.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'document_scanner_service.dart';
import 'entitlement_service.dart';
import 'supabase_service.dart';

/// Exception thrown when attempting to create a folder beyond the tier's limit.
class FolderLimitReachedException implements Exception {
  final int maxFolders;
  final int currentCount;

  const FolderLimitReachedException({
    required this.maxFolders,
    required this.currentCount,
  });

  @override
  String toString() =>
      'FolderLimitReachedException: Plan allows $maxFolders folders, already have $currentCount';
}

/// Offline-first store and sync engine for [DocumentFolder]s.
class DocumentFolderService extends ChangeNotifier {
  DocumentFolderService._();

  static final DocumentFolderService instance = DocumentFolderService._();
  factory DocumentFolderService() => instance;

  static const String _storageKey = 'finavig_document_folders_v1';
  static const _uuid = Uuid();

  final _client = SupabaseService.clientOrNull;
  List<DocumentFolder> _folders = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// All folders across all collections.
  List<DocumentFolder> get allFolders => List.unmodifiable(_folders);

  /// Folders belonging to a specific collection.
  List<DocumentFolder> foldersForCollection(String collectionId) {
    return _folders.where((f) => f.collectionId == collectionId).toList();
  }

  /// Folders belonging to the currently active collection.
  List<DocumentFolder> get activeCollectionFolders {
    final activeId = DocumentCollectionService.instance.activeCollectionId;
    return foldersForCollection(activeId);
  }

  DocumentFolder? folderById(String id) {
    return _folders.where((f) => f.id == id).firstOrNull;
  }

  /// Initialize folder cache from local storage and trigger remote sync.
  Future<void> init() async {
    if (_initialized) return;
    await _loadFromLocal();
    _initialized = true;
    notifyListeners();
    // Non-blocking sync with Supabase
    _syncWithRemote();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _folders = decoded
            .map((item) => DocumentFolder.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      dev.log('Failed to load folders from cache: $e', name: 'DocumentFolderService');
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      dev.log('Failed to save folders to cache: $e', name: 'DocumentFolderService');
    }
  }

  Future<void> _syncWithRemote() async {
    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client == null || userId == null) return;

    try {
      final response = await client
          .from('document_folders')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: true);

      final remoteFolders = (response as List<dynamic>)
          .map((r) => DocumentFolder.fromJson(r as Map<String, dynamic>))
          .toList();

      _folders = remoteFolders;
      await _saveToLocal();
      notifyListeners();
    } catch (e) {
      // Offline or table not yet migrated — keep local cache
      dev.log('Supabase document_folders sync skipped/failed: $e',
          name: 'DocumentFolderService');
    }
  }

  /// Refresh folders manually (e.g., on pull-to-refresh).
  Future<void> refresh() async {
    await _syncWithRemote();
  }

  /// Create a new folder inside [collectionId].
  ///
  /// Throws [FolderLimitReachedException] if the tier does not allow creating
  /// more folders.
  Future<DocumentFolder> createFolder({
    required String collectionId,
    required String name,
    String iconKey = 'folder',
    int colorValue = 0xFF2563EB,
  }) async {
    await init();

    // Entitlement limit check
    final currentCount = foldersForCollection(collectionId).length;
    if (!EntitlementService.instance.canAddFolders(currentCount)) {
      throw FolderLimitReachedException(
        maxFolders: EntitlementService.instance.limits.maxFolders ?? 0,
        currentCount: currentCount,
      );
    }

    final newFolder = DocumentFolder(
      id: _uuid.v4(),
      collectionId: collectionId,
      name: name.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      createdAt: DateTime.now().toUtc(),
    );

    _folders.add(newFolder);
    await _saveToLocal();
    notifyListeners();

    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client != null && userId != null) {
      try {
        await client.from('document_folders').insert({
          'id': newFolder.id,
          'owner_id': userId,
          'collection_id': newFolder.collectionId,
          'name': newFolder.name,
          'icon': newFolder.iconKey,
          'color': newFolder.colorValue,
          'created_at': newFolder.createdAt.toIso8601String(),
        });
      } catch (e) {
        dev.log('Failed to persist folder to Supabase: $e',
            name: 'DocumentFolderService');
      }
    }

    return newFolder;
  }

  /// Update folder properties (name, icon, color).
  Future<void> updateFolder(
    String folderId, {
    String? name,
    String? iconKey,
    int? colorValue,
  }) async {
    await init();
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;

    final updated = _folders[index].copyWith(
      name: name?.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
    );

    _folders[index] = updated;
    await _saveToLocal();
    notifyListeners();

    final client = _client;
    if (client != null) {
      try {
        final updatePayload = <String, dynamic>{};
        if (name != null) updatePayload['name'] = name.trim();
        if (iconKey != null) updatePayload['icon'] = iconKey;
        if (colorValue != null) updatePayload['color'] = colorValue;

        if (updatePayload.isNotEmpty) {
          await client
              .from('document_folders')
              .update(updatePayload)
              .eq('id', folderId);
        }
      } catch (e) {
        dev.log('Failed to update folder in Supabase: $e',
            name: 'DocumentFolderService');
      }
    }
  }

  /// Delete a folder.
  ///
  /// Safe deletion: Unassigns all documents referencing [folderId] so
  /// no documents are deleted or orphaned.
  Future<void> deleteFolder(String folderId) async {
    await init();

    // 1. Unassign documents locally & remotely
    await DocumentScannerService.instance.unassignFolderFromDocuments(folderId);

    // 2. Remove folder from local state
    _folders.removeWhere((f) => f.id == folderId);
    await _saveToLocal();
    notifyListeners();

    // 3. Remove folder from Supabase
    final client = _client;
    if (client != null) {
      try {
        await client.from('document_folders').delete().eq('id', folderId);
      } catch (e) {
        dev.log('Failed to delete folder from Supabase: $e',
            name: 'DocumentFolderService');
      }
    }
  }

  /// Number of folders currently in use in the active collection.
  int get activeCollectionFolderCount => activeCollectionFolders.length;

  /// Clear in-memory cache (e.g. on user sign-out).
  void reset() {
    _folders = [];
    _initialized = false;
    notifyListeners();
  }
}
