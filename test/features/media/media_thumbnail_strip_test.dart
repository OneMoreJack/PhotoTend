import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/media/media_browser_page.dart';
import 'package:rephoto/features/media/widgets/media_thumbnail_strip.dart';

void main() {
  testWidgets('thumbnail strip lazily renders visible media and jumps on tap', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: List.generate(
        30,
        (index) => MediaItem(
          id: 'm$index',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, index + 1),
        ),
      ),
      seed: 1,
    );
    controller.applyCollectionQuery(
      MediaCollectionQuery(
        title: '2026年4月',
        timeStart: DateTime(2026, 4),
        timeEnd: DateTime(2026, 5).subtract(const Duration(milliseconds: 1)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.byKey(const Key('media-thumbnail-strip')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m29')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m0')), findsNothing);

    await tester.tap(find.byKey(const Key('media-thumbnail-m27')));
    await tester.pumpAndSettle();

    expect(controller.currentMediaId, 'm27');
  });

  testWidgets('thumbnail strip excludes trashed media', (tester) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'm0',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
        ),
        MediaItem(
          id: 'm1',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 2),
        ),
        MediaItem(
          id: 'm2',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 3),
        ),
      ],
      seed: 1,
    );
    controller.applyCollectionQuery(
      MediaCollectionQuery(
        title: '2026年4月',
        timeStart: DateTime(2026, 4),
        timeEnd: DateTime(2026, 5).subtract(const Duration(milliseconds: 1)),
      ),
    );
    controller.updateTrash({'m0'});

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.byKey(const Key('media-thumbnail-strip')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m0')), findsNothing);
    expect(find.byKey(const Key('media-thumbnail-m1')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m2')), findsOneWidget);
  });

  testWidgets(
    'video thumbnails without preview bytes use compact placeholder',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'video-local',
            type: MediaType.video,
            createdAt: DateTime(2026, 4, 1),
            pathOrUri: '/tmp/video.mp4',
          ),
        ],
        seed: 1,
      );

      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );

      final strip = tester.widget<ListView>(
        find.descendant(
          of: find.byKey(const Key('media-thumbnail-strip')),
          matching: find.byType(ListView),
        ),
      );
      expect(strip.itemExtent, 66);
      expect(strip.padding, const EdgeInsets.fromLTRB(12, 8, 36, 8));

      final thumbnail = find.byKey(const Key('media-thumbnail-video-local'));
      expect(thumbnail, findsOneWidget);
      expect(
        find.descendant(of: thumbnail, matching: find.byType(Image)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: thumbnail,
          matching: find.byIcon(Icons.play_circle_fill_rounded),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'photo thumbnails without preview bytes show a loading placeholder',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'photo-content',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 1),
            pathOrUri: 'content://photo-content',
          ),
        ],
        seed: 1,
      );

      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );

      final thumbnail = find.byKey(const Key('media-thumbnail-photo-content'));
      expect(thumbnail, findsOneWidget);
      expect(
        find.descendant(
          of: thumbnail,
          matching: find.byKey(
            const Key('media-thumbnail-loading-photo-content'),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('thumbnail strip scrolls selected media into view', (
    tester,
  ) async {
    final items = List.generate(
      30,
      (index) => MediaItem(
        id: 'm$index',
        type: MediaType.photo,
        createdAt: DateTime(2026, 4, index + 1),
      ),
    );
    var currentMediaId = 'm0';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => currentMediaId = 'm29'),
                    child: const Text('Select end'),
                  ),
                  MediaThumbnailStrip(
                    items: items,
                    currentMediaId: currentMediaId,
                    onTap: (id) => setState(() => currentMediaId = id),
                    thumbnailBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.byKey(const Key('media-thumbnail-m0')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m29')), findsNothing);

    await tester.tap(find.text('Select end'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-thumbnail-m29')), findsOneWidget);
  });

  testWidgets(
    'thumbnail strip preserves user scroll when item ids are unchanged',
    (tester) async {
      var items = List.generate(
        30,
        (index) => MediaItem(
          id: 'm$index',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, index + 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => items = List.of(items)),
                      child: const Text('Rebuild'),
                    ),
                    MediaThumbnailStrip(
                      items: items,
                      currentMediaId: 'm0',
                      onTap: (_) {},
                      thumbnailBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.byKey(const Key('media-thumbnail-m0')), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('media-thumbnail-strip')),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media-thumbnail-m0')), findsNothing);

      await tester.tap(find.text('Rebuild'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media-thumbnail-m0')), findsNothing);
    },
  );

  testWidgets(
    'thumbnail strip marks selected item with stable selected state',
    (tester) async {
      final items = [
        MediaItem(
          id: 'm0',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
        ),
        MediaItem(
          id: 'm1',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 2),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaThumbnailStrip(
              items: items,
              currentMediaId: 'm1',
              onTap: (_) {},
              thumbnailBuilder: (_, __, ___) => const ColoredBox(
                color: Colors.black12,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('media-thumbnail-selected-m1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('media-thumbnail-selected-m1')),
          matching: find.byType(AnimatedScale),
        ),
        findsOneWidget,
      );
    },
  );
}
