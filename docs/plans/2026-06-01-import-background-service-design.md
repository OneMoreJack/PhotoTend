# Import Background Service Design

## Goal

Fix the import-page album dialog crash, shorten the system-library hint, allow imports before storage-card scanning finishes, and keep Android imports running while the app is backgrounded or the Flutter page is reclaimed.

## Architecture

The Flutter import flow keeps progressive scanning and the existing controller UI state. Android gains a foreground service that accepts a complete selected-media batch, copies items serially into `MediaStore`, persists progress in shared preferences, and publishes notification progress. The Flutter controller submits one batch and polls persisted native status while it remains alive. If the native batch API is unavailable, the controller falls back to the existing per-item import path.

## UI Behavior

- Canceling the new-album dialog keeps the current destination and does not dispose the text controller until the dialog widget has finished tearing down.
- The system-library subtitle is `导入到系统媒体库`.
- Progressive scan results remain selectable and importable while later pages are still being counted.
- The bottom summary continues to show scanning state while counts are incomplete.

## Android Background Behavior

- `ExternalImportService` runs as a foreground service with an ongoing progress notification.
- The service stores total, completed, imported ids, failed ids, and running state in `rephoto_external_import`.
- `MainActivity` exposes `startBackgroundImport` and `getBackgroundImportStatus` through `rephoto/external_import`.
- The service is Android-only. Unsupported hosts use the prior per-item import calls.

## Verification

- Flutter repository tests cover native batch payload mapping and status parsing.
- Controller tests cover native batch completion and fallback behavior.
- Widget tests cover canceling new album creation and importing a selected item during an unfinished scan.
- Run focused Flutter tests, `flutter analyze`, full Flutter tests, and Android Kotlin compilation.
