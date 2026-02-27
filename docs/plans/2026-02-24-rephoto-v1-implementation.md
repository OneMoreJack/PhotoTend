# RePhoto V1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Flutter app for Android, iOS, and macOS that organizes photos/videos with gesture-based triage, trash-first deletion, time/location filters, and folder import on macOS.

**Architecture:** Keep all product behavior in a platform-agnostic domain layer (filters, random pool, history, trash). Use platform data adapters for mobile system media access and macOS folder scanning/deletion. Persist app state locally for deterministic behavior across restarts.

**Tech Stack:** Flutter, Dart, Riverpod, Drift (or Isar), video_player, mobile media access plugin, macOS filesystem + metadata parsing.

---

## Skill References
- `@superpowers:test-driven-development`
- `@superpowers:verification-before-completion`
- `@superpowers:requesting-code-review`

### Task 1: Bootstrap cross-platform Flutter project

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `test/smoke/app_smoke_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/main.dart';

void main() {
  testWidgets('app bootstraps with RePhoto title', (tester) async {
    await tester.pumpWidget(const RePhotoApp());
    expect(find.text('RePhoto'), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/smoke/app_smoke_test.dart -r expanded`  
Expected: FAIL with missing `RePhotoApp` or title assertion failure.

**Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const RePhotoApp());
}

class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: Center(child: Text('RePhoto'))));
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/smoke/app_smoke_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add pubspec.yaml lib/main.dart test/smoke/app_smoke_test.dart
git commit -m "chore: bootstrap rephoto flutter app"
```

### Task 2: Define domain models and repository contracts

**Files:**
- Create: `lib/domain/models/media_item.dart`
- Create: `lib/domain/models/filter_state.dart`
- Create: `lib/domain/models/trash_entry.dart`
- Create: `lib/domain/repositories/media_repository.dart`
- Test: `test/domain/models/domain_models_test.dart`

**Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('media item supports photo and video types', () {
    const photo = MediaItem(id: '1', type: MediaType.photo);
    const video = MediaItem(id: '2', type: MediaType.video);
    expect(photo.type, MediaType.photo);
    expect(video.type, MediaType.video);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/models/domain_models_test.dart -r expanded`  
Expected: FAIL with unresolved model classes.

**Step 3: Write minimal implementation**

```dart
enum MediaType { photo, video }

class MediaItem {
  const MediaItem({required this.id, required this.type, this.createdAt, this.locationKey});
  final String id;
  final MediaType type;
  final DateTime? createdAt;
  final String? locationKey;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/models/domain_models_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/models lib/domain/repositories test/domain/models/domain_models_test.dart
git commit -m "feat: add domain models and repository contracts"
```

### Task 3: Implement random pool (non-repeating within filter set)

**Files:**
- Create: `lib/domain/services/random_pool_service.dart`
- Test: `test/domain/services/random_pool_service_test.dart`

**Step 1: Write the failing test**

```dart
test('returns all ids once before reset', () {
  final service = RandomPoolService(seed: 7);
  service.reset(['a', 'b', 'c']);
  final seen = {service.next()!, service.next()!, service.next()!};
  expect(seen.length, 3);
  expect(service.next(), isNotNull); // auto reset after exhaustion
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/random_pool_service_test.dart -r expanded`  
Expected: FAIL with missing service or behavior mismatch.

**Step 3: Write minimal implementation**

```dart
class RandomPoolService {
  RandomPoolService({int? seed});
  final List<String> _all = [];
  final Set<String> _seen = {};

  void reset(List<String> ids) {
    _all
      ..clear()
      ..addAll(ids);
    _seen.clear();
  }

  String? next() {
    final unseen = _all.where((id) => !_seen.contains(id)).toList();
    if (unseen.isEmpty && _all.isNotEmpty) {
      _seen.clear();
      return next();
    }
    if (unseen.isEmpty) return null;
    final pick = unseen.first;
    _seen.add(pick);
    return pick;
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/random_pool_service_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/services/random_pool_service.dart test/domain/services/random_pool_service_test.dart
git commit -m "feat: implement non-repeating random pool with auto reset"
```

### Task 4: Implement gesture history + delete/undo state machine

**Files:**
- Create: `lib/domain/services/gesture_session_service.dart`
- Test: `test/domain/services/gesture_session_service_test.dart`

**Step 1: Write the failing test**

```dart
test('up deletes to trash and down undoes last delete', () {
  final s = GestureSessionService();
  s.onShown('a');
  s.onDeleteCurrent('a');
  expect(s.trashIds, contains('a'));
  s.undoLastDelete();
  expect(s.trashIds, isNot(contains('a')));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/gesture_session_service_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class GestureSessionService {
  final List<String> _displayHistory = [];
  final List<String> _deleteStack = [];
  final Set<String> trashIds = {};

  void onShown(String id) => _displayHistory.add(id);
  void onDeleteCurrent(String id) {
    trashIds.add(id);
    _deleteStack.add(id);
  }

  void undoLastDelete() {
    if (_deleteStack.isEmpty) return;
    trashIds.remove(_deleteStack.removeLast());
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/gesture_session_service_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/services/gesture_session_service.dart test/domain/services/gesture_session_service_test.dart
git commit -m "feat: add gesture session delete and undo state machine"
```

