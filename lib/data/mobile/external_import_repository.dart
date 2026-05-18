import 'package:flutter/services.dart';
import 'package:rephoto/domain/models/media_item.dart';

class ExternalImportItem {
  const ExternalImportItem({
    required this.id,
    required this.type,
    required this.displayName,
    required this.pathOrUri,
    this.createdAt,
    this.sizeBytes,
    this.imported = false,
  });

  final String id;
  final MediaType type;
  final String displayName;
  final String pathOrUri;
  final DateTime? createdAt;
  final int? sizeBytes;
  final bool imported;
}

abstract class ExternalImportRepository {
  Future<String?> getSavedImportRoot();
  Future<String?> requestImportRoot();
  Future<List<ExternalImportItem>> scanImportRoot();
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri);
  Future<Uint8List?> fetchFullImageData(String pathOrUri);
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required String albumName,
  });
}

class MethodChannelExternalImportRepository
    implements ExternalImportRepository {
  static const MethodChannel channel = MethodChannel('rephoto/external_import');

  @override
  Future<String?> getSavedImportRoot() {
    return channel.invokeMethod<String>('getSavedImportRoot');
  }

  @override
  Future<String?> requestImportRoot() {
    return channel.invokeMethod<String>('requestImportRoot');
  }

  @override
  Future<List<ExternalImportItem>> scanImportRoot() async {
    final result = await channel.invokeMethod<List<dynamic>>('scanImportRoot');
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_itemFromRaw)
        .where((item) => item.id.isNotEmpty && item.pathOrUri.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri) {
    return channel.invokeMethod<Uint8List>(
      'fetchImportPreviewImageData',
      <String, dynamic>{'pathOrUri': pathOrUri},
    );
  }

  @override
  Future<Uint8List?> fetchFullImageData(String pathOrUri) {
    return channel.invokeMethod<Uint8List>(
      'fetchImportFullImageData',
      <String, dynamic>{'pathOrUri': pathOrUri},
    );
  }

  @override
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required String albumName,
  }) async {
    final result = await channel
        .invokeMethod<String>('importExternalMedia', <String, dynamic>{
          'sourceUri': item.pathOrUri,
          'displayName': item.displayName,
          'type': item.type == MediaType.video ? 'video' : 'photo',
          'albumName': albumName,
        });
    return result ?? '';
  }

  ExternalImportItem _itemFromRaw(Map<dynamic, dynamic> raw) {
    return ExternalImportItem(
      id: (raw['id'] ?? '').toString(),
      type: raw['type'] == 'video' ? MediaType.video : MediaType.photo,
      displayName: (raw['displayName'] ?? '').toString(),
      pathOrUri: (raw['pathOrUri'] ?? raw['id'] ?? '').toString(),
      createdAt: _createdAtFromRaw(raw['createdAtMillis']),
      sizeBytes: _intFromRaw(raw['sizeBytes'] ?? raw['size']),
      imported: raw['imported'] == true,
    );
  }

  DateTime? _createdAtFromRaw(Object? raw) {
    final millis = _intFromRaw(raw);
    if (millis == null || millis <= 0) return null;
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
}

class FakeExternalImportRepository implements ExternalImportRepository {
  FakeExternalImportRepository(List<ExternalImportItem> items)
    : _items = List<ExternalImportItem>.from(items);

  final List<ExternalImportItem> _items;
  final List<String> importedIds = <String>[];
  final List<String> importedAlbumNames = <String>[];
  String? savedRoot = 'content://tree/fake';

  @override
  Future<String?> getSavedImportRoot() async => savedRoot;

  @override
  Future<String?> requestImportRoot() async {
    savedRoot = 'content://tree/fake';
    return savedRoot;
  }

  @override
  Future<List<ExternalImportItem>> scanImportRoot() async {
    if (savedRoot == null) return const <ExternalImportItem>[];
    return List<ExternalImportItem>.from(_items);
  }

  @override
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri) async => null;

  @override
  Future<Uint8List?> fetchFullImageData(String pathOrUri) async => null;

  @override
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required String albumName,
  }) async {
    importedIds.add(item.id);
    importedAlbumNames.add(albumName);
    return 'content://media/imported/${item.id}';
  }
}
