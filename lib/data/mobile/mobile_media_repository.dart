import 'package:flutter/services.dart';
import 'package:rephoto/domain/models/media_item.dart';

abstract class MobileMediaRepository {
  Future<List<MediaItem>> fetchAllMediaItems();
  Future<List<MediaItem>> fetchMediaPage({
    required int offset,
    required int limit,
  });
  Future<Map<String, String>> batchGetLocationKeys(List<MediaItem> items);
  Future<Map<String, String>> getLocationAliases();
  Future<void> setLocationAlias(String locationKey, String alias);
  Future<void> removeLocationAlias(String locationKey);
  Future<List<String>> fetchAllIds();
  Future<void> permanentDelete(Set<String> ids);
  Future<String?> getDeviceModel(String pathOrUri);
  Future<Map<String, String?>> batchGetDeviceModels(List<MediaItem> items);
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri);
  Future<String?> resolvePlayableMediaUri(String pathOrUri);
  Future<void> openInGallery(String pathOrUri);
  Future<void> shareToTarget(
    String pathOrUri,
    String package,
    String? activity,
  );
}

class MethodChannelMobileMediaRepository implements MobileMediaRepository {
  static const MethodChannel channel = MethodChannel('rephoto/mobile_media');

  @override
  Future<List<MediaItem>> fetchAllMediaItems() async {
    final result = await channel.invokeMethod<List<dynamic>>(
      'fetchAllMediaItems',
    );
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (raw) => MediaItem(
            id: (raw['id'] ?? '').toString(),
            type: raw['type'] == 'video' ? MediaType.video : MediaType.photo,
            createdAt: _createdAtFromRaw(raw['createdAtMillis']),
            locationKey: raw['locationKey']?.toString(),
            pathOrUri: raw['pathOrUri']?.toString(),
            sizeBytes: _sizeBytesFromRaw(raw),
            livePhotoVideoUri: _livePhotoVideoUriFromRaw(raw),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  @override
  Future<List<MediaItem>> fetchMediaPage({
    required int offset,
    required int limit,
  }) async {
    try {
      final result = await channel.invokeMethod<List<dynamic>>(
        'fetchMediaPage',
        <String, dynamic>{'offset': offset, 'limit': limit},
      );
      return _mapMediaItems(result);
    } on MissingPluginException {
      return _fetchMediaPageFallback(offset: offset, limit: limit);
    } on PlatformException catch (error) {
      if (error.code == 'METHOD_NOT_IMPLEMENTED') {
        return _fetchMediaPageFallback(offset: offset, limit: limit);
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> batchGetLocationKeys(
    List<MediaItem> items,
  ) async {
    final itemList = items
        .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'pathOrUri': item.pathOrUri,
          },
        )
        .toList();
    if (itemList.isEmpty) return const <String, String>{};
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'batchGetLocationKeys',
      <String, dynamic>{'items': itemList},
    );
    if (result == null) return const <String, String>{};
    return result.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
      ..removeWhere((_, value) => value.isEmpty);
  }

  @override
  Future<Map<String, String>> getLocationAliases() async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'getLocationAliases',
    );
    if (result == null) return const <String, String>{};
    return result.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
      ..removeWhere((key, value) => key.isEmpty || value.isEmpty);
  }

  @override
  Future<void> setLocationAlias(String locationKey, String alias) async {
    await channel.invokeMethod<void>('setLocationAlias', <String, dynamic>{
      'locationKey': locationKey,
      'alias': alias,
    });
  }

  @override
  Future<void> removeLocationAlias(String locationKey) async {
    await channel.invokeMethod<void>('removeLocationAlias', <String, dynamic>{
      'locationKey': locationKey,
    });
  }

  @override
  Future<List<String>> fetchAllIds() async {
    final result = await channel.invokeMethod<List<dynamic>>('fetchAllIds');
    return (result ?? const <dynamic>[]).cast<String>();
  }

  @override
  Future<void> permanentDelete(Set<String> ids) async {
    await channel.invokeMethod<void>('permanentDelete', <String, dynamic>{
      'ids': ids.toList(),
    });
  }

  @override
  Future<String?> getDeviceModel(String pathOrUri) async {
    final result = await channel.invokeMethod<String>(
      'getDeviceModel',
      <String, dynamic>{'pathOrUri': pathOrUri},
    );
    return result;
  }

