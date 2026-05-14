import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/macos/folder_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('scanner returns media entries from imported folder', () async {
    final repo = FakeFolderImportRepository(['a.jpg', 'b.mp4', 'readme.txt']);
    final result = await repo.scan();

    expect(result, ['a.jpg', 'b.mp4']);
  });

  test('scanner maps imported media entries into media items', () async {
    final repo = FakeFolderImportRepository(['a.jpg', 'b.mp4', 'readme.txt']);
    final items = await repo.scanMediaItems();

    expect(items.length, 2);
    expect(items.first.id, 'a.jpg');
    expect(items.first.type, MediaType.photo);
    expect(items.last.type, MediaType.video);
  });

  test('macOS scanner records file size in media items', () async {
    final directory = await Directory.systemTemp.createTemp('rephoto-test-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final file = File('${directory.path}/photo.jpg');
    await file.writeAsBytes([1, 2, 3, 4, 5]);

    final repo = MacosFolderImportRepository(rootDirectory: directory.path);
    final items = await repo.scanMediaItems();

    expect(items.single.sizeBytes, 5);
  });
}
