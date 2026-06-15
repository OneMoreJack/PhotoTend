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

  test('controller excludes raw files until includeRaw is enabled', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'jpg',
        type: MediaType.photo,
        displayName: 'DSC_0001.JPG',
        pathOrUri: 'content://doc/jpg',
      ),
      ExternalImportItem(
        id: 'raw',
        type: MediaType.photo,
        displayName: 'DSC_0001.NEF',
        pathOrUri: 'content://doc/raw',
      ),
    ]);
    final controller = ImportController(repository: repo);

    await controller.refresh();

    expect(controller.includeRaw, isFalse);
    expect(controller.items.map((item) => item.id), ['jpg']);

    await controller.setIncludeRaw(true);

    expect(controller.includeRaw, isTrue);
    expect(controller.items.map((item) => item.id), ['jpg', 'raw']);
  });

  test(
    'controller publishes import items page by page while scanning',
    () async {
      final repo = PagingFakeExternalImportRepository(
        List.generate(
          61,
          (index) => ExternalImportItem(
            id: 'item-$index',
            type: MediaType.photo,
            displayName: 'item-$index.jpg',
            pathOrUri: 'content://doc/item-$index',
          ),
        ),
      );
      final controller = ImportController(repository: repo);
      final visibleCounts = <int>[];
      final scanningStates = <bool>[];
      controller.addListener(() {
        visibleCounts.add(controller.items.length);
        scanningStates.add(controller.isScanningComplete);
      });

      await controller.refresh();

      expect(repo.requestedOffsets, [0, 60]);
      expect(visibleCounts, contains(60));
      expect(controller.items.length, 61);
      expect(controller.isScanningComplete, isTrue);
      expect(scanningStates.last, isTrue);
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

  test(
    'controller deletes selected import items from external storage',
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
      controller.toggleSelection('a');
      await controller.deleteSelectedItems();

      expect(controller.items.map((item) => item.id), ['b']);
      expect(controller.trashedItems, isEmpty);
      expect(controller.selectedIds, isEmpty);
      expect(repo.deletedIds, ['a']);
      expect(controller.completionMessage, '已从储存卡删除 1 个项目');
    },
  );

  test(
    'controller deletes multiple selected import items in one batch',
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
      controller.toggleSelection('a');
      controller.toggleSelection('b');
      await controller.deleteSelectedItems();

      expect(controller.items, isEmpty);
      expect(controller.selectedIds, isEmpty);
      expect(repo.deletedIds, ['a', 'b']);
      expect(controller.completionMessage, '已从储存卡删除 2 个项目');
    },
  );

  test('controller keeps selected items when external delete fails', () async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
      ),
    ]);
    repo.failingDeleteIds.add('a');
    final controller = ImportController(repository: repo);

    await controller.refresh();
    controller.toggleSelection('a');
    await controller.deleteSelectedItems();

    expect(controller.items.map((item) => item.id), ['a']);
    expect(controller.selectedIds, {'a'});
    expect(repo.deletedIds, isEmpty);
    expect(controller.statusMessage, '删除失败，请确认储存卡目录允许写入后重试。');
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
    'controller imports selected items into explicit album target',
    () async {
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
      await controller.importSelected(
        albumTarget: ImportAlbumTarget.existing(
          id: 'bucket-1',
          name: '相机导入',
          relativePath: 'DCIM/相机导入',
        ),
      );

      expect(repo.importedAlbumTargets.single.id, 'bucket-1');
      expect(repo.importedAlbumTargets.single.relativePath, 'DCIM/相机导入');
    },
  );

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

  test(
    'controller uses native background import batch when available',
    () async {
      final repo = BackgroundBatchFakeExternalImportRepository([
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
      await controller.importSelected();

      expect(repo.backgroundImportIds, ['a', 'b']);
      expect(repo.importedIds, isEmpty);
      expect(controller.statusFor('a'), ImportItemStatus.imported);
      expect(controller.statusFor('b'), ImportItemStatus.failed);
      expect(controller.selectedIds, {'b'});
      expect(controller.importTotalCount, 2);
      expect(controller.importCompletedCount, 2);
      expect(controller.statusMessage, '部分照片导入失败，可重新选择后重试。');
    },
  );

  test(
    'controller resumes a running native background import after refresh',
    () async {
      final repo = ResumingBackgroundBatchFakeExternalImportRepository([
        ExternalImportItem(
          id: 'a',
          type: MediaType.photo,
          displayName: 'a.jpg',
          pathOrUri: 'content://doc/a',
        ),
      ]);
      final controller = ImportController(repository: repo);

      await controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(controller.statusFor('a'), ImportItemStatus.imported);
      expect(controller.importTotalCount, 1);
      expect(controller.importCompletedCount, 1);
      expect(controller.isImporting, isFalse);
    },
  );
}

class PagingFakeExternalImportRepository extends FakeExternalImportRepository {
  PagingFakeExternalImportRepository(super.items);

  final List<int> requestedOffsets = <int>[];

  @override
  Future<ExternalImportScanPage> scanImportRootPage({
    required int offset,
    required int limit,
    bool includeRaw = false,
  }) async {
    requestedOffsets.add(offset);
    await Future<void>.delayed(Duration.zero);
    return super.scanImportRootPage(
      offset: offset,
      limit: limit,
      includeRaw: includeRaw,
    );
  }
}

class BackgroundBatchFakeExternalImportRepository
    extends FakeExternalImportRepository {
  BackgroundBatchFakeExternalImportRepository(super.items);

  final List<String> backgroundImportIds = <String>[];

  @override
  Future<bool> startBackgroundImport(
    List<ExternalImportItem> items, {
    required ImportAlbumTarget albumTarget,
  }) async {
    backgroundImportIds.addAll(items.map((item) => item.id));
    return true;
  }

  @override
  Future<ExternalImportBatchStatus?> getBackgroundImportStatus() async {
    return const ExternalImportBatchStatus(
      running: false,
      totalCount: 2,
      completedCount: 2,
      importedIds: {'a'},
      failedIds: {'b'},
    );
  }
}

class ResumingBackgroundBatchFakeExternalImportRepository
    extends FakeExternalImportRepository {
  ResumingBackgroundBatchFakeExternalImportRepository(super.items);

  var statusReads = 0;

  @override
  Future<ExternalImportBatchStatus?> getBackgroundImportStatus() async {
    statusReads += 1;
    if (statusReads == 1) {
      return const ExternalImportBatchStatus(
        running: true,
        totalCount: 1,
        completedCount: 0,
        importedIds: {},
        failedIds: {},
      );
    }
    return const ExternalImportBatchStatus(
      running: false,
      totalCount: 1,
      completedCount: 1,
      importedIds: {'a'},
      failedIds: {},
    );
  }
}