### Task 5: Implement filter engine (time + location, quick actions)

**Files:**
- Create: `lib/domain/services/filter_service.dart`
- Test: `test/domain/services/filter_service_test.dart`

**Step 1: Write the failing test**

```dart
test('location filter is scoped by current time range', () {
  final items = [
    MediaItem(id: '1', type: MediaType.photo, createdAt: DateTime(2026, 2, 1), locationKey: 'CN/SH/XH'),
    MediaItem(id: '2', type: MediaType.photo, createdAt: DateTime(2025, 2, 1), locationKey: 'CN/SH/XH'),
  ];
  final r = FilterService.apply(
    items,
    timeStart: DateTime(2026, 1, 1),
    timeEnd: DateTime(2026, 12, 31),
    locationKey: 'CN/SH/XH',
  );
  expect(r.map((e) => e.id).toList(), ['1']);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/filter_service_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class FilterService {
  static List<MediaItem> apply(
    List<MediaItem> items, {
    DateTime? timeStart,
    DateTime? timeEnd,
    String? locationKey,
  }) {
    return items.where((item) {
      final t = item.createdAt;
      if (timeStart != null && (t == null || t.isBefore(timeStart))) return false;
      if (timeEnd != null && (t == null || t.isAfter(timeEnd))) return false;
      if (locationKey != null && item.locationKey != locationKey) return false;
      return true;
    }).toList();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/filter_service_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/services/filter_service.dart test/domain/services/filter_service_test.dart
git commit -m "feat: implement time and location filter engine"
```

### Task 6: Add local persistence for trash/filter/session state

**Files:**
- Create: `lib/data/local/app_database.dart`
- Create: `lib/data/local/state_store.dart`
- Test: `test/data/local/state_store_test.dart`

**Step 1: Write the failing test**

```dart
test('persists trash count and selected filter after restart', () async {
  final store = InMemoryStateStore();
  await store.saveTrashIds({'1', '2'});
  await store.saveLocationFilter('CN/SH/XH');
  expect(await store.loadTrashIds(), {'1', '2'});
  expect(await store.loadLocationFilter(), 'CN/SH/XH');
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/data/local/state_store_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class InMemoryStateStore {
  Set<String> _trash = {};
  String? _location;

  Future<void> saveTrashIds(Set<String> ids) async => _trash = ids;
  Future<Set<String>> loadTrashIds() async => _trash;
  Future<void> saveLocationFilter(String? key) async => _location = key;
  Future<String?> loadLocationFilter() async => _location;
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/data/local/state_store_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/data/local test/data/local/state_store_test.dart
git commit -m "feat: persist trash and filter session state"
```

### Task 7: Implement mobile media adapter (read + permanent delete)

**Files:**
- Create: `lib/data/mobile/mobile_media_repository.dart`
- Create: `lib/data/mobile/mobile_permissions_service.dart`
- Test: `test/data/mobile/mobile_media_repository_test.dart`

**Step 1: Write the failing test**

```dart
test('permanent delete removes trashed ids from source list', () async {
  final repo = FakeMobileMediaRepository(['1', '2', '3']);
  await repo.permanentDelete({'2'});
  expect(await repo.fetchAllIds(), ['1', '3']);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/data/mobile/mobile_media_repository_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class FakeMobileMediaRepository {
  FakeMobileMediaRepository(List<String> ids) : _ids = ids;
  List<String> _ids;

  Future<List<String>> fetchAllIds() async => _ids;

  Future<void> permanentDelete(Set<String> ids) async {
    _ids = _ids.where((id) => !ids.contains(id)).toList();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/data/mobile/mobile_media_repository_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/data/mobile test/data/mobile/mobile_media_repository_test.dart
git commit -m "feat: add mobile media adapter contract for final deletion"
```

### Task 8: Implement macOS folder import scanner (photo + video)

**Files:**
- Create: `lib/data/macos/folder_import_repository.dart`
- Test: `test/data/macos/folder_import_repository_test.dart`

**Step 1: Write the failing test**

```dart
test('scanner returns media entries from imported folder', () async {
  final repo = FakeFolderImportRepository(['a.jpg', 'b.mp4', 'readme.txt']);
  final result = await repo.scan();
  expect(result, ['a.jpg', 'b.mp4']);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/data/macos/folder_import_repository_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class FakeFolderImportRepository {
  FakeFolderImportRepository(this._files);
  final List<String> _files;

  Future<List<String>> scan() async {
    const exts = ['.jpg', '.jpeg', '.png', '.heic', '.mp4', '.mov'];
    return _files.where((f) => exts.any((e) => f.toLowerCase().endsWith(e))).toList();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/data/macos/folder_import_repository_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/data/macos test/data/macos/folder_import_repository_test.dart
git commit -m "feat: add macos folder scan for photo and video"
```

### Task 9: Build Home screen with gesture mapping and quick filters

