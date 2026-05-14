import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/macos/folder_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test(
    'macos repository scans folder recursively for photo and video files',
    () async {
      final root = await Directory.systemTemp.createTemp('rephoto_scan_test');
      final nested = Directory('${root.path}/nested')
        ..createSync(recursive: true);

      final photo = File('${root.path}/a.jpg')..writeAsStringSync('photo');
      final video = File('${nested.path}/b.mp4')..writeAsStringSync('video');
      File('${nested.path}/ignore.txt').writeAsStringSync('text');

      final repo = MacosFolderImportRepository(rootDirectory: root.path);
      final result = await repo.scan();

      expect(result, containsAll([photo.path, video.path]));
      expect(result.any((path) => path.endsWith('.txt')), isFalse);

      await root.delete(recursive: true);
    },
  );

  test('macos repository maps scan result to media items with types', () async {
    final root = await Directory.systemTemp.createTemp(
      'rephoto_scan_items_test',
    );
    final nested = Directory('${root.path}/nested')
      ..createSync(recursive: true);

    final photo = File('${root.path}/a.jpg')..writeAsStringSync('photo');
    final video = File('${nested.path}/b.mp4')..writeAsStringSync('video');

    final repo = MacosFolderImportRepository(rootDirectory: root.path);
    final items = await repo.scanMediaItems();

    final byId = {for (final item in items) item.id: item};
    expect(byId[photo.path]?.type, MediaType.photo);
    expect(byId[video.path]?.type, MediaType.video);
    expect(byId[photo.path]?.pathOrUri, photo.path);
    expect(byId[photo.path]?.createdAt, isNotNull);

    await root.delete(recursive: true);
  });
}
