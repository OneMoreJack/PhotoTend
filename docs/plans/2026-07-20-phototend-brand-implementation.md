# PhotoTend Brand Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the user-visible RePhoto brand with “理好相册 / PhotoTend” and install one verified icon system across Android, iOS, and macOS without renaming internal APIs or identifiers.

**Architecture:** Keep internal Dart class names, package names, bundle identifiers, and method channels unchanged. Route in-app names through the existing localization layer, localize native system display names per platform, use `PhotoTend` for cross-language import album/folder defaults, and generate every platform icon from one committed SVG source.

**Tech Stack:** Flutter/Dart localization, Android resources and adaptive icons, Apple asset catalogs and InfoPlist localization, SVG source assets, `rsvg-convert`, `sips`, Flutter tests and analyzer.

---

### Task 1: Commit the approved brand source

**Files:**
- Create: `assets/brand/phototend-mark.svg`
- Reference: `docs/plans/2026-07-20-phototend-brand-design.md`

**Step 1: Copy the approved SVG into the repository**

Copy the exact contents of the approved `phototend-logo-geometry-v1.svg` into `assets/brand/phototend-mark.svg`. Do not include the preview board, labels, mockup shadows, or system rounded mask.

**Step 2: Validate the source**

Run:

```bash
xmllint --noout assets/brand/phototend-mark.svg
rg 'linearGradient|radialGradient|filter|text|image' assets/brand/phototend-mark.svg
```

Expected: XML validation passes and `rg` returns no matches.

**Step 3: Commit**

```bash
git add assets/brand/phototend-mark.svg docs/plans/2026-07-20-phototend-brand-design.md
git commit -m "docs: add PhotoTend brand source"
```

### Task 2: Rename the in-app user-visible brand

**Files:**
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/features/albums/album_summary_page.dart`
- Modify: `lib/features/media/media_browser_page.dart`
- Modify: `test/features/home/home_page_test.dart`
- Modify: any focused tests found by `rg -n "RePhoto" test`

**Step 1: Update tests first**

Change Chinese-locale expectations from `RePhoto` to `理好相册`. Add or update an English-locale assertion expecting `PhotoTend`. Preserve expectations that intentionally verify the title is absent on a detail surface.

**Step 2: Run focused tests and confirm failure**

```bash
flutter test test/features/home/home_page_test.dart -r expanded
```

Expected: title assertions fail because production strings still return `RePhoto`.

**Step 3: Update localized titles**

Set the English localization getter to:

```dart
String get appTitle => 'PhotoTend';
```

Set the Simplified Chinese localization getter to:

```dart
String get appTitle => '理好相册';
```

Replace hardcoded user-visible `RePhoto` text in album and media surfaces with `localeScope.localizations.appTitle` or the existing local localization accessor. Do not rename `RePhotoApp`, `RePhotoLocaleScope`, files, imports, or class names.

**Step 4: Format and verify**

```bash
dart format lib/l10n/app_localizations.dart lib/features/albums/album_summary_page.dart lib/features/media/media_browser_page.dart test/features/home/home_page_test.dart
flutter test test/features/home/home_page_test.dart -r expanded
```

Expected: focused tests pass.

**Step 5: Commit**

```bash
git add lib/l10n/app_localizations.dart lib/features/albums/album_summary_page.dart lib/features/media/media_browser_page.dart test/features/home/home_page_test.dart
git commit -m "feat: rename in-app brand to PhotoTend"
```

### Task 3: Rename import destinations without touching channel contracts

**Files:**
- Modify: `lib/features/import/import_controller.dart`
- Modify: `android/app/src/main/kotlin/com/example/rephoto/ExternalImportService.kt`
- Modify: `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt`
- Modify: `test/features/import/import_controller_test.dart`
- Modify: `test/data/mobile/mobile_media_repository_test.dart`

**Step 1: Update focused test expectations**

Change default album, relative path, and fallback file expectations from `RePhoto` to `PhotoTend`. Do not change method names, channel names, argument keys, or payload shapes.

**Step 2: Run focused tests and confirm failure**

```bash
flutter test test/features/import/import_controller_test.dart test/data/mobile/mobile_media_repository_test.dart -r expanded
```

Expected: assertions fail on old `RePhoto` defaults.

**Step 3: Update defaults**

Change Dart default album parameters and Android native fallbacks to `PhotoTend`, including `PhotoTend-import.jpg` and `PhotoTend-import.mp4`. Keep internal log tags unchanged unless they are displayed to users.

**Step 4: Format and verify**

```bash
dart format lib/features/import/import_controller.dart test/features/import/import_controller_test.dart test/data/mobile/mobile_media_repository_test.dart
flutter test test/features/import/import_controller_test.dart test/data/mobile/mobile_media_repository_test.dart -r expanded
```

Expected: focused tests pass.

**Step 5: Commit**

Stage only these brand-related hunks. The worktree already contains unrelated edits in some of these files, so inspect `git diff` and use partial staging if necessary.

```bash
git diff -- lib/features/import/import_controller.dart test/features/import/import_controller_test.dart android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt
git add -p lib/features/import/import_controller.dart test/features/import/import_controller_test.dart android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt
git add android/app/src/main/kotlin/com/example/rephoto/ExternalImportService.kt test/data/mobile/mobile_media_repository_test.dart
git commit -m "feat: rename default import destination"
```

### Task 4: Localize native system display names

**Files:**
- Create: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values-zh-rCN/strings.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Create: `ios/Runner/en.lproj/InfoPlist.strings`
- Create: `ios/Runner/zh-Hans.lproj/InfoPlist.strings`
- Modify: `macos/Runner/Configs/AppInfo.xcconfig`
- Create: `macos/Runner/en.lproj/InfoPlist.strings`
- Create: `macos/Runner/zh-Hans.lproj/InfoPlist.strings`

**Step 1: Add Android localized names**

Set the default resource to `PhotoTend` and Simplified Chinese resource to `理好相册`, then replace the manifest literal with:

```xml
android:label="@string/app_name"
```

**Step 2: Add Apple localized names**

Use `PhotoTend` as the nonlocalized fallback. Add localized `CFBundleDisplayName` values in `InfoPlist.strings` for English and Simplified Chinese. Update the two iOS photo permission descriptions to say `PhotoTend`; do not translate unrelated permission copy in this task.

Set macOS `PRODUCT_NAME = PhotoTend`. Add localized `CFBundleDisplayName` strings so Simplified Chinese Finder/Launchpad surfaces can show `理好相册` where supported.

**Step 3: Validate configuration files**

```bash
plutil -lint ios/Runner/Info.plist
plutil -lint ios/Runner/en.lproj/InfoPlist.strings
plutil -lint ios/Runner/zh-Hans.lproj/InfoPlist.strings
plutil -lint macos/Runner/en.lproj/InfoPlist.strings
plutil -lint macos/Runner/zh-Hans.lproj/InfoPlist.strings
```

Expected: every file reports `OK`.

**Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/values/strings.xml android/app/src/main/res/values-zh-rCN/strings.xml ios/Runner/Info.plist ios/Runner/en.lproj/InfoPlist.strings ios/Runner/zh-Hans.lproj/InfoPlist.strings macos/Runner/Configs/AppInfo.xcconfig macos/Runner/en.lproj/InfoPlist.strings macos/Runner/zh-Hans.lproj/InfoPlist.strings
git commit -m "feat: localize PhotoTend system name"
```

