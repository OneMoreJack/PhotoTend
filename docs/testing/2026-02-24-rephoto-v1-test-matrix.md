# RePhoto V1 Test Matrix

## Mobile
- Permission granted: media list can be loaded.
- Permission denied/limited: app shows guarded state and does not crash.
- Swipe up moves current media into trash.
- Swipe down restores last deleted media.
- Trash permanent delete keeps failed ids for retry.

## macOS
- Folder import scan includes supported image/video extensions.
- Trash restore removes selected items from trash list.
- Permanent delete removes successful ids and keeps failed ids.

## Filters
- Time range and location can be applied together.
- Location filtering is constrained by selected time range.
- Random pool draws without repetition until exhaustion, then auto-resets.

## Video
- Video tile renders play affordance in home and trash flows.

## Regression Commands
- `flutter analyze`
- `flutter test -r expanded`
