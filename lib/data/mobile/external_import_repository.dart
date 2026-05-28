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

class ExternalImportRoot {
  const ExternalImportRoot({
    required this.id,
    required this.label,
    this.description,
    this.removable = true,
  });

  final String id;
  final String label;
  final String? description;
  final bool removable;
}

class ExternalImportScanPage {
  const ExternalImportScanPage({required this.items, required this.hasMore});

  final List<ExternalImportItem> items;
  final bool hasMore;
}

class ImportAlbumTarget {
  const ImportAlbumTarget({
    required this.name,
    this.id,
    this.relativePath,
    this.systemLibrary = false,
  });

  const ImportAlbumTarget.systemLibrary()
    : name = '你的图库',
      id = null,
      relativePath = null,
      systemLibrary = true;

  factory ImportAlbumTarget.existing({
    required String id,
    required String name,
    String? relativePath,
  }) {
    return ImportAlbumTarget(id: id, name: name, relativePath: relativePath);
  }

  factory ImportAlbumTarget.named(String name) {
    return ImportAlbumTarget(name: name);
  }

  final String name;
  final String? id;
  final String? relativePath;
  final bool systemLibrary;
}

abstract class ExternalImportRepository {
  Future<String?> getSavedImportRoot();
  Future<List<ExternalImportRoot>> listImportRoots();
  Future<String?> requestImportRoot({String? rootId});
  Future<List<ExternalImportItem>> scanImportRoot({bool includeRaw = false});
  Future<ExternalImportScanPage> scanImportRootPage({
    required int offset,
    required int limit,
    bool includeRaw = false,
  });
  Future<String?> getImportDebugInfo();
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri);
  Future<Uint8List?> fetchFullImageData(String pathOrUri);
  Future<void> deleteExternalMedia(ExternalImportItem item);
  Future<List<String>> deleteExternalMediaItems(List<ExternalImportItem> items);
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required ImportAlbumTarget albumTarget,
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
  Future<List<ExternalImportRoot>> listImportRoots() async {
    final result = await channel.invokeMethod<List<dynamic>>('listImportRoots');
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_rootFromRaw)
        .where((root) => root.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<String?> requestImportRoot({String? rootId}) {
    return channel.invokeMethod<String>('requestImportRoot', <String, dynamic>{
      if (rootId != null && rootId.isNotEmpty) 'rootId': rootId,
    });
  }

  @override
  Future<List<ExternalImportItem>> scanImportRoot({
    bool includeRaw = false,
  }) async {
    final result = await channel.invokeMethod<List<dynamic>>(
      'scanImportRoot',
      <String, dynamic>{'includeRaw': includeRaw},
    );
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(_itemFromRaw)
        .where((item) => item.id.isNotEmpty && item.pathOrUri.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<ExternalImportScanPage> scanImportRootPage({
    required int offset,
    required int limit,
    bool includeRaw = false,
  }) async {
    final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
      'scanImportRootPage',
      <String, dynamic>{
        'offset': offset,
        'limit': limit,
        'includeRaw': includeRaw,
      },
    );
    final rawItems = result?['items'] as List<dynamic>? ?? const <dynamic>[];
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map(_itemFromRaw)
        .where((item) => item.id.isNotEmpty && item.pathOrUri.isNotEmpty)
        .toList(growable: false);
    return ExternalImportScanPage(
      items: items,
      hasMore: result?['hasMore'] == true,
    );
  }

  @override
  Future<String?> getImportDebugInfo() {
    return channel.invokeMethod<String>('getImportDebugInfo');
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
  Future<void> deleteExternalMedia(ExternalImportItem item) {
    return channel.invokeMethod<void>('deleteExternalMedia', <String, dynamic>{
      'sourceUri': item.pathOrUri,
    });
  }

  @override
  Future<List<String>> deleteExternalMediaItems(
    List<ExternalImportItem> items,
  ) async {
    if (items.isEmpty) return const <String>[];
    final result = await channel.invokeMethod<List<dynamic>>(
      'deleteExternalMediaItems',
      <String, dynamic>{
        'sourceUris': items.map((item) => item.pathOrUri).toList(),
      },
    );
    return (result ?? const <dynamic>[])
        .map((value) => value.toString())
        .toList(growable: false);
  }

  @override
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required ImportAlbumTarget albumTarget,
  }) async {
    final result = await channel
        .invokeMethod<String>('importExternalMedia', <String, dynamic>{
          'sourceUri': item.pathOrUri,
          'displayName': item.displayName,
          'type': item.type == MediaType.video ? 'video' : 'photo',
          if (!albumTarget.systemLibrary) 'albumName': albumTarget.name,
          if (albumTarget.id != null) 'albumId': albumTarget.id,
          if (albumTarget.relativePath != null)
            'albumRelativePath': albumTarget.relativePath,
          'useSystemLibrary': albumTarget.systemLibrary,
        });
    return result ?? '';
  }

  ExternalImportRoot _rootFromRaw(Map<dynamic, dynamic> raw) {
    return ExternalImportRoot(
      id: (raw['id'] ?? '').toString(),
      label: (raw['label'] ?? '储存卡').toString(),
      description: raw['description']?.toString(),
      removable: raw['removable'] != false,
    );
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
  final List<ImportAlbumTarget> importedAlbumTargets = <ImportAlbumTarget>[];
  final List<String> deletedIds = <String>[];
  final Set<String> failingDeleteIds = <String>{};
  List<ExternalImportRoot> roots = const <ExternalImportRoot>[
    ExternalImportRoot(id: 'fake-sd-card', label: '测试储存卡'),
  ];
  String? savedRoot = 'content://tree/fake';

  @override
  Future<String?> getSavedImportRoot() async => savedRoot;

  @override
  Future<List<ExternalImportRoot>> listImportRoots() async => roots;

  @override
  Future<String?> requestImportRoot({String? rootId}) async {
    savedRoot = 'content://tree/fake';
    return savedRoot;
  }

  @override
  Future<List<ExternalImportItem>> scanImportRoot({
    bool includeRaw = false,
  }) async {
    if (savedRoot == null) return const <ExternalImportItem>[];
    return _items
        .where((item) => includeRaw || !_isRawImportItem(item))
        .toList(growable: false);
  }

  @override
  Future<ExternalImportScanPage> scanImportRootPage({
    required int offset,
    required int limit,
    bool includeRaw = false,
  }) async {
    final allItems = await scanImportRoot(includeRaw: includeRaw);
    final safeOffset = offset.clamp(0, allItems.length);
    final safeLimit = limit <= 0 ? 1 : limit;
    final end = (safeOffset + safeLimit).clamp(0, allItems.length);
    return ExternalImportScanPage(
      items: allItems.sublist(safeOffset, end),
      hasMore: end < allItems.length,
    );
  }

  @override
  Future<String?> getImportDebugInfo() async {
    return 'root=$savedRoot items=${_items.length}';
  }

  @override
  Future<Uint8List?> fetchPreviewImageData(String pathOrUri) async => null;

  @override
  Future<Uint8List?> fetchFullImageData(String pathOrUri) async => null;

  @override
  Future<void> deleteExternalMedia(ExternalImportItem item) async {
    if (failingDeleteIds.contains(item.id)) {
      throw Exception('delete failed');
    }
    deletedIds.add(item.id);
    _items.removeWhere((candidate) => candidate.id == item.id);
  }

  @override
  Future<List<String>> deleteExternalMediaItems(
    List<ExternalImportItem> items,
  ) async {
    final deleted = <String>[];
    for (final item in items) {
      if (failingDeleteIds.contains(item.id)) {
        continue;
      }
      deletedIds.add(item.id);
      deleted.add(item.pathOrUri);
    }
    _items.removeWhere((candidate) => deleted.contains(candidate.pathOrUri));
    return deleted;
  }

  @override
  Future<String> importExternalMedia(
    ExternalImportItem item, {
    required ImportAlbumTarget albumTarget,
  }) async {
    importedIds.add(item.id);
    importedAlbumNames.add(albumTarget.name);
    importedAlbumTargets.add(albumTarget);
    return 'content://media/imported/${item.id}';
  }

  bool _isRawImportItem(ExternalImportItem item) {
    final lower = item.displayName.toLowerCase();
    return lower.endsWith('.dng') ||
        lower.endsWith('.nef') ||
        lower.endsWith('.nrw') ||
        lower.endsWith('.cr2') ||
        lower.endsWith('.cr3') ||
        lower.endsWith('.arw') ||
        lower.endsWith('.rw2') ||
        lower.endsWith('.orf') ||
        lower.endsWith('.raf') ||
        lower.endsWith('.pef') ||
        lower.endsWith('.srw');
  }
}