### Task 5: Generate and install platform icon assets

**Files:**
- Create: `assets/brand/phototend-app-icon-1024.png`
- Replace: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Create: Android adaptive foreground/background resources as required
- Replace: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` only if required sizes are missing
- Replace: `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`

**Step 1: Render the master PNG**

```bash
rsvg-convert -w 1024 -h 1024 -o assets/brand/phototend-app-icon-1024.png assets/brand/phototend-mark.svg
sips -g pixelWidth -g pixelHeight -g hasAlpha assets/brand/phototend-app-icon-1024.png
```

Expected: `1024 × 1024`. If `hasAlpha` is `yes`, flatten against `#F4F0E8` before installing the iOS master.

**Step 2: Generate Apple sizes from the same master**

Use `sips -z <height> <width>` on copies of the master to populate every filename already listed by the iOS and macOS `Contents.json` files. Never upscale from a smaller derivative.

**Step 3: Generate Android icons**

Generate legacy launcher PNGs at mdpi `48`, hdpi `72`, xhdpi `96`, xxhdpi `144`, and xxxhdpi `192`. Add an Android 8+ adaptive icon with warm cream background and a foreground derived from the same mark, preserving the adaptive safe zone. Keep the manifest resource name `@mipmap/ic_launcher`.

**Step 4: Verify dimensions and visual identity**

```bash
find android/app/src/main/res ios/Runner/Assets.xcassets/AppIcon.appiconset macos/Runner/Assets.xcassets/AppIcon.appiconset -name '*.png' -print0 | xargs -0 file
git diff --stat
```

Expected: all required files have their catalog-declared dimensions; no build artifacts or unrelated images are added.

**Step 5: Commit**

```bash
git add assets/brand android/app/src/main/res/mipmap-* ios/Runner/Assets.xcassets/AppIcon.appiconset macos/Runner/Assets.xcassets/AppIcon.appiconset
git commit -m "feat: install PhotoTend app icons"
```

### Task 6: Run full verification

**Files:**
- Modify only files required by test or analyzer failures caused by this rebrand

**Step 1: Search for stale user-visible branding**

```bash
rg -n "RePhoto|Rephoto|rephoto" lib android ios macos test --glob '!**/Generated*' --glob '!**/.symlinks/**'
```

Expected: remaining matches are reviewed individually and limited to intentionally preserved internal identifiers, bundle IDs, package paths, channel implementation details, or historical test fixtures.

**Step 2: Run Dart verification**

```bash
flutter test -r expanded
flutter analyze
```

Expected: all tests pass and analyzer reports no issues.

**Step 3: Run platform verification**

```bash
./gradlew :app:compileDebugKotlin
flutter build ios --simulator --no-codesign
flutter build macos
```

Run Gradle from `android/`. If Apple builds are unavailable, record them explicitly as unverified rather than claiming success.

**Step 4: Manual visual checks**

- Confirm Simplified Chinese launcher name is `理好相册`.
- Confirm English launcher name is `PhotoTend`.
- Confirm all three platform icons use the same four-card geometry.
- Confirm the rear cards remain distinct at launcher, settings, search, and macOS Finder sizes.
- Confirm the front card is square and unrotated.
- Confirm the right-upper hole remains visible but secondary.
- Confirm import defaults create/use `PhotoTend`, not `RePhoto`.

**Step 5: Commit any verification-only corrections**

```bash
git add <only corrected brand files>
git commit -m "fix: polish PhotoTend brand rollout"
```

