# PhotoTend Android Icon Spacing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Increase the optical breathing room of the Android 8+ PhotoTend adaptive icon without changing the approved logo geometry or other platform assets.

**Architecture:** Keep `assets/brand/phototend-mark.svg` as the single immutable brand source. Re-render only the Android adaptive foreground onto its existing 432 × 432 transparent canvas at 68% scale, centered over the existing cream adaptive background; verify the binary dimensions, transparency bounds, asset scope, and Android build.

**Tech Stack:** SVG, `rsvg-convert`, PNG/Pillow inspection, Android adaptive icon resources, Flutter/Gradle.

---

### Task 1: Re-render the Android adaptive foreground

**Files:**
- Modify: `android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png`
- Reference: `assets/brand/phototend-mark.svg`
- Reference: `docs/plans/2026-07-20-phototend-android-icon-spacing-design.md`

**Step 1: Record the current asset scope**

Run:

```bash
git status --short
shasum android/app/src/main/res/mipmap-*/ic_launcher.png ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png
```

Expected: the worktree is clean and checksums can be compared after rendering.

**Step 2: Render the approved source at 68%**

Run:

```bash
rsvg-convert -w 294 -h 294 \
  --page-width 432 --page-height 432 \
  --left 69 --top 69 \
  -o android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png \
  assets/brand/phototend-mark.svg
```

Expected: only the Android adaptive foreground changes. The SVG, legacy Android launchers, and Apple icon catalogs remain unchanged.

**Step 3: Verify dimensions and centered transparency**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png
python3 - <<'PY'
from PIL import Image

path = 'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png'
image = Image.open(path).convert('RGBA')
assert image.size == (432, 432)
bounds = image.getchannel('A').getbbox()
assert bounds == (69, 69, 363, 363), bounds
print(f'ADAPTIVE_FOREGROUND_OK bounds={bounds}')
PY
```

Expected: 432 × 432, alpha enabled, opaque content bounds exactly `(69, 69, 363, 363)`.

**Step 4: Inspect the result visually**

View the foreground PNG and confirm the four-card geometry is centered, the front card is square and unrotated, the rear cards remain distinct, and the hole remains visible.

**Step 5: Commit**

```bash
git add android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png
git commit -m "fix: add breathing room to Android app icon"
```

### Task 2: Verify platform scope and Android build

**Files:**
- Modify only files required to correct failures caused by the foreground change

**Step 1: Confirm no unrelated platform icons changed**

Run the checksum command from Task 1 again and compare it with the baseline. Then run:

```bash
git diff HEAD~1 --name-only
```

Expected: the implementation commit changes only `android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png`.

**Step 2: Run Android resource and Kotlin verification**

Run from `android/`:

```bash
./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`.

**Step 3: Build the APK and inspect packaged resources**

Run:

```bash
flutter build apk --debug
/Users/jackli/Library/Android/sdk/build-tools/35.0.0/aapt2 dump resources \
  build/app/outputs/flutter-apk/app-debug.apk \
  | rg 'drawable/ic_launcher_foreground|color/ic_launcher_background|mipmap/ic_launcher'
```

Expected: the adaptive foreground, cream background, and launcher resource are packaged.

**Step 4: Run final repository checks**

Run:

```bash
flutter test -r expanded
flutter analyze
git status --short --branch
```

Expected: all tests pass, analysis reports no issues, and the worktree is clean.
