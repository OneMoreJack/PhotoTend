# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Summary

RePhoto is a cross-platform Flutter app for photo and video triage. The current product centers on a photo timeline, album summaries, gesture-first browsing, trash-first deletion, external storage import, and permanent delete flows.

Targets currently present in the repo:

- Android
- iOS
- macOS

## Repo Layout

- `lib/main.dart`: app entry point. `RePhotoApp` builds a `MaterialApp` with `HuashuTheme` and starts at `HomePage`.
- `lib/domain/`: platform-independent models, repositories, and services.
  - `models/`: media items, filters, trash entries, album summary entries, deletion stats, and collection queries.
  - `services/`: filter logic, gesture session state, random pool behavior, and permanent delete result handling.
  - `repositories/`: abstract media repository contracts.
- `lib/data/`: data adapters and platform-facing repository implementations.
  - `data/mobile/`: method-channel adapters for mobile media, permissions, and external import.
  - `data/macos/`: folder import scanner for macOS.
  - `data/local/`: local state store scaffolding.
- `lib/features/`: UI features and controllers.
  - `albums/`: album summary/timeline surface.
  - `home/`: app bootstrap controller ownership and mobile media loading.
  - `import/`: external storage import flow.
  - `media/`: media browser, thumbnails, and video tiles.
  - `settings/`: settings surface.
  - `trash/`: trash selection, restore, and permanent delete flow.
- `lib/theme/`: shared visual tokens and Material theme. `HuashuTheme` and `HuashuColors` are the primary design vocabulary.
- `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt`: Android method-channel implementation for media library access, permissions, preview data, external import, sharing/opening, and deletion.
- `ios/Runner/AppDelegate.swift`: iOS method-channel implementation for Photos permissions, media fetch, previews, sharing/opening, and deletion.
- `macos/`: Flutter macOS runner. The Dart macOS folder import path currently lives under `lib/data/macos/`.
- `test/`: Flutter tests, mostly mirroring `lib/` boundaries.
- `docs/plans/`: design and implementation plans for major feature work.
- `docs/testing/`: regression test matrix.

## Important Architecture

Keep product behavior in Dart when it can be platform-independent:

- Filtering, randomization, gesture history, trash state, album grouping, and deletion result modeling belong in `lib/domain/` or feature controllers.
- Platform APIs belong behind adapters in `lib/data/`.
- Android and iOS method-channel method names must stay aligned with the Dart adapters in `lib/data/mobile/`.

Controller patterns already in use:

- Feature controllers extend `ChangeNotifier`.
- Controllers expose immutable views where practical, such as `List.unmodifiable` or `Set.unmodifiable`.
- UI widgets accept injectable controllers or functions in tests when the production path owns the concrete implementation.
- Async loading paths use session counters where stale async results could otherwise update current UI state.

## Platform Channels

Current channel names:

- `rephoto/mobile_permissions`
- `rephoto/mobile_media`
- `rephoto/external_import`

Before changing a channel method:

1. Update the Dart adapter in `lib/data/mobile/`.
2. Update Android implementation in `MainActivity.kt` when Android uses it.
3. Update iOS implementation in `AppDelegate.swift` when iOS uses it.
4. Add or update method-channel tests under `test/data/mobile/` or feature tests that mock channels.

Do not assume a method exists on every platform. Some Dart methods intentionally handle `MissingPluginException` or `METHOD_NOT_IMPLEMENTED` fallbacks.

## Build, Test, And Lint

Install dependencies:

```bash
flutter pub get
```

Analyze:

```bash
flutter analyze
```

Run all tests with expanded output:

```bash
flutter test -r expanded
```

Run focused tests:

```bash
flutter test test/domain/services/random_pool_service_test.dart -r expanded
flutter test test/features/home/home_controller_test.dart -r expanded
flutter test test/data/mobile/mobile_media_repository_test.dart -r expanded
```

Format changed Dart files:

```bash
dart format <changed Dart files>
```

Android native compile check when editing Android Kotlin:

```bash
./gradlew :app:compileDebugKotlin
```

From the repo root, the Gradle wrapper is under `android/`, so run that command with `workdir=android` or use `android/gradlew` if invoking from the root.

## Test Matrix

Use `docs/testing/2026-02-24-rephoto-v1-test-matrix.md` as the baseline regression matrix.

Key areas to protect:

- Mobile permission granted, denied, and limited states.
- Media pagination and background loading.
- Swipe up to trash and undo/restore behavior.
- Permanent delete retaining failed ids for retry.
- Time and location filters working together.
- Random pool drawing without repetition until exhaustion and auto-reset.
- macOS folder import extension filtering.
- External storage import selection, progress, and delete flows.
- Video preview/play affordances in browser and trash flows.

## Engineering Conventions

- Prefer the existing `ChangeNotifier` controller style over introducing new state management.
- Keep domain logic deterministic and easy to unit test.
- Add tests close to the changed behavior. Match the existing `test/domain`, `test/data`, and `test/features` layout.
- Prefer repository interfaces and injectable collaborators for code that touches platform APIs.
- Preserve existing Chinese user-facing copy unless a task explicitly changes product language.
- Use `HuashuColors` and `HuashuTheme` for visual changes instead of ad hoc colors and typography.
- Keep UI changes responsive. The app has mobile and desktop/macOS surfaces.
- Keep `MediaItem` test data minimal, but include `pathOrUri` when image/video rendering behavior depends on it.
- For async UI/controller work, guard stale results with the existing session-counter pattern when multiple loads can overlap.
- Use structured Dart parsing and typed data mapping for channel results; avoid fragile string parsing.

## Constraints And Do-Not Rules

- Do not revert unrelated local changes.
- Do not make broad refactors while implementing a focused fix.
- Do not edit generated Flutter plugin files unless the task explicitly requires it.
- Do not add dependencies without a clear reason and tests or verification.
- Do not bypass the trash-first deletion model. Permanent deletion should report failed ids and keep them available for retry.
- Do not change platform channel names or payload shapes without updating Dart, Android/iOS implementations, and tests together.
- Do not assume Android, iOS, and macOS have the same media API behavior.
- Do not remove fallbacks for `MissingPluginException` or `METHOD_NOT_IMPLEMENTED` unless the platform implementation is proven complete.
- Do not let failed media/library reads crash the app; existing flows favor guarded status messages and best-effort refreshes.
- Avoid committing build artifacts from `build/`, `.dart_tool/`, Pods, or IDE state.

## PR Expectations

For a code change, include:

- What behavior changed.
- Which files or layers were touched.
- Tests run, with exact commands.
- Any platform-specific verification or unverified platform risk.

For UI changes, include:

- What screen or flow changed.
- Responsive considerations.
- Any manual verification performed.

For platform-channel changes, include:

- Dart method or payload changes.
- Android/iOS implementation changes.
- Mock-channel tests or focused feature tests.

## Definition Of Done

A task is done when:

- The implementation is scoped to the request.
- Relevant unit/widget tests pass.
- `flutter analyze` passes, or any remaining warnings are explicitly documented.
- Changed Dart files are formatted.
- Platform-channel behavior is verified on every touched side or clearly marked as unverified.
- User-visible behavior has either automated tests or a concise manual verification note.
- No unrelated files were reformatted or reverted.

