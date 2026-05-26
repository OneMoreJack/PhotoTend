import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';
import 'package:rephoto/features/import/import_page.dart';
import 'package:rephoto/theme/huashu_theme.dart';

void main() {
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
    expect(snackBar.backgroundColor, HuashuColors.positive);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('导入完成'), findsOneWidget);
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
