import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';
import 'package:rephoto/features/import/import_page.dart';
import 'package:rephoto/l10n/app_localizations.dart';
import 'package:rephoto/theme/huashu_theme.dart';

void main() {
  testWidgets('import page renders English empty state and actions', (
    tester,
  ) async {
    final controller = ImportController(
      repository: FakeExternalImportRepository([]),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import'), findsOneWidget);
    expect(find.text('No importable content found'), findsOneWidget);
    expect(find.text('Choose Storage Source'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('import page keeps album picker in header and actions in menu', (
    tester,
  ) async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime(2026, 5, 20),
        sizeBytes: 1024,
      ),
      ExternalImportItem(
        id: 'raw',
        type: MediaType.photo,
        displayName: 'a.nef',
        pathOrUri: 'content://doc/raw',
        createdAt: DateTime(2026, 5, 20),
        sizeBytes: 2048,
      ),
    ]);
    final controller = ImportController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(home: ImportPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-album-picker-btn')), findsOneWidget);
    expect(find.text('导入至:'), findsNothing);
    expect(find.byKey(const Key('import-bottom-summary')), findsOneWidget);
    expect(find.text('待导入'), findsOneWidget);
    expect(find.text('1 个项目 · 1.0 KB'), findsOneWidget);
    expect(find.byTooltip('选择储存卡'), findsNothing);
    expect(find.byTooltip('刷新'), findsNothing);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('导入全部'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-more-actions-btn')));
    await tester.pumpAndSettle();

    expect(find.text('重选储存卡'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('加载 RAW 文件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-toggle-raw-menu-item')));
    await tester.pumpAndSettle();

    expect(controller.includeRaw, isTrue);
    expect(find.text('2 个项目 · 3.0 KB'), findsOneWidget);
  });

  testWidgets('import progress hides count while scanning total is unknown', (
    tester,
  ) async {
    final repo = BlockingSecondPageImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime(2026, 5, 20),
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
        createdAt: DateTime(2026, 5, 19),
      ),
    ]);
    final controller = ImportController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(home: ImportPage(controller: controller)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('正在扫描'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('0/0'), findsNothing);

    repo.completeSecondPage();
    await tester.pumpAndSettle();
  });

  testWidgets('selected items can import before storage scan completes', (
    tester,
  ) async {
    final repo = BlockingSecondPageImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime(2026, 5, 20),
      ),
      ExternalImportItem(
        id: 'b',
        type: MediaType.photo,
        displayName: 'b.jpg',
        pathOrUri: 'content://doc/b',
        createdAt: DateTime(2026, 5, 19),
      ),
    ]);
    final controller = ImportController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(home: ImportPage(controller: controller)),
    );
    await tester.runAsync(() async {
      for (var index = 0; index < 20 && controller.items.isEmpty; index += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();

    expect(controller.items.map((item) => item.id), ['a']);
    controller.toggleSelection('a');
    await tester.pump();

    final importFinder = find.byWidgetPredicate(
      (widget) => widget is FilledButton,
    );
    final importButton = tester.widget<FilledButton>(importFinder);
    expect(importButton.onPressed, isNotNull);

    await tester.tap(importFinder);
    await tester.pump();
    await tester.pump();

    expect(repo.importedIds, ['a']);

    repo.completeSecondPage();
    await tester.pumpAndSettle();
  });

  testWidgets('successful import uses the shared success toast style', (
    tester,
  ) async {
    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime(2026, 5, 20),
      ),
    ]);
    final controller = ImportController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        theme: HuashuTheme.build(),
        home: ImportPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入全部'));
    await tester.pump();
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final snackBarMargin = snackBar.margin! as EdgeInsets;
    expect(snackBar.backgroundColor, HuashuColors.positive);
    expect(snackBarMargin.top, greaterThan(0));
    expect(snackBarMargin.bottom, greaterThan(100));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('导入完成'), findsOneWidget);
    expect(repo.importedAlbumTargets.single.systemLibrary, isTrue);
  });

  testWidgets('album picker uses existing system album target', (tester) async {
    const mediaChannel = MethodChannelMobileMediaRepository.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
          if (call.method == 'fetchUserAlbums') {
            return [
              {
                'id': 'bucket-camera-import',
                'name': '相机导入',
                'count': 840,
                'relativePath': 'DCIM/相机导入',
              },
            ];
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mediaChannel, null);
    });

    final repo = FakeExternalImportRepository([
      ExternalImportItem(
        id: 'a',
        type: MediaType.photo,
        displayName: 'a.jpg',
        pathOrUri: 'content://doc/a',
        createdAt: DateTime(2026, 5, 20),
      ),
    ]);
    final controller = ImportController(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        theme: HuashuTheme.build(),
        home: ImportPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-album-picker-btn')));
    await tester.pumpAndSettle();

    expect(find.text('导入到系统媒体库'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.textContaining('DCIM/相机导入'), findsOneWidget);

    await tester.tap(find.text('相机导入').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入全部'));
    await tester.pumpAndSettle();

    expect(repo.importedAlbumTargets.single.id, 'bucket-camera-import');
    expect(repo.importedAlbumTargets.single.name, '相机导入');
    expect(repo.importedAlbumTargets.single.relativePath, 'DCIM/相机导入');
  });

  testWidgets('canceling new album creation keeps current destination', (
    tester,
  ) async {
    const mediaChannel = MethodChannelMobileMediaRepository.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
          if (call.method == 'fetchUserAlbums') {
            return <Map<String, dynamic>>[];
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mediaChannel, null);
    });
    final controller = ImportController(
      repository: FakeExternalImportRepository([
        ExternalImportItem(
          id: 'a',
          type: MediaType.photo,
          displayName: 'a.jpg',
          pathOrUri: 'content://doc/a',
          createdAt: DateTime(2026, 5, 20),
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: HuashuTheme.build(),
        home: ImportPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-album-picker-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建相簿...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('你的图库'), findsOneWidget);
  });
}

class BlockingSecondPageImportRepository extends FakeExternalImportRepository {
  BlockingSecondPageImportRepository(super.items);

  final Completer<void> _secondPageCompleter = Completer<void>();

  @override
  Future<ExternalImportScanPage> scanImportRootPage({
    required int offset,
    required int limit,
    bool includeRaw = false,
  }) async {
    if (offset > 0) {
      await _secondPageCompleter.future;
    }
    final page = await super.scanImportRootPage(
      offset: offset,
      limit: 1,
      includeRaw: includeRaw,
    );
    return ExternalImportScanPage(items: page.items, hasMore: offset == 0);
  }

  void completeSecondPage() {
    if (!_secondPageCompleter.isCompleted) {
      _secondPageCompleter.complete();
    }
  }
}
