import 'package:flutter/services.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';

abstract class StateStore {
  Future<void> saveTrashIds(Set<String> ids);
  Future<Set<String>> loadTrashIds();

  Future<void> saveLocationFilter(String? locationKey);
  Future<String?> loadLocationFilter();

  Future<void> saveDeletionStats(DeletionStats stats);
  Future<DeletionStats> loadDeletionStats();

  Future<void> saveBrowseProgress(String collectionId, String mediaId);
  Future<String?> loadBrowseProgress(String collectionId);
}

class InMemoryStateStore implements StateStore {
  Set<String> _trashIds = <String>{};
  String? _locationFilter;
  DeletionStats _deletionStats = DeletionStats.empty;
  final Map<String, String> _browseProgressByCollection = <String, String>{};

  @override
  Future<void> saveTrashIds(Set<String> ids) async {
    _trashIds = Set<String>.from(ids);
  }

  @override
  Future<Set<String>> loadTrashIds() async {
    return Set<String>.from(_trashIds);
  }

  @override
  Future<void> saveLocationFilter(String? locationKey) async {
    _locationFilter = locationKey;
  }

  @override
  Future<String?> loadLocationFilter() async {
    return _locationFilter;
  }

  @override
  Future<void> saveDeletionStats(DeletionStats stats) async {
    _deletionStats = stats;
  }

  @override
  Future<DeletionStats> loadDeletionStats() async {
    return _deletionStats;
  }

  @override
  Future<void> saveBrowseProgress(String collectionId, String mediaId) async {
    _browseProgressByCollection[collectionId] = mediaId;
  }

  @override
  Future<String?> loadBrowseProgress(String collectionId) async {
    return _browseProgressByCollection[collectionId];
  }
}

class MethodChannelLocalStateStore implements StateStore {
  static const MethodChannel channel = MethodChannel('rephoto/local_state');

  @override
  Future<void> saveTrashIds(Set<String> ids) async {}

  @override
  Future<Set<String>> loadTrashIds() async => const <String>{};

  @override
  Future<void> saveLocationFilter(String? locationKey) async {}

  @override
  Future<String?> loadLocationFilter() async => null;

  @override
  Future<void> saveDeletionStats(DeletionStats stats) async {
    try {
      await channel.invokeMethod<void>('saveDeletionStats', stats.toMap());
    } on MissingPluginException {
      // Desktop/local test builds may not expose the mobile persistence channel.
    } on PlatformException catch (error) {
      if (error.code != 'METHOD_NOT_IMPLEMENTED') {
        rethrow;
      }
    }
  }

  @override
  Future<DeletionStats> loadDeletionStats() async {
    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'loadDeletionStats',
      );
      return DeletionStats.fromMap(result);
    } on MissingPluginException {
      return DeletionStats.empty;
    } on PlatformException catch (error) {
      if (error.code == 'METHOD_NOT_IMPLEMENTED') {
        return DeletionStats.empty;
      }
      rethrow;
    }
  }

  @override
  Future<void> saveBrowseProgress(String collectionId, String mediaId) async {
    try {
      await channel.invokeMethod<void>('saveBrowseProgress', {
        'collectionId': collectionId,
        'mediaId': mediaId,
      });
    } on MissingPluginException {
      // Desktop/local test builds may not expose the mobile persistence channel.
    } on PlatformException catch (error) {
      if (error.code != 'METHOD_NOT_IMPLEMENTED') {
        rethrow;
      }
    }
  }

  @override
  Future<String?> loadBrowseProgress(String collectionId) async {
    try {
      return await channel.invokeMethod<String>('loadBrowseProgress', {
        'collectionId': collectionId,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (error.code == 'METHOD_NOT_IMPLEMENTED') {
        return null;
      }
      rethrow;
    }
  }
}
