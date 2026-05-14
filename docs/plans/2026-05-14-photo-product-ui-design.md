# RePhoto Photo Product UI Design

## Goal

Shift RePhoto from a file-management feeling toward a photo timeline and memory product, while preserving the existing HomeController, media browser, and trash behaviors.

## Current Constraints

- The worktree already has uncommitted changes in album summary, media browser, thumbnail strip, and tests. Future work must preserve those changes.
- `AlbumSummaryPage` is the actual home timeline surface.
- `MediaBrowserPage` is large, so changes should be local and avoid broad rewrites.
- Tests often use `MediaItem` values without `pathOrUri`, so cover/photo UI needs a polished placeholder path.

## Chosen Approach

Implement a pragmatic visual upgrade without introducing new state management, new repositories, or recommendation algorithms.

1. Add lightweight presentation metadata to album summaries: representative cover media and recent media ids.
2. Turn the recent area into a visual hero and month rows into cover-led memory cards.
3. Add a deterministic Memory section from existing summaries instead of AI recommendation logic.
4. Reduce browser toolbar noise by keeping high-frequency toggles visible and moving secondary actions behind a more menu.
5. Polish thumbnail and trash interactions with animation, glass surfaces, responsive grids, and consistent visual tokens.

## Files

- `lib/domain/models/album_summary_entry.dart`
- `lib/features/home/home_controller.dart`
- `lib/features/albums/album_summary_page.dart`
- `lib/features/media/media_browser_page.dart`
- `lib/features/media/widgets/media_thumbnail_strip.dart`
- `lib/features/trash/trash_page.dart`
- `test/features/home/home_controller_test.dart`
- `test/features/home/home_page_test.dart`
- `test/features/media/media_thumbnail_strip_test.dart`
- `test/features/trash/trash_page_test.dart`

## Success Criteria

- Home starts with a photo-like recent hero instead of only flat list tiles.
- Month summaries expose cover/preview areas and softer hierarchy.
- Home includes a Memory section derived from existing media data.
- Browser bottom actions are visually quieter and expose a `...` more menu for secondary actions.
- Thumbnail strip keeps selected media visible and makes the selected state more obvious.
- Trash uses a centered responsive grid and a unified bottom bar.
- Existing behavior tests still pass, with added tests for the new user-visible behaviors.

## Verification

Run:

```bash
flutter analyze
flutter test test/features/home/home_controller_test.dart test/features/home/home_page_test.dart test/features/media/media_thumbnail_strip_test.dart test/features/trash/trash_page_test.dart
```