  @override
  Future<Map<String, String?>> batchGetDeviceModels(
    List<MediaItem> items,
  ) async {
    final itemList = items
        .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'pathOrUri': item.pathOrUri,
          },
        )
        .toList();
    if (itemList.isEmpty) return const <String, String?>{};
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'batchGetDeviceModels',
      <String, dynamic>{'items': itemList},
    );
    if (result == null) return const <String, String?>{};
    return result.map((k, v) => MapEntry(k.toString(), v?.toString()));
  }

  @override
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri) async {
    final result = await channel.invokeMethod<Uint8List>(
      'fetchPreviewImageData',
      <String, dynamic>{'pathOrUri': pathOrUri},
    );
    return result;
  }

  @override
  Future<String?> resolvePlayableMediaUri(String pathOrUri) async {
    final result = await channel.invokeMethod<String>(
      'resolvePlayableMediaUri',
      <String, dynamic>{'pathOrUri': pathOrUri},
    );
    return result;
  }

  @override
  Future<void> openInGallery(String pathOrUri) async {
    await channel.invokeMethod<void>('openInGallery', <String, dynamic>{
      'pathOrUri': pathOrUri,
    });
  }

  @override
  Future<void> shareToTarget(
    String pathOrUri,
    String package,
    String? activity,
  ) async {
    await channel.invokeMethod<void>('shareToTarget', <String, dynamic>{
      'pathOrUri': pathOrUri,
      'package': package,
      'activity': activity,
    });
  }

  DateTime? _createdAtFromRaw(Object? raw) {
    if (raw == null) {
      return null;
    }
    final millis = switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (millis == null || millis <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  int? _intFromRaw(Object? raw) {
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
  }

  int? _sizeBytesFromRaw(Map<dynamic, dynamic> raw) {
    return _intFromRaw(raw['sizeBytes']) ?? _intFromRaw(raw['size']);
  }

  String? _livePhotoVideoUriFromRaw(Map<dynamic, dynamic> raw) {
    final value = raw['livePhotoVideoUri'] ?? raw['motionVideoUri'];
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  List<MediaItem> _mapMediaItems(List<dynamic>? result) {
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (raw) => MediaItem(
            id: (raw['id'] ?? '').toString(),
            type: raw['type'] == 'video' ? MediaType.video : MediaType.photo,
            createdAt: _createdAtFromRaw(raw['createdAtMillis']),
            locationKey: raw['locationKey']?.toString(),
            pathOrUri: raw['pathOrUri']?.toString(),
            sizeBytes: _sizeBytesFromRaw(raw),
            livePhotoVideoUri: _livePhotoVideoUriFromRaw(raw),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<MediaItem>> _fetchMediaPageFallback({
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit <= 0) {
      return const <MediaItem>[];
    }
    final items = await fetchAllMediaItems();
    if (offset >= items.length) {
      return const <MediaItem>[];
    }
    final end = (offset + limit).clamp(0, items.length);
    return items.sublist(offset, end);
  }
}

class FakeMobileMediaRepository implements MobileMediaRepository {
  FakeMobileMediaRepository(List<String> ids)
    : _items = ids
          .map((id) => MediaItem(id: id, type: MediaType.photo))
          .toList();

  FakeMobileMediaRepository.withItems(List<MediaItem> items)
    : _items = List<MediaItem>.from(items);

  List<MediaItem> _items;

  @override
  Future<List<MediaItem>> fetchAllMediaItems() async {
    return List<MediaItem>.from(_items);
  }

  @override
  Future<List<MediaItem>> fetchMediaPage({
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit <= 0 || offset >= _items.length) {
      return const <MediaItem>[];
    }
    final end = (offset + limit).clamp(0, _items.length);
    return List<MediaItem>.from(_items.sublist(offset, end));
  }

  @override
  Future<Map<String, String>> batchGetLocationKeys(
    List<MediaItem> items,
  ) async {
    return const <String, String>{};
  }

  @override
  Future<Map<String, String>> getLocationAliases() async {
    return const <String, String>{};
  }

  @override
  Future<void> setLocationAlias(String locationKey, String alias) async {}

  @override
  Future<void> removeLocationAlias(String locationKey) async {}

  @override
  Future<List<String>> fetchAllIds() async {
    return _items.map((item) => item.id).toList();
  }

  @override
  Future<void> permanentDelete(Set<String> ids) async {
    _items = _items.where((item) => !ids.contains(item.id)).toList();
  }

  @override
  Future<String?> getDeviceModel(String pathOrUri) async => null;

  @override
  Future<Map<String, String?>> batchGetDeviceModels(
    List<MediaItem> items,
  ) async {
    return const <String, String?>{};
  }

  @override
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri) async => null;

  @override
  Future<String?> resolvePlayableMediaUri(String pathOrUri) async {
    return pathOrUri;
  }

  @override
  Future<void> openInGallery(String pathOrUri) async {}

  @override
  Future<void> shareToTarget(
    String pathOrUri,
    String package,
    String? activity,
  ) async {}
}
