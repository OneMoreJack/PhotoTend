# Import Background Service Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Android storage-card imports continue in a foreground service while fixing the related import-page regressions.

**Architecture:** Submit selected import items as one Android native batch and poll persisted service progress from Dart. Keep the existing per-item repository call as a fallback for unsupported hosts and test fakes.

**Tech Stack:** Flutter, Dart `MethodChannel`, Android Kotlin foreground service, Android `MediaStore`, Flutter widget/unit tests.

---

### Task 1: Add Flutter Regression Tests

**Files:**
- Modify: `test/features/import/import_page_test.dart`
- Modify: `test/features/import/import_controller_test.dart`
- Modify: `test/data/mobile/mobile_media_repository_test.dart`

**Steps:**
1. Add tests for canceling new album creation and importing while a later scan page is blocked.
2. Add repository tests for batch request payload and native progress parsing.
3. Add a controller test for completing a native background batch.
4. Run focused tests and confirm they fail for the missing behavior.

### Task 2: Add Dart Batch Import API

**Files:**
- Modify: `lib/data/mobile/external_import_repository.dart`
- Modify: `lib/features/import/import_controller.dart`

**Steps:**
1. Add typed native batch-status mapping.
2. Add repository methods to start a batch and read status.
3. Prefer native batch import in the controller, polling status while the page is alive.
4. Fall back to per-item imports when the method is unsupported.
5. Run focused tests and confirm they pass.

### Task 3: Fix Import Page Regressions

**Files:**
- Modify: `lib/features/import/import_page.dart`
- Modify: `lib/l10n/app_localizations.dart`

**Steps:**
1. Delay album-dialog text-controller disposal until teardown completes.
2. Shorten the system-library subtitle.
3. Keep the import action enabled while progressive scan statistics are loading.
4. Run widget tests and confirm they pass.

### Task 4: Add Android Foreground Import Service

**Files:**
- Create: `android/app/src/main/kotlin/com/example/rephoto/ExternalImportService.kt`
- Modify: `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Steps:**
1. Extract Android import copy logic into a context-based helper shared by the activity and service.
2. Add a foreground service that copies one batch serially and stores progress.
3. Add channel handlers to start a batch and return current status.
4. Register required service permissions and manifest entry.
5. Compile Kotlin and resolve any native errors.

### Task 5: Verify

**Steps:**
1. Format changed Dart files.
2. Run focused Flutter tests.
3. Run `flutter analyze`.
4. Run `flutter test -r expanded`.
5. Run `./gradlew :app:compileDebugKotlin` from `android/`.
