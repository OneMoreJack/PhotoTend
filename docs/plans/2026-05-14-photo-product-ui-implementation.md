# Photo Product UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the RePhoto home, browser, and trash interactions feel like a photo timeline product rather than a file cleanup utility.

**Architecture:** Keep data ownership in `HomeController`, add only lightweight summary presentation fields, and keep UI changes scoped to existing feature pages. Avoid adding new services or recommendation engines.

**Tech Stack:** Flutter, Material widgets, existing `HomeController`, widget tests with `flutter_test`.

---

### Task 1: Album Summary Presentation Metadata

**Files:**
- Modify: `lib/domain/models/album_summary_entry.dart`
- Modify: `lib/features/home/home_controller.dart`
- Test: `test/features/home/home_controller_test.dart`

**Steps:**
1. Add `coverMediaId` and `previewMediaIds` to `AlbumSummaryEntry`, defaulting to null/empty.
2. Update `_buildSummaryEntry` to select representative non-trash media for each bucket.
3. Prefer photo items with `pathOrUri`; then any photo; then video.
4. Add tests proving trash items are excluded from cover/preview and photo cover is preferred.

### Task 2: Home Timeline Visual Upgrade

**Files:**
- Modify: `lib/features/albums/album_summary_page.dart`
- Test: `test/features/home/home_page_test.dart`

**Steps:**
1. Replace compact recent list tiles with a top `近三天` hero card.
2. Add a Memory section using deterministic summary entries such as `近一周` and the latest populated month.
3. Replace month `ListTile` presentation with cover-led cards and soft metadata text.
4. Preserve tap behavior into `MediaBrowserPage`.
5. Add tests for hero, memory section, month cover area, and navigation.

### Task 3: Browser Action Bar More Menu

**Files:**
- Modify: `lib/features/media/media_browser_page.dart`
- Test: `test/features/home/home_page_test.dart` or create focused media browser tests if needed.

**Steps:**
1. Keep visible bottom actions for browse mode and video-only.
2. Replace the open/share button with a `browser-more-btn`.
3. Show secondary actions in a modal/bottom sheet: open in gallery, import folder when available, settings.
4. Keep existing keys for browse/video tests.
5. Update tests so `Import Folder` is no longer visible by default but appears from the more menu.

### Task 4: Thumbnail Strip Polish

**Files:**
- Modify: `lib/features/media/widgets/media_thumbnail_strip.dart`
- Test: `test/features/media/media_thumbnail_strip_test.dart`

**Steps:**
1. Wrap thumbnails in `AnimatedScale`.
2. Strengthen selected state with accent border, inner white stroke, and stable dimensions.
3. Preserve existing lazy rendering and selected item scroll behavior.
4. Add a focused selected-state widget test without relying on exact animation frames.

### Task 5: Trash Grid And Bottom Bar

**Files:**
- Modify: `lib/features/trash/trash_page.dart`
- Test: `test/features/trash/trash_page_test.dart`

**Steps:**
1. Make grid column count responsive with `LayoutBuilder`.
2. Add selected overlay and animated border to grid tiles.
3. Replace isolated circular bottom actions with a unified bottom bar: Restore, Delete, Empty.
4. Show selected count in the bottom bar and keep danger styling for permanent delete.
5. Preserve confirmation and deleting progress behavior.

### Task 6: Verification And Review

**Files:**
- Inspect all modified files.

**Steps:**
1. Run `dart format` on modified Dart files.
2. Run `flutter analyze`.
3. Run focused tests listed in the design doc.
4. Run independent review against this plan and the original user proposal.

