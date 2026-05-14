import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/media/media_browser_page.dart';

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
    expect(find.byKey(const Key('media-thumbnail-m0')), findsOneWidget);
    expect(find.byKey(const Key('media-thumbnail-m29')), findsNothing);

    await tester.tap(find.byKey(const Key('media-thumbnail-m2')));
    await tester.pumpAndSettle();

    expect(controller.currentMediaId, 'm2');
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
      expect(strip.itemExtent, 52);
      expect(strip.padding, const EdgeInsets.fromLTRB(12, 6, 36, 6));

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
}
