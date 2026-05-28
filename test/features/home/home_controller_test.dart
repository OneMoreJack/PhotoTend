import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/local/state_store.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/home/home_controller.dart';

void main() {
  test('album summaries exclude trashed media and include top shortcuts', () {
    final now = DateTime(2026, 5, 14, 12);
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'a',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13),
          sizeBytes: 100,
        ),
        MediaItem(
          id: 'b',
          type: MediaType.video,
          createdAt: DateTime(2026, 5, 10),
          sizeBytes: 200,
        ),
        MediaItem(
          id: 'c',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 2),
          sizeBytes: 300,
        ),
      ],
      nowProvider: () => now,
      seed: 1,
    );

    controller.updateTrash({'a'});

    final allMedia = controller.albumSummaryEntries.singleWhere(
      (entry) => entry.id == 'all-media',
    );
    expect(allMedia.photoCount, 1);
    expect(allMedia.videoCount, 1);

    final recent7 = controller.albumSummaryEntries.singleWhere(
      (entry) => entry.id == 'recent-7-days',
    );
    expect(recent7.photoCount, 0);
    expect(recent7.videoCount, 1);
    expect(recent7.knownSizeBytes, 200);
  });

  test('album summaries exclude trash from cover and previews', () {
    final now = DateTime(2026, 5, 14, 12);
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'trashed-cover',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 14, 10),
          pathOrUri: '/tmp/trashed.jpg',
        ),
        MediaItem(
          id: 'kept-photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13, 10),
          pathOrUri: '/tmp/kept.jpg',
        ),
        MediaItem(
          id: 'kept-video',
          type: MediaType.video,
          createdAt: DateTime(2026, 5, 12, 10),
          pathOrUri: '/tmp/kept.mov',
        ),
      ],
      nowProvider: () => now,
      seed: 1,
    );

    controller.updateTrash({'trashed-cover'});

    final allMedia = controller.recentAlbumSummaryEntries.singleWhere(
      (entry) => entry.id == 'all-media',
    );
    expect(allMedia.coverMediaId, 'kept-photo');
    expect(allMedia.previewMediaIds, ['kept-photo', 'kept-video']);
    expect(allMedia.previewMediaIds, isNot(contains('trashed-cover')));
  });

  test('album summary cover prefers photos with path before videos', () {
    final now = DateTime(2026, 5, 14, 12);
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'new-video',
          type: MediaType.video,
          createdAt: DateTime(2026, 5, 14, 11),
          pathOrUri: '/tmp/video.mov',
        ),
        MediaItem(
          id: 'photo-without-path',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 14, 10),
        ),
        MediaItem(
          id: 'photo-with-path',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 13, 10),
          pathOrUri: '/tmp/photo.jpg',
        ),
      ],
      nowProvider: () => now,
      seed: 1,
    );

    final allMedia = controller.recentAlbumSummaryEntries.singleWhere(
      (entry) => entry.id == 'all-media',
    );

    expect(allMedia.coverMediaId, 'photo-with-path');
    expect(allMedia.previewMediaIds.take(3), [
      'new-video',
      'photo-without-path',
      'photo-with-path',
    ]);
  });

  test('on this day memory includes prior years on the same month and day', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'same-day-2025',
          type: MediaType.photo,
          createdAt: DateTime(2025, 5, 14, 9),
          pathOrUri: '/tmp/2025.jpg',
        ),
        MediaItem(
          id: 'same-day-2024',
          type: MediaType.video,
          createdAt: DateTime(2024, 5, 14, 9),
        ),
        MediaItem(
          id: 'same-day-2023',
          type: MediaType.photo,
          createdAt: DateTime(2023, 5, 14, 9),
        ),
        MediaItem(
          id: 'same-day-2022',
          type: MediaType.photo,
          createdAt: DateTime(2022, 5, 14, 9),
        ),
        MediaItem(
          id: 'same-day-2021',
          type: MediaType.photo,
          createdAt: DateTime(2021, 5, 14, 9),
        ),
        MediaItem(
          id: 'today',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 14, 9),
        ),
        MediaItem(
          id: 'other-day',
          type: MediaType.photo,
          createdAt: DateTime(2025, 5, 13, 9),
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14, 12),
      seed: 1,
    );

    final memory = controller.onThisDayMemoryEntry;

    expect(memory.title, '那年今日');
    expect(memory.photoCount, 4);
    expect(memory.videoCount, 1);
    expect(memory.coverMediaId, 'same-day-2025');
    expect(memory.previewMediaIds, [
      'same-day-2025',
      'same-day-2024',
      'same-day-2023',
      'same-day-2022',
      'same-day-2021',
    ]);
    expect(memory.query.mediaIds, {
      'same-day-2025',
      'same-day-2024',
      'same-day-2023',
      'same-day-2022',
      'same-day-2021',
    });
  });

  test('monthly summaries are newest first and count media by type', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'apr-photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 1),
          sizeBytes: 100,
        ),
        MediaItem(
          id: 'apr-video',
          type: MediaType.video,
          createdAt: DateTime(2026, 4, 2),
          sizeBytes: 200,
        ),
        MediaItem(
          id: 'mar-photo',
          type: MediaType.photo,
          createdAt: DateTime(2026, 3, 2),
          sizeBytes: 50,
        ),
      ],
      nowProvider: () => DateTime(2026, 5, 14),
      seed: 1,
    );

    final months = controller.monthlyAlbumSummaryEntries;
    expect(months.map((entry) => entry.id), ['month-2026-04', 'month-2026-03']);
    expect(months.first.photoCount, 1);
    expect(months.first.videoCount, 1);
    expect(months.first.knownSizeBytes, 300);
  });

  test(
    'yearly summary groups current year expanded and older years collapsed',
    () {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'current-photo',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 1),
            sizeBytes: 100,
          ),
          MediaItem(
            id: 'current-video',
            type: MediaType.video,
            createdAt: DateTime(2026, 5, 2),
            sizeBytes: 200,
          ),
          MediaItem(
            id: 'old-photo',
            type: MediaType.photo,
            createdAt: DateTime(2025, 1, 2),
            sizeBytes: 50,
          ),
        ],
        nowProvider: () => DateTime(2026, 5, 14),
        seed: 1,
      );

      final groups = controller.yearlyAlbumSummaryGroups;

      expect(groups.map((group) => group.year), [2026, 2025]);
      expect(groups.first.summary.photoCount, 1);
      expect(groups.first.summary.videoCount, 1);
      expect(groups.first.summary.knownSizeBytes, 300);
      expect(groups.first.defaultExpanded, isTrue);
      expect(groups.first.months.map((entry) => entry.id), [
        'month-2026-05',
        'month-2026-04',
      ]);
      expect(groups.last.defaultExpanded, isFalse);
    },
  );

  test('applying collection query starts from newest matching media', () {
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
        MediaItem(
          id: 'other',
          type: MediaType.photo,
          createdAt: DateTime(2026, 5, 1),
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

    expect(controller.filteredMediaIds, ['late', 'early']);
    expect(controller.currentMediaId, 'late');
  });

  test('jump to media updates current media inside active filtered set', () {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b', 'c'],
      seed: 1,
    );

    controller.jumpToMedia('c');

    expect(controller.currentMediaId, 'c');
    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, isNotNull);
  });

  test('swipe up deletes current and swipe down restores it', () {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b'],
      seed: 1,
    );
    final first = controller.currentMediaId;
    expect(first, isNotNull);

    controller.onSwipeUpDelete();
    expect(controller.trashIds, contains(first));

    controller.onSwipeDownUndoDelete();
    expect(controller.trashIds, isNot(contains(first)));
  });

  test('trash order keeps newest deleted item first', () {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b', 'c'],
      seed: 1,
    );
    final first = controller.currentMediaId!;
    controller.onSwipeUpDelete();

    final second = controller.currentMediaId!;
    controller.onSwipeUpDelete();

    expect(controller.orderedTrashIds, [second, first]);
  });

  test(
    'swipe right goes to previous shown media and skips trashed entries',
    () {
      final controller = HomeController(
        initialMediaIds: const ['a', 'b', 'c'],
        seed: 2,
      );
      controller.toggleBrowseMode();
      final first = controller.currentMediaId!;

      controller.onSwipeLeftRandom();
      final second = controller.currentMediaId!;
      expect(second, isNot(first));

      controller.onSwipeRightPrevious();
      expect(controller.currentMediaId, first);

      controller.onSwipeUpDelete();
      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, isNotNull);

      controller.onSwipeRightPrevious();
      expect(controller.currentMediaId, isNot(first));
      expect(controller.trashIds, contains(first));
    },
  );

  test(
    'swipe left replays forward history before loading a new random media',
    () {
      final controller = HomeController(
        initialMediaIds: const ['a', 'b', 'c', 'd'],
        seed: 2,
      );
      controller.toggleBrowseMode();
      final first = controller.currentMediaId!;

      controller.onSwipeLeftRandom();
      final second = controller.currentMediaId!;
      controller.onSwipeLeftRandom();
      final third = controller.currentMediaId!;
      expect({first, second, third}.length, 3);

      controller.onSwipeRightPrevious();
      expect(controller.currentMediaId, second);

      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, third);

      controller.onSwipeLeftRandom();
      final fourth = controller.currentMediaId!;
      expect(fourth, isNot(third));
      expect({first, second, third, fourth}.length, 4);
    },
  );

  test('preload target prefers forward history when available', () {
    final controller = HomeController(
      initialMediaIds: const ['a', 'b', 'c', 'd'],
      seed: 3,
    );
    controller.toggleBrowseMode();

    controller.onSwipeLeftRandom();
    final second = controller.currentMediaId!;
    controller.onSwipeLeftRandom();
    final third = controller.currentMediaId!;

    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, second);
    expect(controller.prepareUpcomingMediaForPreload()?.id, third);
  });

  test('single-item pool stays visible when swiping next repeatedly', () {
    final controller = HomeController(initialMediaIds: const ['only'], seed: 1);
    expect(controller.currentMediaId, 'only');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'only');
    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'only');
  });

  test(
    'video-only mode filters non-video media and recovers when toggled off',
    () {
      final now = DateTime.now();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(id: 'p1', type: MediaType.photo, createdAt: now),
          MediaItem(id: 'v1', type: MediaType.video, createdAt: now),
          MediaItem(id: 'p2', type: MediaType.photo, createdAt: now),
        ],
        seed: 1,
      );

      controller.toggleVideoOnlyMode();
      expect(controller.videoOnlyEnabled, isTrue);
      expect(controller.filteredMediaIds, ['v1']);
      expect(controller.currentMediaId, 'v1');

      controller.toggleVideoOnlyMode();
      expect(controller.videoOnlyEnabled, isFalse);
      expect(controller.filteredMediaIds, containsAll(['p1', 'v1', 'p2']));
    },
  );

  test('sequential mode uses left for next and right for previous media', () {
    final now = DateTime.now();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'a', type: MediaType.photo, createdAt: now),
        MediaItem(id: 'b', type: MediaType.photo, createdAt: now),
        MediaItem(id: 'c', type: MediaType.photo, createdAt: now),
      ],
      seed: 1,
    );

    expect(controller.browseMode, BrowseMode.sequential);
    controller.currentMediaId = 'b';

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'c');

    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, 'b');

    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, 'a');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'b');
  });

  test('sequential mode wraps outside monthly collections', () {
    final now = DateTime.now();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'a', type: MediaType.photo, createdAt: now),
        MediaItem(id: 'b', type: MediaType.photo, createdAt: now),
        MediaItem(id: 'c', type: MediaType.photo, createdAt: now),
      ],
      seed: 1,
    );

    controller.currentMediaId = 'a';

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'b');

    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, 'a');
  });

  test('monthly collection is marked completed after browsing last item', () {
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
    expect(controller.currentMediaId, 'late');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'early');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, isNull);
    expect(controller.isCollectionCompleted(month.id), isTrue);
  });

  test(
    'completed monthly collection hides browse progress at last media',
    () async {
      final store = InMemoryStateStore();
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
        stateStore: store,
        seed: 1,
      );
      final month = controller.monthlyAlbumSummaryEntries.first;

      controller.applyCollectionQuery(month.query);
      controller.jumpToMedia('early');
      await Future<void>.delayed(Duration.zero);

      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, isNull);
      expect(controller.isCollectionCompleted(month.id), isTrue);

      final resume = await controller.loadActiveBrowseProgress();
      expect(resume, isNull);
    },
  );

  test(
    'completed monthly collection exposes browse progress before last media',
    () async {
      final store = InMemoryStateStore();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'late',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 20),
          ),
          MediaItem(
            id: 'middle',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 10),
          ),
          MediaItem(
            id: 'early',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
        stateStore: store,
        seed: 1,
      );
      final month = controller.monthlyAlbumSummaryEntries.first;

      controller.applyCollectionQuery(month.query);
      controller.jumpToMedia('early');
      controller.onSwipeLeftRandom();
      expect(controller.isCollectionCompleted(month.id), isTrue);

      controller.jumpToMedia('middle');
      await Future<void>.delayed(Duration.zero);
      controller.applyCollectionQuery(month.query);
      expect(controller.currentMediaId, 'late');

      final resume = await controller.loadActiveBrowseProgress();
      expect(resume?.mediaId, 'middle');
    },
  );

  test(
    'random pool returns null after exhaustion and reset makes items available again',
    () {
      final controller = HomeController(
        initialMediaIds: const ['a', 'b'],
        seed: 0,
      );
      controller.toggleBrowseMode();
      expect(controller.browseMode, BrowseMode.random);
      final first = controller.currentMediaId!;

      controller.onSwipeLeftRandom();
      final second = controller.currentMediaId!;
      expect(second, isNot(first));

      // Pool exhausted — swipe left keeps showing the last photo
      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, second);
      expect(controller.isPoolExhausted, isTrue);

      // After reset, can browse again
      controller.resetRandomPool();
      expect(controller.isPoolExhausted, isFalse);
      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, anyOf('a', 'b'));
    },
  );

  test('time and location filters constrain random candidate set', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'today-sh',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'CN/SH/XH',
        ),
        MediaItem(
          id: 'today-bj',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'CN/BJ/HD',
        ),
        MediaItem(
          id: 'old-sh',
          type: MediaType.photo,
          createdAt: DateTime.now().subtract(const Duration(days: 200)),
          locationKey: 'CN/SH/XH',
        ),
      ],
      seed: 1,
    );

    controller.setTimeFilter(TimeFilterPreset.today);
    controller.setLocationFilter('CN/SH/XH');

    expect(controller.filteredMediaIds, ['today-sh']);
    expect(controller.currentMediaId, 'today-sh');
  });

  test(
    'changing filter starts from the first matching photo and sequential mode continues from there',
    () {
      final now = DateTime.now();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'old',
            type: MediaType.photo,
            createdAt: now.subtract(const Duration(days: 30)),
          ),
          MediaItem(
            id: 'day-1',
            type: MediaType.photo,
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          MediaItem(
            id: 'day-2',
            type: MediaType.photo,
            createdAt: now.subtract(const Duration(days: 1)),
          ),
          MediaItem(id: 'today', type: MediaType.photo, createdAt: now),
        ],
        seed: 7,
      );

      controller.setTimeFilter(TimeFilterPreset.last7Days);

      expect(controller.filteredMediaIds, ['day-1', 'day-2', 'today']);
      expect(controller.currentMediaId, 'day-1');
      expect(controller.prepareUpcomingMediaForPreload()?.id, isNotNull);

      expect(controller.browseMode, BrowseMode.sequential);

      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, 'day-2');

      controller.onSwipeLeftRandom();
      expect(controller.currentMediaId, 'today');
    },
  );

  test(
    'replace media items swaps data source for filtering and random flow',
    () {
      final controller = HomeController(
        initialMediaIds: const ['a', 'b', 'c'],
        seed: 1,
      );

      controller.replaceMediaItems([
        MediaItem(
          id: 'mobile-1',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'US/CA/SF',
          pathOrUri: 'content://mobile-1',
        ),
        MediaItem(
          id: 'mobile-2',
          type: MediaType.video,
          createdAt: DateTime.now(),
          locationKey: 'US/CA/SF',
          pathOrUri: 'content://mobile-2',
        ),
      ]);

      expect(controller.filteredMediaIds, ['mobile-1', 'mobile-2']);
      expect(controller.currentMediaId, anyOf('mobile-1', 'mobile-2'));

      controller.setLocationFilter('US/CA/SF');
      expect(controller.filteredMediaIds.length, 2);
    },
  );

  test('location filter supports unknown location bucket', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'known',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'US/CA/SF',
        ),
        MediaItem(
          id: 'unknown',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: null,
        ),
      ],
      seed: 1,
    );

    expect(
      controller.availableLocationKeys,
      contains(HomeController.unknownLocationLabel),
    );
    controller.setLocationFilter(HomeController.unknownLocationLabel);
    expect(controller.filteredMediaIds, ['unknown']);
  });

  test(
    'hierarchical location filtering works for country/province/city/district',
    () {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'a',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            locationKey: 'CN/SH/SHC/XH',
          ),
          MediaItem(
            id: 'b',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            locationKey: 'CN/SH/SHC/PD',
          ),
          MediaItem(
            id: 'c',
            type: MediaType.photo,
            createdAt: DateTime.now(),
            locationKey: 'CN/BJ/BJC/HD',
          ),
        ],
        seed: 1,
      );

      expect(controller.availableCountries, contains('CN'));
      controller.setCountry('CN');
      expect(controller.filteredMediaIds, containsAll(['a', 'b', 'c']));
      expect(controller.availableProvinces, containsAll(['SH', 'BJ']));

      controller.setProvince('SH');
      expect(controller.filteredMediaIds, containsAll(['a', 'b']));
      expect(controller.availableCities, contains('SHC'));

      controller.setCity('SHC');
      expect(controller.filteredMediaIds, containsAll(['a', 'b']));
      expect(controller.availableDistricts, containsAll(['XH', 'PD']));

      controller.setDistrict('XH');
      expect(controller.filteredMediaIds, ['a']);
    },
  );

  test('location hierarchy options are constrained by current time filter', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'recent-us',
          type: MediaType.photo,
          createdAt: DateTime.now(),
          locationKey: 'US/CA/SF/SOMA',
        ),
        MediaItem(
          id: 'old-cn',
          type: MediaType.photo,
          createdAt: DateTime.now().subtract(const Duration(days: 400)),
          locationKey: 'CN/SH/SHC/XH',
        ),
      ],
      seed: 1,
    );

    controller.setTimeFilter(TimeFilterPreset.today);
    expect(controller.availableCountries, ['US']);
    expect(controller.filteredMediaIds, ['recent-us']);
  });

  test(
    'remove media items permanently excludes deleted ids from pool and trash',
    () {
      final controller = HomeController(
        initialMediaIds: const ['a', 'b'],
        seed: 1,
      );

      controller.updateTrash({'a'});
      controller.removeMediaItems({'a'});

      expect(controller.filteredMediaIds, isNot(contains('a')));
      expect(controller.trashIds, isNot(contains('a')));
      expect(controller.currentMediaId, 'b');
    },
  );

  test('delete keeps queued next media so remaining item is still shown', () {
    final now = DateTime.now();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'a', type: MediaType.photo, createdAt: now),
        MediaItem(id: 'b', type: MediaType.photo, createdAt: now),
      ],
      seed: 1,
    );

    expect(controller.currentMediaId, 'a');
    expect(controller.prepareUpcomingMediaForPreload()?.id, 'b');

    controller.onSwipeUpDelete();

    expect(controller.currentMediaId, 'b');
    expect(controller.trashIds, contains('a'));
  });

  test('resetAllFiltersAndRestart restores defaults and shows media again', () {
    final now = DateTime.now();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'a', type: MediaType.photo, createdAt: now),
        MediaItem(
          id: 'b',
          type: MediaType.video,
          createdAt: now.subtract(const Duration(days: 20)),
        ),
      ],
      seed: 1,
    );

    controller.toggleVideoOnlyMode();
    controller.setCountry('CN');
    controller.setCustomDateRange(
      now.subtract(const Duration(days: 1)),
      now.subtract(const Duration(days: 1)),
    );
    expect(controller.currentMediaId, isNull);

    controller.resetAllFiltersAndRestart();

    expect(controller.selectedTimeFilter, TimeFilterPreset.all);
    expect(controller.customStart, isNull);
    expect(controller.customEnd, isNull);
    expect(controller.selectedCountry, isNull);
    expect(controller.selectedProvince, isNull);
    expect(controller.selectedCity, isNull);
    expect(controller.selectedDistrict, isNull);
    expect(controller.videoOnlyEnabled, isFalse);
    expect(controller.hasOverlayDayFilter, isFalse);
    expect(controller.hasDeviceFilter, isFalse);
    expect(controller.currentMediaId, isNotNull);
  });

  test('geo location filter matches the same coordinate key', () {
    final now = DateTime.now();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'geo-a',
          type: MediaType.photo,
          createdAt: now,
          locationKey: 'geo/31.230/121.473',
        ),
        MediaItem(
          id: 'geo-b',
          type: MediaType.photo,
          createdAt: now,
          locationKey: 'geo/39.904/116.407',
        ),
        MediaItem(
          id: 'unknown',
          type: MediaType.photo,
          createdAt: now,
          locationKey: null,
        ),
      ],
      seed: 1,
    );

    controller.setLocationFilter('geo/31.230/121.473');

    expect(controller.filteredMediaIds, ['geo-a']);
  });

  test(
    'updateMediaLocationKeys applies location filter after background resolve',
    () {
      final now = DateTime.now();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'a',
            type: MediaType.photo,
            createdAt: now,
            locationKey: null,
          ),
          MediaItem(
            id: 'b',
            type: MediaType.photo,
            createdAt: now,
            locationKey: null,
          ),
        ],
        seed: 1,
      );

      controller.updateMediaLocationKeys({
        'a': 'CN/广东省/深圳市/莲花山公园内',
        'b': 'CN/广东省/深圳市/南山区',
      });
      controller.setLocationFilter('CN/广东省/深圳市/莲花山公园内');

      expect(controller.filteredMediaIds, ['a']);
    },
  );

  test(
    'exact location key filter distinguishes two photos in same district',
    () {
      final now = DateTime.now();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'home',
            type: MediaType.photo,
            createdAt: now,
            locationKey: 'CN/广东省/深圳市/福田区/@22.5401,114.0601',
          ),
          MediaItem(
            id: 'office',
            type: MediaType.photo,
            createdAt: now,
            locationKey: 'CN/广东省/深圳市/福田区/@22.5439,114.0582',
          ),
        ],
        seed: 1,
      );

      controller.setLocationFilter('CN/广东省/深圳市/福田区/@22.5401,114.0601');
      expect(controller.filteredMediaIds, ['home']);

      controller.setLocationFilter('CN/广东省/深圳市/福田区/@22.5439,114.0582');
      expect(controller.filteredMediaIds, ['office']);
    },
  );

  test('controller persists cumulative permanent deletion stats', () async {
    final store = InMemoryStateStore();
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(id: 'p1', type: MediaType.photo, sizeBytes: 1024),
        MediaItem(id: 'v1', type: MediaType.video, sizeBytes: 2048),
      ],
      stateStore: store,
      seed: 1,
    );

    controller.recordPermanentDeletionStats({'p1', 'v1'});

    final restored = await store.loadDeletionStats();
    expect(restored.photoCount, 1);
    expect(restored.videoCount, 1);
    expect(restored.knownSizeBytes, 3072);
  });

  test('controller restores cumulative permanent deletion stats', () async {
    final store = InMemoryStateStore();
    await store.saveDeletionStats(
      const DeletionStats(photoCount: 4, videoCount: 1, knownSizeBytes: 8192),
    );
    final controller = HomeController(stateStore: store, seed: 1);

    await controller.restoreDeletionStats();

    expect(controller.deletionStats.photoCount, 4);
    expect(controller.deletionStats.videoCount, 1);
    expect(controller.deletionStats.knownSizeBytes, 8192);
  });

  test(
    'controller persists monthly browse progress without resuming by default',
    () async {
      final store = InMemoryStateStore();
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'late',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 20),
          ),
          MediaItem(
            id: 'middle',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 10),
          ),
          MediaItem(
            id: 'early',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
        stateStore: store,
        seed: 1,
      );
      final month = controller.monthlyAlbumSummaryEntries.first;

      controller.applyCollectionQuery(month.query);
      expect(controller.currentMediaId, 'late');

      controller.jumpToMedia('middle');
      await Future<void>.delayed(Duration.zero);

      final restarted = HomeController(
        initialMediaItems: controller.mediaItemsByIds({
          'late',
          'middle',
          'early',
        }),
        stateStore: store,
        seed: 1,
      );
      restarted.applyCollectionQuery(month.query);

      expect(restarted.currentMediaId, 'late');

      final resume = await restarted.loadActiveBrowseProgress();
      expect(resume?.mediaId, 'middle');
      expect(resume?.displayIndex, 2);
      expect(resume?.totalCount, 3);
    },
  );

  test('jumping inside monthly sequential collection uses adjacent media', () {
    final controller = HomeController(
      initialMediaItems: [
        MediaItem(
          id: 'late',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 20),
        ),
        MediaItem(
          id: 'middle',
          type: MediaType.photo,
          createdAt: DateTime(2026, 4, 10),
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
    expect(controller.currentMediaId, 'late');

    controller.jumpToMedia('middle');
    expect(controller.currentMediaId, 'middle');

    controller.onSwipeRightPrevious();
    expect(controller.currentMediaId, 'late');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'middle');

    controller.onSwipeLeftRandom();
    expect(controller.currentMediaId, 'early');
  });

  test(
    'switching from random to sequential after jump uses adjacent media',
    () {
      final controller = HomeController(
        initialMediaItems: [
          MediaItem(
            id: 'late',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 20),
          ),
          MediaItem(
            id: 'middle',
            type: MediaType.photo,
            createdAt: DateTime(2026, 4, 10),
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
      controller.toggleBrowseMode();
      expect(controller.browseMode, BrowseMode.random);

      controller.jumpToMedia('middle');
      controller.toggleBrowseMode();
      expect(controller.browseMode, BrowseMode.sequential);

      controller.onSwipeRightPrevious();
      expect(controller.currentMediaId, 'late');
    },
  );
}
