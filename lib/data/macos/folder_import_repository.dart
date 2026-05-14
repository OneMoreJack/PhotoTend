import 'dart:io';

import 'package:rephoto/domain/models/media_item.dart';

abstract class FolderImportRepository {
  Future<List<String>> scan();
  Future<List<MediaItem>> scanMediaItems();
}

class MacosFolderImportRepository implements FolderImportRepository {
  MacosFolderImportRepository({required this.rootDirectory});

  final String rootDirectory;
  static const _extensions = <String>[
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.mp4',
    '.mov',
  ];

  @override
  Future<List<String>> scan() async {
    final root = Directory(rootDirectory);
    if (!await root.exists()) {
      return <String>[];
    }

    final mediaPaths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final path = entity.path.toLowerCase();
      if (_extensions.any(path.endsWith)) {
        mediaPaths.add(entity.path);
      }
    }
    return mediaPaths;
  }

  @override
  Future<List<MediaItem>> scanMediaItems() async {
    final paths = await scan();
    final items = <MediaItem>[];
    for (final path in paths) {
      DateTime? createdAt;
      int? sizeBytes;
      try {
        final stat = await File(path).stat();
        createdAt = stat.modified;
        sizeBytes = stat.size;
      } catch (_) {
        createdAt = null;
        sizeBytes = null;
      }

      items.add(
        MediaItem(
          id: path,
          type: _isVideoPath(path) ? MediaType.video : MediaType.photo,
          createdAt: createdAt,
          locationKey: null,
          pathOrUri: path,
          sizeBytes: sizeBytes,
        ),
      );
    }
    return items;
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov');
  }
}

class FakeFolderImportRepository implements FolderImportRepository {
  FakeFolderImportRepository(this._files);

  final List<String> _files;

  @override
  Future<List<String>> scan() async {
    const extensions = <String>[
      '.jpg',
      '.jpeg',
      '.png',
      '.heic',
      '.mp4',
      '.mov',
    ];
    return _files
        .where(
          (file) => extensions.any((ext) => file.toLowerCase().endsWith(ext)),
        )
        .toList();
  }

  @override
  Future<List<MediaItem>> scanMediaItems() async {
    final paths = await scan();
    return paths
        .map(
          (path) => MediaItem(
            id: path,
            type: _isVideoPath(path) ? MediaType.video : MediaType.photo,
            pathOrUri: path,
          ),
        )
        .toList();
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov');
  }
}
