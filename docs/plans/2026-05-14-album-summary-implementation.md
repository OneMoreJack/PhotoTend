# Album Summary Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Open RePhoto on a time-based album summary, then navigate into a reusable media browser with a lazy thumbnail strip.

**Architecture:** Split the current home experience into `AlbumSummaryPage` and `MediaBrowserPage`. Keep a shared controller for the media collection, trash state, filtering, browsing, and summary derivation. Add lightweight query and summary models so later album types can reuse the browser route.

**Tech Stack:** Flutter, Dart, `ChangeNotifier`, existing MethodChannel media repositories, existing widget tests with `flutter_test`.

---

## Skill References

- `@superpowers:test-driven-development`
- `@superpowers:verification-before-completion`
- `@superpowers:requesting-code-review`

### Task 1: Add Collection Query and Summary Models

**Files:**
- Modify: `lib/domain/models/media_item.dart`
- Create: `lib/domain/models/media_collection_query.dart`
- Create: `lib/domain/models/album_summary_entry.dart`
- Test: `test/domain/models/album_summary_entry_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('album summary entry formats counts and known size state', () {
    final entry = AlbumSummaryEntry(
      id: 'month-2026-04',
      title: '2026年4月',
      query: MediaCollectionQuery(
        title: '2026年4月',
        timeStart: DateTime(2026, 4),
        timeEnd: DateTime(2026, 5).subtract(const Duration(milliseconds: 1)),
      ),
      photoCount: 2,
      videoCount: 1,
      knownSizeBytes: 1024,
      hasUnknownSize: true,
    );

    expect(entry.totalCount, 3);
    expect(entry.hasMedia, isTrue);
    expect(entry.hasUnknownSize, isTrue);
  });

  test('media item can carry optional byte size', () {
    const item = MediaItem(id: 'a', type: MediaType.photo, sizeBytes: 42);
    expect(item.sizeBytes, 42);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/models/album_summary_entry_test.dart -r expanded`

Expected: FAIL because the new models and `MediaItem.sizeBytes` do not exist.

**Step 3: Implement minimal models**

Add `sizeBytes` to `MediaItem` constructor and field.

Create `MediaCollectionQuery`:

```dart
class MediaCollectionQuery {
  const MediaCollectionQuery({
    required this.title,
    this.timeStart,
    this.timeEnd,
  });

  final String title;
  final DateTime? timeStart;
  final DateTime? timeEnd;
}
```

Create `AlbumSummaryEntry`:

```dart
import 'package:rephoto/domain/models/media_collection_query.dart';

class AlbumSummaryEntry {
  const AlbumSummaryEntry({
    required this.id,
    required this.title,
    required this.query,
    required this.photoCount,
    required this.videoCount,
    required this.knownSizeBytes,
    required this.hasUnknownSize,
  });

  final String id;
  final String title;
  final MediaCollectionQuery query;
  final int photoCount;
  final int videoCount;
  final int knownSizeBytes;
  final bool hasUnknownSize;

  int get totalCount => photoCount + videoCount;
  bool get hasMedia => totalCount > 0;
}
```

Update every `MediaItem(...)` copy site to preserve `sizeBytes`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/models/album_summary_entry_test.dart -r expanded`

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/models test/domain/models/album_summary_entry_test.dart
git commit -m "feat: add album summary query models"
```

### Task 2: Build Album Summary Data in Controller

**Files:**
- Modify: `lib/features/home/home_controller.dart`
- Test: `test/features/home/home_controller_test.dart`

**Step 1: Write failing controller tests**

Add tests:

