import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/trash/trash_page.dart';

void main() {
  testWidgets('restore and delete buttons use active styling when selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrashPage(initialIds: ['1'])),
    );

    Color buttonBackground(Finder finder) {
      final button = tester.widget<TextButton>(finder);
      return button.style!.backgroundColor!.resolve(<WidgetState>{})!;
    }

    expect(
      buttonBackground(find.byKey(const Key('trash-bottom-restore-btn'))),
      const Color(0xFFF4F5F8),
    );
    expect(
      buttonBackground(find.byKey(const Key('trash-bottom-delete-btn'))),
      const Color(0xFFF4F5F8),
    );

    await tester.tap(find.byKey(const Key('trash-grid-item-1')));
    await tester.pumpAndSettle();

    expect(
      buttonBackground(find.byKey(const Key('trash-bottom-restore-btn'))),
      const Color(0xFFE7F0FF),
    );
    expect(
      buttonBackground(find.byKey(const Key('trash-bottom-delete-btn'))),
      const Color(0xFFFFE3E2),
    );
  });

  testWidgets('bottom bar summarizes trash photo video counts and size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrashPage(
          initialIds: const ['p1', 'v1', 'p2'],
          initialMediaItems: const [
            MediaItem(id: 'p1', type: MediaType.photo, sizeBytes: 1024),
            MediaItem(id: 'v1', type: MediaType.video, sizeBytes: 2048),
            MediaItem(id: 'p2', type: MediaType.photo),
          ],
        ),
      ),
    );

    expect(find.text('2 photos'), findsOneWidget);
    expect(find.text('1 video'), findsOneWidget);
    expect(find.text('3.0 KB+'), findsOneWidget);
  });

  testWidgets('empty trash hides photo video and size stats', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrashPage(initialIds: [])));

    expect(find.text('0 photos'), findsNothing);
    expect(find.text('0 videos'), findsNothing);
    expect(find.text('0 B'), findsNothing);
    expect(find.byKey(const Key('trash-bottom-stats')), findsNothing);
  });

  testWidgets('restore selected removes item from trash list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrashPage(initialIds: ['1', '2'])),
    );

    await tester.tap(find.byKey(const Key('trash-grid-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash-bottom-restore-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-grid-item-1')), findsNothing);
    expect(find.byKey(const Key('trash-grid-item-2')), findsOneWidget);
  });

  testWidgets(
    'delete all permanently skips app confirmation and clears entries',
    (tester) async {
      final service = PermanentDeleteService(
        fakeDeleteResult: const {'1': true, '2': true},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrashPage(initialIds: const ['1', '2'], deleteService: service),
        ),
      );

      await tester.tap(find.byKey(const Key('trash-bottom-empty-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Permanent Delete'), findsNothing);
      expect(find.byKey(const Key('trash-grid-item-1')), findsNothing);
      expect(find.byKey(const Key('trash-grid-item-2')), findsNothing);
    },
  );

  testWidgets('delete selected permanently shows failure retry hint', (
    tester,
  ) async {
    final service = PermanentDeleteService(
      fakeDeleteResult: const {'1': false, '2': true},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrashPage(initialIds: const ['1', '2'], deleteService: service),
      ),
    );

    await tester.tap(find.byKey(const Key('trash-grid-item-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trash-bottom-delete-btn')));
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to permanently delete 1 item(s). Retry from trash.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trash-grid-item-1')), findsOneWidget);
  });

  testWidgets(
    'delete selected permanently shows mixed success and failure counts',
    (tester) async {
      final service = PermanentDeleteService(
        fakeDeleteResult: const {'1': false, '2': true},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrashPage(initialIds: const ['1', '2'], deleteService: service),
        ),
      );

      await tester.tap(find.byKey(const Key('trash-grid-item-1')));
      await tester.tap(find.byKey(const Key('trash-grid-item-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trash-bottom-delete-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Permanently deleted 1 item(s), failed 1 item(s). Retry from trash.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('delete selected shows deleting progress state', (tester) async {
    final service = PermanentDeleteService(
      fakeDeleteResult: const {'1': true},
      simulatedDelay: const Duration(milliseconds: 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TrashPage(initialIds: const ['1'], deleteService: service),
      ),
    );

    await tester.tap(find.byKey(const Key('trash-grid-item-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trash-bottom-delete-btn')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Deleting...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Deleting...'), findsNothing);
  });

  testWidgets('renders media in photo-grid style', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrashPage(
          initialIds: const ['v1', 'p1'],
          initialMediaItems: const [
            MediaItem(id: 'v1', type: MediaType.video),
            MediaItem(id: 'p1', type: MediaType.photo),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('trash-grid-item-v1')), findsOneWidget);
    expect(find.byKey(const Key('trash-grid-item-p1')), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    expect(find.byKey(const Key('trash-bottom-bar')), findsOneWidget);
  });

  testWidgets('unselected trash media keeps original color rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrashPage(initialIds: ['p1', 'p2'])),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('trash-grid-item-p1')),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
    );
  });

  testWidgets('grid view does not expose raw media ids as list text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrashPage(
          initialIds: const ['v1'],
          initialMediaItems: [
            MediaItem(
              id: 'v1',
              type: MediaType.video,
              createdAt: DateTime(2024, 1, 2, 10, 20),
              locationKey: 'CN/SH/XH',
            ),
          ],
        ),
      ),
    );

    expect(find.text('v1'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('select all icon toggles all trash items selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrashPage(initialIds: ['1', '2'])),
    );

    await tester.tap(find.byTooltip('Select All'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trash-bottom-restore-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-grid-item-1')), findsNothing);
    expect(find.byKey(const Key('trash-grid-item-2')), findsNothing);
  });

  testWidgets('trash grid uses more columns on wider screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: TrashPage(initialIds: ['1', '2', '3', '4'])),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(5));
  });
}
