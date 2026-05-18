import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/home/home_page.dart';
import 'package:rephoto/features/media/media_browser_page.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:rephoto/theme/huashu_theme.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  const transparentImage = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0x00,
    0x00,
    0x03,
    0x01,
    0x01,
    0x00,
    0x18,
    0xDD,
    0x8D,
    0x18,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  testWidgets('home starts on album summary', (tester) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'recent',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
        ),
        MediaItem(
          id: 'memory',
          type: MediaType.photo,
          createdAt: DateTime(2025, 5, 14),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(
      find.byKey(const Key('album-memory-hero-on-this-day')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('album-recent-card-recent-7-days')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('album-recent-card-all-media')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('current-media-preview')), findsNothing);
  });

  testWidgets('bottom import tab opens the dedicated import page', (
    tester,
  ) async {
    const importChannel = MethodChannel('rephoto/external_import');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(importChannel, (call) async {
          if (call.method == 'getSavedImportRoot') {
            return null;
          }
          if (call.method == 'scanImportRoot') {
            return <Map<String, Object?>>[];
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(importChannel, null);
    });

    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'recent',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('album-nav-import')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-page')), findsOneWidget);
    expect(find.text('导入'), findsWidgets);
  });

  testWidgets('home header exposes settings entry', (tester) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'recent',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(find.text('RePhoto'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Random Pool'), findsOneWidget);
  });

  testWidgets('monthly completion keeps month title and only replay action', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'late',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 20),
        ),
        MediaItem(
          id: 'early',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
        ),
      ],
      seed: 1,
    );
    final month = controller.monthlyAlbumSummaryEntries.first;
    controller.applyCollectionQuery(month.query);
    controller.onSwipeLeftRandom();
    controller.onSwipeLeftRandom();

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();

    expect(find.text('April 2026'), findsOneWidget);
    expect(find.text('当前月份已经浏览完毕'), findsOneWidget);
    expect(find.text('再看一遍'), findsOneWidget);
    expect(
      find.byKey(const Key('reset-filters-and-restart-button')),
      findsNothing,
    );
  });

  testWidgets('tapping recent shortcut opens the matching browser collection', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'recent-photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(
      find.byKey(const Key('album-recent-card-recent-7-days')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('album-recent-card-recent-7-days')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-browser-page')), findsOneWidget);
    expect(controller.currentMediaId, 'recent-photo');
  });

  testWidgets('home cover renders iOS phasset preview bytes', (tester) async {
    const channel = MethodChannel('rephoto/mobile_media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'fetchPreviewImageData') {
            return Uint8List.fromList(transparentImage);
          }
          return null;
        });

    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'photo-phasset',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
          pathOrUri: 'phasset://photo-phasset',
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byKey(const Key('album-cover-month-2026-04')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('tapping month opens media browser at first item', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'late',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 20),
        ),
        MediaItem(
          id: 'early',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
        ),
      ],
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );
    await tester.ensureVisible(
      find.byKey(const Key('album-month-card-month-2026-04')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('album-month-card-month-2026-04')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-browser-page')), findsOneWidget);
    expect(controller.currentMediaId, 'late');
  });

  testWidgets('completed month shows a done marker on album summary', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'late',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 20),
        ),
        MediaItem(
          id: 'early',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
        ),
      ],
      seed: 1,
    );
    final month = controller.monthlyAlbumSummaryEntries.first;
    controller.applyCollectionQuery(month.query);
    controller.onSwipeLeftRandom();
    controller.onSwipeLeftRandom();

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('album-month-card-month-2026-04')),
        matching: find.byKey(const Key('album-month-completed-month-2026-04')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('album summary groups months by year without collapsing years', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'current',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 20),
          sizeBytes: 1024,
        ),
        MediaItem(
          id: 'old',
          type: MediaType.video,
          createdAt: DateTime(2025, 1, 1),
          sizeBytes: 2048,
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(find.text('按年份'), findsNothing);
    expect(find.text('年份'), findsNothing);
    expect(
      find.byKey(const Key('album-month-card-month-2026-04')),
      findsOneWidget,
    );
    expect(find.text('1 张照片 · 1 个视频 · 300 B'), findsNothing);
    expect(find.text('2025年1月'), findsNothing);
    expect(find.text('April'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('January'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('January'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-browser-page')), findsOneWidget);
    expect(controller.currentMediaId, 'old');
  });

  testWidgets(
    'album summary lays out week and all-photo shortcuts in one row',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'recent',
            type: MediaType.photo,
            createdAt: DateTime(2026, 5, 14),
          ),
          MediaItem(
            id: 'older',
            type: MediaType.video,
            createdAt: DateTime(2026, 4, 20),
          ),
        ],
        nowProvider: () => DateTime(2026, 5, 15),
        seed: 1,
      );

      await tester.pumpWidget(
        MaterialApp(home: HomePage(controller: controller)),
      );

      expect(find.text('近三天'), findsNothing);
      expect(find.text('近一周'), findsOneWidget);
      expect(find.text('所有照片'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      final weekTop = tester.getTopLeft(find.text('近一周')).dy;
      final allTop = tester.getTopLeft(find.text('所有照片')).dy;
      expect((weekTop - allTop).abs(), lessThan(1));

      final weekRight = tester
          .getTopRight(find.byKey(const Key('album-recent-card-recent-7-days')))
          .dx;
      final allLeft = tester
          .getTopLeft(find.byKey(const Key('album-recent-card-all-media')))
          .dx;
      expect(weekRight, lessThan(allLeft));
    },
  );

  testWidgets('month stats render photo video and storage as matching items', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 1),
          sizeBytes: 1024,
        ),
        MediaItem(
          id: 'video',
          type: MediaType.video,
          createdAt: DateTime(2026, 5, 2),
          sizeBytes: 2048,
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    final monthCard = find.byKey(const Key('album-month-card-month-2026-05'));
    expect(monthCard, findsOneWidget);
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-photos-month-2026-05')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-videos-month-2026-05')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-size-month-2026-05')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byIcon(Icons.sd_storage_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('month stats hide zero-value video and storage items', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 1),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    final monthCard = find.byKey(const Key('album-month-card-month-2026-05'));
    expect(monthCard, findsOneWidget);
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-photos-month-2026-05')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-videos-month-2026-05')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: monthCard,
        matching: find.byKey(const Key('album-stat-size-month-2026-05')),
      ),
      findsNothing,
    );
  });

  testWidgets('on this day hero is taller with a cover image background', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'memory',
          type: MediaType.photo,
          createdAt: DateTime(2025, 5, 14),
          pathOrUri: '/tmp/mock-memory.jpg',
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    final hero = find.byKey(const Key('album-memory-hero-on-this-day'));
    expect(tester.getSize(hero).height, greaterThanOrEqualTo(150));

    final image = tester.widget<Image>(
      find.descendant(of: hero, matching: find.byType(Image)).first,
    );
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('home trash button opens trash page', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 0,
    );
    controller.onSwipeUpDelete();

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    await tester.tap(find.byTooltip('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Trash'), findsOneWidget);
    expect(
      find.byKey(Key('trash-grid-item-${controller.trashIds.first}')),
      findsOneWidget,
    );
  });

  testWidgets('swipe up sends current media to trash', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 0,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.drag(find.byType(MediaBrowserPage), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-badge-text')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('swipe left shows another media and swipe down undoes delete', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    final initialId = controller.currentMediaId;
    await tester.drag(find.byType(MediaBrowserPage), const Offset(-400, 0));
    await tester.pumpAndSettle();
    final afterLeftId = controller.currentMediaId;
    expect(afterLeftId, isNot(initialId));

    await tester.drag(find.byType(MediaBrowserPage), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trash-badge-text')), findsOneWidget);

    controller.onSwipeDownUndoDelete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trash-badge-text')), findsNothing);
  });

  testWidgets('horizontal swipe prerenders the target media behind card', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 14),
          pathOrUri: '/tmp/a.jpg',
        ),
        MediaItem(
          id: 'b',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
          pathOrUri: '/tmp/b.jpg',
        ),
      ],
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MediaBrowserPage)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    expect(
      find.byKey(const Key('transition-backdrop-preview')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('accepted horizontal swipe switches media before fly-out ends', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 14),
          pathOrUri: '/tmp/a.jpg',
        ),
        MediaItem(
          id: 'b',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
          pathOrUri: '/tmp/b.jpg',
        ),
      ],
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();

    final initialId = controller.currentMediaId;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MediaBrowserPage)),
    );
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.currentMediaId, isNot(initialId));
    expect(find.byKey(const Key('outgoing-media-preview')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('dragging video progress does not switch browser card', (
    tester,
  ) async {
    VideoPlayerPlatform.instance = _HomeFakeVideoPlayerPlatform();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'v1',
          type: MediaType.video,
          createdAt: DateTime(2026, 5, 14),
          pathOrUri: '/tmp/v1.mp4',
        ),
        MediaItem(
          id: 'p2',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
          pathOrUri: '/tmp/p2.jpg',
        ),
      ],
      seed: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final initialId = controller.currentMediaId;
    final progressBar = find.byKey(const Key('video-progress-bar'));
    expect(progressBar, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(progressBar));
    await tester.pump();
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.currentMediaId, initialId);
  });

  testWidgets('media browser does not show the top time filter button', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.text('全部时间'), findsNothing);
    expect(find.text('自定义…'), findsNothing);
  });

  testWidgets('side menu opens from left icon and contains settings entry', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('import folder replaces media set in home controller', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    String? importedPath;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaBrowserPage(
          controller: controller,
          pickDirectoryPath: () async => '/tmp/mock-import',
          scanImportedDirectory: (path) async {
            importedPath = path;
            return [
              MediaItem(
                id: 'imported-1',
                type: MediaType.photo,
                createdAt: DateTime.now(),
                pathOrUri: '/tmp/mock-import/imported-1.jpg',
              ),
            ];
          },
        ),
      ),
    );

    expect(find.text('Import Folder'), findsNothing);
    await tester.tap(find.byKey(const Key('browser-more-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Import Folder'), findsOneWidget);

    await tester.tap(find.text('Import Folder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(importedPath, '/tmp/mock-import');
    expect(controller.filteredMediaIds, ['imported-1']);
  });

  testWidgets('home without injected controller does not use mock media ids', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MediaBrowserPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RePhoto'), findsOneWidget);
    expect(find.textContaining('m1'), findsNothing);
  });

  testWidgets('home bootstraps media library and clears loading status', (
    tester,
  ) async {
    const permissionsChannel = MethodChannel('rephoto/mobile_permissions');
    const mediaChannel = MethodChannel('rephoto/mobile_media');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, (call) async {
          if (call.method == 'requestMediaReadPermission') {
            return 'granted';
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
          if (call.method == 'fetchMediaPage') {
            final args = call.arguments as Map<dynamic, dynamic>;
            if (args['offset'] == 0) {
              return [
                {
                  'id': 'device-photo',
                  'type': 'photo',
                  'createdAtMillis': 1775001600000,
                  'pathOrUri': 'content://device-photo',
                  'sizeBytes': 1024,
                },
              ];
            }
            return const <Map<String, Object?>>[];
          }
          return null;
        });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('正在加载媒体库…'), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('正在加载媒体库…'), findsNothing);
    expect(
      find.byKey(const Key('album-month-card-month-2026-04')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.photo_outlined), findsWidgets);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, null);
  });

  testWidgets(
    'photo preview renders image widget when file path is available',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'photo-file',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            pathOrUri: '/tmp/mock-photo.jpg',
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );

      expect(find.byKey(const Key('current-media-preview')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('current-media-preview')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'photo preview renders image widget when iOS phasset thumbnail bytes are available',
    (tester) async {
      const channel = MethodChannel('rephoto/mobile_media');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'fetchPreviewImageData') {
              return Uint8List.fromList(transparentImage);
            }
            return null;
          });

      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'photo-phasset',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            pathOrUri: 'phasset://photo-phasset',
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('current-media-preview')), findsOneWidget);
      expect(find.text('Preview unavailable'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('current-media-preview')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets('live photo preview renders playable video tile', (tester) async {
    VideoPlayerPlatform.instance = _HomeFakeVideoPlayerPlatform();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'live-photo',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          pathOrUri: 'phasset://live-photo',
          livePhotoVideoUri: 'file:///tmp/live-photo.mov',
        ),
      ],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(VideoTile), findsOneWidget);
    expect(find.byKey(const Key('video-play-overlay')), findsOneWidget);
  });

  testWidgets(
    'photo preview renders image widget when Android content thumbnail bytes are available',
    (tester) async {
      const channel = MethodChannel('rephoto/mobile_media');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'fetchPreviewImageData') {
              return Uint8List.fromList(transparentImage);
            }
            return null;
          });

      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'photo-content',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            pathOrUri: 'content://media/photo-content',
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('current-media-preview')), findsOneWidget);
      expect(find.text('Preview unavailable'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('current-media-preview')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets(
    'video preview shows image placeholder while iOS phasset video is unresolved',
    (tester) async {
      const channel = MethodChannel('rephoto/mobile_media');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'fetchPreviewImageData') {
              return Uint8List.fromList(transparentImage);
            }
            if (call.method == 'resolvePlayableMediaUri') {
              return null;
            }
            return null;
          });

      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'video-phasset',
            type: MediaType.video,
            createdAt: DateTime.now(),
            pathOrUri: 'phasset://video-phasset',
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Preview unavailable'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets('main page shows filter label only when active', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.text('RePhoto'), findsNothing);
    // When filter is 'All Time', no filter label in AppBar
    expect(find.text('All Time'), findsNothing);
  });

  testWidgets('media metadata is shown from the bottom info sheet', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime(2026, 3, 14),
          locationKey: 'CN/广东省/深圳市/福田区/@22.54010,114.06010',
          pathOrUri: '/tmp/a.jpg',
          sizeBytes: 16 * 1024 * 1024,
        ),
      ],
      seed: 1,
    );
    controller.setDeviceModelForId('a', 'NIKON D5600');

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();

    expect(find.byKey(const Key('current-day-chip')), findsNothing);
    expect(find.byKey(const Key('current-device-chip')), findsNothing);
    expect(find.byKey(const Key('location-filter-btn')), findsNothing);

    await tester.tap(find.byKey(const Key('browser-info-btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('media-info-sheet')), findsOneWidget);
    expect(find.text('2026-03-14'), findsOneWidget);
    expect(find.text('NIKON D5600'), findsOneWidget);
    expect(find.text('深圳市 · 福田区'), findsOneWidget);
    expect(find.text('16 MB'), findsOneWidget);
  });

  testWidgets('reset random pool is moved into settings page', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.text('Reset Random Pool'), findsNothing);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Random Pool'), findsOneWidget);
  });

  testWidgets('settings shows cumulative permanent deletion stats', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'p1', type: MediaType.photo, sizeBytes: 1024),
        MediaItem(id: 'v1', type: MediaType.video, sizeBytes: 2048),
      ],
      seed: 1,
    );
    controller.recordPermanentDeletionStats({'p1', 'v1'});

    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Cumulative deleted'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(find.text('1 video'), findsOneWidget);
    expect(find.text('3.0 KB saved'), findsOneWidget);
  });

  testWidgets('video only toggle switches controller mode', (tester) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'p1', type: MediaType.photo, createdAt: DateTime.now()),
        MediaItem(id: 'v1', type: MediaType.video, createdAt: DateTime.now()),
      ],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(controller.videoOnlyEnabled, isFalse);
    await tester.tap(find.byKey(const Key('video-only-btn')));
    await tester.pumpAndSettle();
    expect(controller.videoOnlyEnabled, isTrue);
  });

  testWidgets('browse mode defaults to sequential and toggles to random', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(controller.browseMode, BrowseMode.sequential);
    expect(
      find.descendant(
        of: find.byKey(const Key('browse-mode-btn')),
        matching: find.byIcon(Icons.format_list_numbered_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('browse-mode-btn')));
    await tester.pumpAndSettle();

    expect(controller.browseMode, BrowseMode.random);
    final activeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('browse-mode-btn')),
        matching: find.byIcon(Icons.shuffle_rounded),
      ),
    );
    expect(activeIcon.color, HuashuColors.inkSoft);
  });

  testWidgets('trash badge is shown only when trash has items', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 0,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(find.byKey(const Key('trash-badge-text')), findsNothing);

    await tester.drag(find.byType(MediaBrowserPage), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-badge-text')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.drag(find.byType(MediaBrowserPage), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-badge-text')), findsNothing);
  });

  testWidgets('system back from trash still syncs updated trash ids to home', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 0,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    await tester.drag(find.byType(MediaBrowserPage), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trash-badge-text')), findsOneWidget);

    await tester.tap(find.byTooltip('Trash'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(Key('trash-grid-item-${controller.trashIds.first}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash-bottom-restore-btn')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-badge-text')), findsNothing);
  });

  testWidgets(
    'end status replay button restarts without reset-filters action',
    (tester) async {
      final now = DateTime.now();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(id: 'a', type: MediaType.photo, createdAt: now),
        ],
        seed: 1,
      );
      controller.currentMediaId = null;
      expect(controller.currentMediaId, isNull);

      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();

      expect(find.text('当前月份已经浏览完毕'), findsOneWidget);
      expect(find.text('再看一遍'), findsOneWidget);
      expect(
        find.byKey(const Key('reset-filters-and-restart-button')),
        findsNothing,
      );
      final replayButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('end-replay-button')),
      );
      replayButton.onPressed?.call();
      await tester.pumpAndSettle();

      expect(controller.currentMediaId, isNotNull);
    },
  );

  testWidgets('startup loading should not show completed-browsing card', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MediaBrowserPage()));
    await tester.pump();

    expect(find.byKey(const Key('mobile-library-status')), findsOneWidget);
    expect(find.text('当前月份已经浏览完毕'), findsNothing);
  });

  testWidgets(
    'share button opens the share sheet directly when media is shareable',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'a',
            type: MediaType.photo,
            createdAt: DateTime(2026, 5, 1),
            pathOrUri: '/tmp/a.jpg',
          ),
          MediaItem(
            id: 'b',
            type: MediaType.photo,
            createdAt: DateTime(2026, 5, 2),
            pathOrUri: '/tmp/b.jpg',
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();

      final browseCenter = tester.getCenter(
        find.byKey(const Key('browse-mode-btn')),
      );
      final videoCenter = tester.getCenter(
        find.byKey(const Key('video-only-btn')),
      );
      final moreCenter = tester.getCenter(
        find.byKey(const Key('browser-more-btn')),
      );

      expect(browseCenter.dx, lessThan(videoCenter.dx));
      expect(videoCenter.dx, lessThan(moreCenter.dx));
      expect(find.text('分享到'), findsNothing);

      await tester.tap(find.byKey(const Key('browser-more-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('分享到'), findsOneWidget);
      expect(find.text('微信'), findsOneWidget);
    },
  );

  testWidgets('geo location is displayed in the info sheet', (tester) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'geo/31.230/121.473',
        ),
      ],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('browser-info-btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('31.230'), findsOneWidget);
    expect(find.textContaining('121.473'), findsOneWidget);
  });

  testWidgets(
    'photo area does not show metadata chips when current photo has no location',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(id: 'a', type: MediaType.photo, createdAt: DateTime.now()),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );
      await tester.pump();

      expect(find.byKey(const Key('location-filter-btn')), findsNothing);
      expect(find.byKey(const Key('current-day-chip')), findsNothing);
    },
  );
}

class _HomeFakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<VideoEvent>> _streams =
      <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(1920, 1080),
        duration: const Duration(minutes: 2),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Widget buildView(int playerId) {
    return ColoredBox(
      color: Colors.black,
      child: Text('video-$playerId', textDirection: TextDirection.ltr),
    );
  }

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      const Duration(seconds: 20);

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