```dart
test('album summaries exclude trashed media and include recent windows', () {
  final now = DateTime(2026, 5, 14, 12);
  final controller = HomeController(
    initialMediaItems: [
      MediaItem(id: 'a', type: MediaType.photo, createdAt: DateTime(2026, 5, 13), sizeBytes: 100),
      MediaItem(id: 'b', type: MediaType.video, createdAt: DateTime(2026, 5, 10), sizeBytes: 200),
      MediaItem(id: 'c', type: MediaType.photo, createdAt: DateTime(2026, 4, 2), sizeBytes: 300),
    ],
    nowProvider: () => now,
    seed: 1,
  );

  controller.updateTrash({'a'});

  final recent3 = controller.albumSummaryEntries.singleWhere((e) => e.id == 'recent-3-days');
  expect(recent3.totalCount, 0);

  final recent7 = controller.albumSummaryEntries.singleWhere((e) => e.id == 'recent-7-days');
  expect(recent7.photoCount, 0);
  expect(recent7.videoCount, 1);
  expect(recent7.knownSizeBytes, 200);
});

test('monthly summaries are newest first and count media by type', () {
  final controller = HomeController(
    initialMediaItems: [
      MediaItem(id: 'apr-photo', type: MediaType.photo, createdAt: DateTime(2026, 4, 1), sizeBytes: 100),
      MediaItem(id: 'apr-video', type: MediaType.video, createdAt: DateTime(2026, 4, 2), sizeBytes: 200),
      MediaItem(id: 'mar-photo', type: MediaType.photo, createdAt: DateTime(2026, 3, 2), sizeBytes: 50),
    ],
    nowProvider: () => DateTime(2026, 5, 14),
    seed: 1,
  );

  final months = controller.monthlyAlbumSummaryEntries;
  expect(months.map((e) => e.id), ['month-2026-04', 'month-2026-03']);
  expect(months.first.photoCount, 1);
  expect(months.first.videoCount, 1);
  expect(months.first.knownSizeBytes, 300);
});
```

**Step 2: Run tests to verify failure**

Run: `flutter test test/features/home/home_controller_test.dart -r expanded`

Expected: FAIL because summary APIs and `nowProvider` do not exist.

**Step 3: Implement summary APIs**

Add `DateTime Function() nowProvider` to `HomeController`, defaulting to `DateTime.now`.

Add:

- `List<AlbumSummaryEntry> get recentAlbumSummaryEntries`
- `List<AlbumSummaryEntry> get monthlyAlbumSummaryEntries`
- `List<AlbumSummaryEntry> get albumSummaryEntries`

Implementation details:

- Source from `_allMediaItems.where((item) => !trashIds.contains(item.id))`.
- Ignore items with `createdAt == null` for time buckets.
- Recent 3 days means from local midnight two days before today through end of today.
- Recent 7 days means from local midnight six days before today through end of today.
- Monthly buckets use `DateTime(year, month, 1)` through the last millisecond before next month.
- Hide empty monthly buckets. Keep recent buckets visible even if zero so the UI can show stable quick entries.
- Sum only non-null `sizeBytes`; set `hasUnknownSize` if any included item has null size.

**Step 4: Run tests to verify pass**