**Files:**
- Create: `lib/features/home/home_page.dart`
- Create: `lib/features/home/home_controller.dart`
- Test: `test/features/home/home_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('swipe up sends current media to trash', (tester) async {
  await tester.pumpWidget(const HomePage());
  await tester.drag(find.byType(HomePage), const Offset(0, -400));
  await tester.pumpAndSettle();
  expect(find.textContaining('Trash: 1'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/home_page_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class HomeController extends ChangeNotifier {
  int trashCount = 0;
  void onSwipeUpDelete() {
    trashCount += 1;
    notifyListeners();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/home_page_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/home test/features/home/home_page_test.dart
git commit -m "feat: implement home gestures and quick filter actions"
```

### Task 10: Build Trash screen (restore selected + delete all permanently)

**Files:**
- Create: `lib/features/trash/trash_page.dart`
- Create: `lib/features/trash/trash_controller.dart`
- Test: `test/features/trash/trash_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('restore selected removes item from trash list', (tester) async {
  await tester.pumpWidget(const TrashPage(initialIds: ['1', '2']));
  await tester.tap(find.text('1'));
  await tester.tap(find.text('Restore Selected'));
  await tester.pumpAndSettle();
  expect(find.text('1'), findsNothing);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/trash/trash_page_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class TrashController extends ChangeNotifier {
  TrashController(List<String> ids) : ids = [...ids];
  final List<String> ids;
  final Set<String> selected = {};

  void restoreSelected() {
    ids.removeWhere(selected.contains);
    selected.clear();
    notifyListeners();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/trash/trash_page_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/trash test/features/trash/trash_page_test.dart
git commit -m "feat: add trash page restore and bulk delete actions"
```

### Task 11: Add video playback surface in home and trash details

**Files:**
- Create: `lib/features/media/widgets/video_tile.dart`
- Modify: `lib/features/home/home_page.dart`
- Modify: `lib/features/trash/trash_page.dart`
- Test: `test/features/media/video_tile_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('video item renders play control', (tester) async {
  await tester.pumpWidget(const VideoTile(uri: 'file:///tmp/a.mp4'));
  expect(find.byIcon(Icons.play_arrow), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/video_tile_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.uri});
  final String uri;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Icon(Icons.play_arrow));
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/video_tile_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/media lib/features/home/home_page.dart lib/features/trash/trash_page.dart test/features/media/video_tile_test.dart
git commit -m "feat: add video playback entry points"
```

### Task 12: Wire permanent deletion workflow and failure handling

**Files:**
- Create: `lib/domain/services/permanent_delete_service.dart`
- Modify: `lib/features/trash/trash_controller.dart`
- Test: `test/domain/services/permanent_delete_service_test.dart`

**Step 1: Write the failing test**

```dart
test('failed delete ids stay in trash for retry', () async {
  final s = PermanentDeleteService(fakeDeleteResult: {'1': true, '2': false});
  final result = await s.delete({'1', '2'});
  expect(result.failedIds, {'2'});
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/permanent_delete_service_test.dart -r expanded`  
Expected: FAIL.

**Step 3: Write minimal implementation**

```dart
class DeleteResult {
  DeleteResult(this.failedIds);
  final Set<String> failedIds;
}

class PermanentDeleteService {
  PermanentDeleteService({required this.fakeDeleteResult});
  final Map<String, bool> fakeDeleteResult;

  Future<DeleteResult> delete(Set<String> ids) async {
    final failed = ids.where((id) => fakeDeleteResult[id] != true).toSet();
    return DeleteResult(failed);
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/permanent_delete_service_test.dart -r expanded`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/services/permanent_delete_service.dart lib/features/trash/trash_controller.dart test/domain/services/permanent_delete_service_test.dart
git commit -m "feat: keep failed permanent deletes in trash for retry"
```

### Task 13: Verify, document, and prepare handoff

**Files:**
- Create: `docs/testing/2026-02-24-rephoto-v1-test-matrix.md`
- Modify: `README.md`

**Step 1: Write the failing test (validation checklist as executable commands)**

```bash
flutter analyze
flutter test
```

**Step 2: Run validation to capture failures**

Run: `flutter analyze && flutter test`  
Expected: PASS. If FAIL, create follow-up tasks before proceeding.

**Step 3: Write minimal documentation implementation**

```markdown
# RePhoto V1 Test Matrix
- Mobile: permission allow/deny, soft delete, undo, permanent delete
- macOS: import folder scan, restore, delete all
- Filters: time presets, custom range, location scope under time
- Video: playback in home and trash pages
```

**Step 4: Run validation again**

Run: `flutter analyze && flutter test`  
Expected: PASS.

**Step 5: Commit**

```bash
git add docs/testing/2026-02-24-rephoto-v1-test-matrix.md README.md
git commit -m "docs: add rephoto v1 verification matrix and usage notes"
```

## Done Criteria
- All tasks completed in order
- `flutter analyze` is clean
- `flutter test` passes
- Manual sanity checks pass on Android, iOS, macOS
- No known P1/P2 bugs open

