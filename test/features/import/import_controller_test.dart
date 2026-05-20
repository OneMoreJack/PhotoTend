import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';

void main() {
  test('controller marks selected items imported one by one', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.toggleSelection('a');
    controller.toggleSelection('b');
    await controller.importSelected();

    expect(controller.items.map((item) => item.id), ['a', 'b']);
    expect(controller.selectedIds, isEmpty);
    expect(controller.statusFor('a'), ImportItemStatus.imported);
    expect(controller.statusFor('b'), ImportItemStatus.imported);
    expect(controller.completionMessage, '导入完成');
    expect(repo.importedIds, ['a', 'b']);
  });

  test('controller tracks total import progress', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.selectAllPending();
    expect(controller.importProgress, 0);

    await controller.importSelected();

    expect(controller.importTotalCount, 2);
    expect(controller.importCompletedCount, 2);
    expect(controller.importProgress, 1);
  });

  test(
    'controller keeps previously imported items selectable after refresh',
    () async {
      final imported = ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
        sizeBytes: 100,
        imported: true,
      );
      final pending = ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1735689700000),
        sizeBytes: 200,
      );
      final repo = FakeExternalImportRepository([imported, pending]);
      final controller = ImportController(repository: repo);

      await controller.refresh();
      controller.toggleSelection('a');

      expect(controller.statusFor('a'), ImportItemStatus.idle);
      expect(controller.selectedIds, {'a'});

      controller.selectAllPending();

      expect(controller.statusFor('a'), ImportItemStatus.idle);
      expect(controller.statusFor('b'), ImportItemStatus.idle);
      expect(controller.selectedIds, {'a', 'b'});
    },
  );

  test(
    'controller exposes missing card state when no root is available',
    () async {
      final repo = FakeExternalImportRepository(const <ExternalImportItem>[]);
      repo.savedRoot = null;
      final controller = ImportController(repository: repo);

      await controller.refresh();

      expect(controller.items, isEmpty);
      expect(controller.needsStorageCard, isTrue);
      expect(controller.statusMessage, '请连接外接储存卡，或选择储存卡目录。');
    },
  );

  test('controller toggles a pending selection group', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
      ),
      ExternalImportItem(
        id: 'c',
        type: MediaType.photo,
        displayName: 'c.jpg',
        pathOrUri: 'content://doc/c',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.togglePendingSelection(['a', 'b']);

    expect(controller.selectedIds, {'a', 'b'});
    expect(controller.arePendingSelected(['a', 'b']), isTrue);

    controller.togglePendingSelection(['a', 'b']);

    expect(controller.selectedIds, isEmpty);
    expect(controller.arePendingSelected(['a', 'b']), isFalse);
  });

  test('controller deletes selected import items immediately', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.toggleSelection('a');
    controller.deleteSelectedItems();

    expect(controller.items.map((item) => item.id), ['b']);
    expect(controller.trashedItems, isEmpty);
    expect(controller.selectedIds, isEmpty);
  });

  test('controller imports selected items into requested album', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.toggleSelection('a');
    await controller.importSelected(albumName: '旅行');

    expect(repo.importedAlbumNames, ['旅行']);
  });

  test(
    'controller imports all visible pending items when nothing is selected',
    () async {
      final repo = FakeExternalImportRepository([
        ExternalImportItem(
          id: 'a',
          type: MediaType.photo,
          displayName: 'a.jpg',
          pathOrUri: 'content://doc/a',
        ),
        ExternalImportItem(
          id: 'b',
          type: MediaType.photo,
          displayName: 'b.jpg',
          pathOrUri: 'content://doc/b',
        ),
      ]);
      final controller = ImportController(repository: repo);

      await controller.refresh();
      await controller.importPendingOrSelected(albumName: '你的图库');

      expect(repo.importedIds, ['a', 'b']);
      expect(controller.importTotalCount, 2);
    },
  );
}
