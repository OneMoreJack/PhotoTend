# Storage Card Direct Scan Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make detected Android storage cards load immediately and ensure every refresh includes newly added media.

**Architecture:** Treat a detected removable volume as a native `volume://` import root that needs no document-tree picker. Keep manual SAF authorization unchanged, and make paginated volume scans use the same freshly merged MediaStore and filesystem snapshot as full scans.

**Tech Stack:** Flutter/Dart, Android Kotlin, MethodChannel, Android StorageManager, MediaStore, Flutter tests, Android JVM tests

---

### Task 1: Directly select a detected removable volume

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt`
- Test: `android/app/src/test/kotlin/com/example/rephoto/ExternalImportRootTest.kt`

**Step 1: Write the failing test**

Add a focused helper-level test showing that a non-empty mounted volume id resolves to
`volume://<id>`, while a missing volume returns null. Keep Android framework calls behind a
small injectable/pure decision helper so the JVM test exercises real selection behavior.

**Step 2: Run test to verify it fails**

Run:
`cd android && ./gradlew :app:testDebugUnitTest --tests com.example.rephoto.ExternalImportRootTest`

Expected: FAIL because direct detected-volume selection is not implemented.

**Step 3: Write minimal implementation**

Update `requestImportRoot` so a supplied `rootId` is validated against mounted removable
volumes, stored as `volume://<resolved-id>`, and returned immediately. Only a null/empty
`rootId` should create and launch `ACTION_OPEN_DOCUMENT_TREE`.

Update `readSavedImportRoot` to retain a mounted `volume://` root and clear it only after the
volume is no longer mounted.

**Step 4: Run test to verify it passes**

Run the focused Gradle test again.

Expected: PASS.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt \
  android/app/src/test/kotlin/com/example/rephoto/ExternalImportRootTest.kt
git commit -m "fix: select detected storage cards directly"
```

### Task 2: Refresh volume-backed paginated scans

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt`
- Test: `android/app/src/test/kotlin/com/example/rephoto/ExternalImportPagingTest.kt`

**Step 1: Write the failing test**

Extract a pure page-building helper accepting a current item snapshot, offset, and limit.
Test that:

- a second snapshot containing a newer item returns it on the first page;
- items are sorted newest-first before slicing;
- adjacent pages contain no duplicate ids;
- `hasMore` reflects the sorted merged snapshot.

**Step 2: Run test to verify it fails**

Run:
`cd android && ./gradlew :app:testDebugUnitTest --tests com.example.rephoto.ExternalImportPagingTest`

Expected: FAIL because paging is currently embedded in document-tree-only scanning.

**Step 3: Write minimal implementation**

For a saved `volume://` root, call `scanMediaStoreImportVolume` on every page request, then
pass that fresh merged list to the tested page helper. Preserve existing document-tree
limited scanning for manual `content://` roots.

**Step 4: Run test to verify it passes**

Run both focused Android tests.

Expected: PASS.

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt \
  android/app/src/test/kotlin/com/example/rephoto/ExternalImportPagingTest.kt
git commit -m "fix: refresh storage card paging snapshot"
```

### Task 3: Protect the Flutter channel and refresh flow

**Files:**
- Modify: `test/data/mobile/mobile_media_repository_test.dart`
- Modify: `test/features/import/import_controller_test.dart`
- Modify if required: `lib/data/mobile/external_import_repository.dart`
- Modify if required: `lib/features/import/import_controller.dart`

**Step 1: Write the failing tests**

Add or tighten tests proving that a detected root id is passed to `requestImportRoot`, while
manual selection omits it. Add a controller test where refresh replaces an old page snapshot
with a new snapshot containing a later photo.

**Step 2: Run tests to verify the expected state**

Run:
`flutter test test/data/mobile/mobile_media_repository_test.dart test/features/import/import_controller_test.dart -r expanded`

Expected: new regression test fails if current behavior does not replace stale results; existing
channel test may already pass and should document the unchanged contract.

**Step 3: Write minimal implementation**

Only change Dart production code if the failing tests reveal a Dart-side defect. Do not alter
channel names or payload shapes.

**Step 4: Run tests to verify they pass**

Run the two focused Flutter test files again.

Expected: PASS.

**Step 5: Commit**

```bash
git add test/data/mobile/mobile_media_repository_test.dart \
  test/features/import/import_controller_test.dart \
  lib/data/mobile/external_import_repository.dart \
  lib/features/import/import_controller.dart
git commit -m "test: cover refreshed storage card imports"
```

### Task 4: Verify the complete fix

**Files:**
- Modify: changed Dart files only if formatting changes are needed
- Reference: `docs/testing/2026-02-24-rephoto-v1-test-matrix.md`

**Step 1: Format changed Dart files**

Run `dart format <changed Dart files>`.

**Step 2: Run Android verification**

Run:

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:compileDebugKotlin
```

Expected: BUILD SUCCESSFUL.

**Step 3: Run Flutter verification**

Run:

```bash
flutter test -r expanded
flutter analyze
```

Expected: all tests pass and analysis reports no issues.

**Step 4: Inspect the final diff**

Run:
`git diff --check && git status --short && git diff --stat`

Expected: no whitespace errors, no build artifacts, and only scoped import-related changes.

**Step 5: Commit**

```bash
git add <remaining scoped files>
git commit -m "fix: refresh detected storage card imports"
```