Run: `flutter test test/features/home/home_controller_test.dart -r expanded`

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/home/home_controller.dart test/features/home/home_controller_test.dart
git commit -m "feat: derive time album summaries"
```

### Task 3: Apply Browser Query and Support Thumbnail Jump

**Files:**
- Modify: `lib/features/home/home_controller.dart`
- Test: `test/features/home/home_controller_test.dart`

**Step 1: Write failing tests**

Add:

```dart
test('applying collection query starts from earliest matching media', () {
  final controller = HomeController(
    initialMediaItems: [
      MediaItem(id: 'late', type: MediaType.photo, createdAt: DateTime(2026, 4, 20)),
      MediaItem(id: 'early', type: MediaType.photo, createdAt: DateTime(2026, 4, 1)),
      MediaItem(id: 'other', type: MediaType.photo, createdAt: DateTime(2026, 5, 1)),
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

  expect(controller.filteredMediaIds, ['early', 'late']);
  expect(controller.currentMediaId, 'early');
});

test('jump to media updates current media inside active filtered set', () {
  final controller = HomeController(initialMediaIds: const ['a', 'b', 'c'], seed: 1);
  controller.jumpToMedia('c');
  expect(controller.currentMediaId, 'c');
  controller.onSwipeRightPrevious();
  expect(controller.currentMediaId, isNotNull);
});
```

**Step 2: Run tests to verify failure**

Run: `flutter test test/features/home/home_controller_test.dart -r expanded`

Expected: FAIL because `applyCollectionQuery` and `jumpToMedia` do not exist.

**Step 3: Implement query application**

Add:

- `MediaCollectionQuery? activeCollectionQuery`
- `void applyCollectionQuery(MediaCollectionQuery query)`
- `void clearCollectionQuery()`
- `void jumpToMedia(String id)`

Implementation details:

- Query time range should be an additional base time condition.
- Preserve existing overlay/device/location/video filters by applying them after the query time range.
- Sort filtered ids by `createdAt`, nulls last, then id.
- `applyCollectionQuery` resets history and starts from first filtered media.
- `jumpToMedia` only accepts ids in `_filteredMediaIds` and not in trash. It appends the id to visible history if needed, marks it consumed in random pool, and notifies listeners.

**Step 4: Run tests to verify pass**

Run: `flutter test test/features/home/home_controller_test.dart -r expanded`

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/home/home_controller.dart test/features/home/home_controller_test.dart
git commit -m "feat: apply album queries to browser"
```

### Task 4: Split Home into Album Summary and Media Browser Routes

**Files:**
- Modify: `lib/features/home/home_page.dart`
- Create: `lib/features/albums/album_summary_page.dart`
- Create: `lib/features/media/media_browser_page.dart`
- Test: `test/features/home/home_page_test.dart`
- Create or modify: `test/features/albums/album_summary_page_test.dart`

**Step 1: Write failing widget tests**

Add tests:

```dart
testWidgets('home starts on album summary', (tester) async {
  final controller = HomeController(
    initialMediaItems: [
      MediaItem(id: 'a', type: MediaType.photo, createdAt: DateTime(2026, 4, 1)),
    ],
    seed: 1,
  );

  await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));

  expect(find.text('近三天'), findsOneWidget);
  expect(find.text('2026年4月'), findsOneWidget);
  expect(find.byKey(const Key('current-media-preview')), findsNothing);
});

testWidgets('tapping month opens media browser at first item', (tester) async {
  final controller = HomeController(
    initialMediaItems: [
      MediaItem(id: 'late', type: MediaType.photo, createdAt: DateTime(2026, 4, 20)),
      MediaItem(id: 'early', type: MediaType.photo, createdAt: DateTime(2026, 4, 1)),
    ],
    seed: 1,
  );

  await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));
  await tester.tap(find.text('2026年4月'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('media-browser-page')), findsOneWidget);
  expect(controller.currentMediaId, 'early');
});
```

**Step 2: Run tests to verify failure**

Run: `flutter test test/features/home/home_page_test.dart -r expanded`

Expected: FAIL because home still renders the browser directly.

**Step 3: Extract browser page**

Move the current `HomePage` stateful browser implementation into `MediaBrowserPage`.

Create a new lightweight `HomePage` that:

- Owns or receives `HomeController`.
- Bootstraps mobile library loading as before, or delegates bootstrapping callbacks into `AlbumSummaryPage`.
- Renders `AlbumSummaryPage`.

Create `AlbumSummaryPage` that:

- Receives the controller.
- Displays status/empty state.
- Displays recent and monthly entries.
- Pushes `MediaBrowserPage(controller: controller, query: entry.query)` on tap.

Keep existing widget keys when possible.

**Step 4: Run tests to verify pass**

Run:

```bash
flutter test test/features/home/home_page_test.dart -r expanded
flutter test test/features/albums/album_summary_page_test.dart -r expanded
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/home lib/features/albums lib/features/media test/features/home test/features/albums
git commit -m "feat: split album summary and media browser routes"
```

### Task 5: Add Lazy Thumbnail Strip to Browser

**Files:**
- Modify: `lib/features/media/media_browser_page.dart`
- Create: `lib/features/media/widgets/media_thumbnail_strip.dart`
- Test: `test/features/media/media_thumbnail_strip_test.dart`
- Modify: `test/features/home/home_page_test.dart`

**Step 1: Write failing widget tests**

```dart
testWidgets('thumbnail strip lazily renders visible media and jumps on tap', (tester) async {
  final controller = HomeController(
    initialMediaItems: List.generate(
      30,
      (i) => MediaItem(
        id: 'm$i',
        type: MediaType.photo,
        createdAt: DateTime(2026, 4, i + 1),
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

  await tester.pumpWidget(MaterialApp(home: MediaBrowserPage(controller: controller)));

  expect(find.byKey(const Key('media-thumbnail-strip')), findsOneWidget);
  expect(find.byKey(const Key('media-thumbnail-m0')), findsOneWidget);
  expect(find.byKey(const Key('media-thumbnail-m29')), findsNothing);

  await tester.tap(find.byKey(const Key('media-thumbnail-m2')));
  await tester.pumpAndSettle();
  expect(controller.currentMediaId, 'm2');
});
```

**Step 2: Run tests to verify failure**

Run: `flutter test test/features/media/media_thumbnail_strip_test.dart -r expanded`

Expected: FAIL because thumbnail strip does not exist.

**Step 3: Implement thumbnail strip**

Create `MediaThumbnailStrip`:

- Inputs: `items`, `currentMediaId`, `thumbnailBuilder`, `onTap`.
- Uses `SizedBox(height: 78)` and horizontal `ListView.builder`.
- Key the strip as `media-thumbnail-strip`.
- Key each tile as `media-thumbnail-$id`.
- Use stable item width so lazy builder can avoid building offscreen children.
- Show selected state with a clear border.

In `MediaBrowserPage`:

- Build items from `controller.filteredMediaIds` and `controller.mediaItemsByIds(...)`.
- Reuse small preview loading helpers for phasset/file thumbnails.
- Place the strip above `_buildBottomActionBar()`.

**Step 4: Run tests to verify pass**

Run:

```bash
flutter test test/features/media/media_thumbnail_strip_test.dart -r expanded
flutter test test/features/home/home_page_test.dart -r expanded
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/media test/features/media test/features/home/home_page_test.dart
git commit -m "feat: add browser thumbnail strip"
```

### Task 6: Populate Size Metadata from Repositories

**Files:**
- Modify: `lib/data/macos/folder_import_repository.dart`
- Modify: `lib/data/mobile/mobile_media_repository.dart`
- Test: `test/data/macos/folder_import_repository_test.dart`
- Test: `test/data/mobile/mobile_media_repository_test.dart`

**Step 1: Write failing tests**

For macOS folder import, assert scanned files set `sizeBytes`.

For mobile repository, extend mocked platform payload with `sizeBytes` and assert it maps into `MediaItem.sizeBytes`.

**Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/data/macos/folder_import_repository_test.dart -r expanded
flutter test test/data/mobile/mobile_media_repository_test.dart -r expanded
```

Expected: FAIL because size metadata is ignored.

**Step 3: Implement size mapping**

- macOS: use `File(path).length()` while scanning.
- mobile: parse `sizeBytes` when the platform returns an integer-like value.
- Keep null on failure or missing metadata.

**Step 4: Run tests to verify pass**

Run:

```bash
flutter test test/data/macos/folder_import_repository_test.dart -r expanded
flutter test test/data/mobile/mobile_media_repository_test.dart -r expanded
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/data/macos lib/data/mobile test/data/macos test/data/mobile
git commit -m "feat: include media size metadata"
```

### Task 7: Final Verification

**Files:**
- No code files expected.

**Step 1: Format changed Dart files**

Run: `dart format lib test`

Expected: formatter completes successfully.

**Step 2: Run analyzer**

Run: `flutter analyze`

Expected: no new issues.

**Step 3: Run full test suite**

Run: `flutter test -r expanded`

Expected: all tests pass.

**Step 4: Review git diff**

Run: `git diff --stat`

Expected: only files related to album summary, browser split, thumbnails, size metadata, and tests changed.

**Step 5: Commit any final fixes**

```bash
git add lib test docs/plans
git commit -m "test: verify album summary browser flow"
```
