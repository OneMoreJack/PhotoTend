import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';
import 'package:rephoto/features/import/import_page.dart';

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
}
