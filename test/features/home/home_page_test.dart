import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/home/home_page.dart';
import 'package:rephoto/features/media/media_browser_page.dart';

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
      find.byKey(const Key('album-recent-card-recent-3-days')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('album-recent-card-recent-7-days')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('current-media-preview')), findsNothing);
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
      find.byKey(const Key('album-recent-card-recent-3-days')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('album-recent-card-recent-3-days')));
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
    await tester.tap(find.byKey(const Key('album-month-card-month-2026-04')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-browser-page')), findsOneWidget);
    expect(controller.currentMediaId, 'late');
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
    expect(find.textContaining('1 Photos'), findsWidgets);

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

  testWidgets(
    'current day chip activates overlay filter without changing time filter bar',
    (tester) async {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(id: 'a', type: MediaType.photo, createdAt: DateTime.now()),
          MediaItem(
            id: 'b',
            type: MediaType.photo,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
        seed: 1,
      );
      await tester.pumpWidget(
        MaterialApp(home: MediaBrowserPage(controller: controller)),
      );

      expect(controller.selectedTimeFilter, TimeFilterPreset.all);
      expect(controller.hasOverlayDayFilter, isFalse);

      await tester.tap(find.byKey(const Key('current-day-chip')));
      await tester.pumpAndSettle();
      // Time filter bar must NOT change — overlay is independent
      expect(controller.selectedTimeFilter, TimeFilterPreset.all);
      expect(controller.hasOverlayDayFilter, isTrue);

      await tester.tap(find.byKey(const Key('current-day-chip')));
      await tester.pumpAndSettle();
      expect(controller.selectedTimeFilter, TimeFilterPreset.all);
      expect(controller.hasOverlayDayFilter, isFalse);
    },
  );

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

  testWidgets('browse mode toggle switches to sequential mode', (tester) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );

    expect(controller.browseMode, BrowseMode.random);
    await tester.tap(find.byKey(const Key('browse-mode-btn')));
    await tester.pumpAndSettle();

    expect(controller.browseMode, BrowseMode.sequential);
    final activeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('browse-mode-btn')),
        matching: find.byIcon(Icons.format_list_numbered_rounded),
      ),
    );
    expect(activeIcon.color, const Color(0xFF0066D6));
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
    'end status reset-filters button restores defaults and restarts',
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
      await tester.pumpAndSettle();

      expect(find.text('已浏览完当前条件下的所有照片'), findsOneWidget);
      expect(find.text('再看一遍'), findsOneWidget);
      expect(find.text('重新开始'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('reset-filters-and-restart-button')),
      );
      await tester.tap(
        find.byKey(const Key('reset-filters-and-restart-button')),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedTimeFilter, TimeFilterPreset.all);
      expect(controller.currentMediaId, isNotNull);
    },
  );

  testWidgets('startup loading should not show completed-browsing card', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MediaBrowserPage()));
    await tester.pump();

    expect(find.byKey(const Key('mobile-library-status')), findsOneWidget);
    expect(find.text('已浏览完当前条件下的所有照片'), findsNothing);
  });

  testWidgets('bottom action buttons order is browse then video then more', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('open-in-gallery-btn')), findsNothing);

    await tester.tap(find.byKey(const Key('browser-more-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-in-gallery-btn')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('geo location is displayed in location lock chip', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-filter-btn')), findsOneWidget);
    expect(find.textContaining('31.230'), findsOneWidget);
    expect(find.textContaining('121.473'), findsOneWidget);
  });

  testWidgets(
    'location filter icon is hidden when current photo has no location',
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
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-filter-btn')), findsNothing);
    },
  );

  testWidgets('tap location lock chip toggles location filter on and off', (
    tester,
  ) async {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'CN/广东省/深圳市/福田区/@22.54010,114.06010',
        ),
        MediaItem(
          id: 'b',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'CN/广东省/深圳市/福田区/@22.54321,114.05888',
        ),
      ],
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(home: MediaBrowserPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-filter-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-filter-btn')));
    await tester.pumpAndSettle();
    expect(controller.filteredMediaIds.length, 1);

    await tester.tap(find.byKey(const Key('location-filter-btn')));
    await tester.pumpAndSettle();
    expect(controller.filteredMediaIds.length, 2);
  });
}
