# RePhoto

Cross-platform Flutter app (Android, iOS, macOS) for photo/video triage with gesture-first workflows and trash-first deletion.

## Current Scope

- Gesture session baseline (`HomePage`): swipe-up increments trash flow.
- Trash management baseline (`TrashPage`): restore selected items.
- Domain services:
  - Non-repeating random pool with auto-reset
  - Time + location filtering
  - Delete/undo session stack
  - Permanent delete result model (failed ids retained)
- Data adapters (scaffold level):
  - Mobile media repository contracts
  - macOS folder import scanner contract
  - In-memory local state store

## Development

```bash
flutter pub get
flutter analyze
flutter test -r expanded
```

## Test Matrix

- `/docs/testing/2026-02-24-rephoto-v1-test-matrix.md`
