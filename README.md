# PhotoTend

PhotoTend is an open-source Flutter app for tending a large photo and video
library one item at a time. It combines gesture-first browsing, trash-first
deletion, timeline summaries, and external-storage import.

## Platform status

- **Android:** supported and distributed through
  [GitHub Releases](https://github.com/OneMoreJack/PhotoTend/releases).
- **iPhone:** source is present but the product has not been tested for release.
- **macOS:** source is present but the product has not been tested for release.

The website labels iPhone and macOS as “Coming soon” until they have completed
platform-specific testing.

## Product scope

- Browse photos and videos with directional gestures.
- Move items to trash first, restore them, and confirm permanent deletion later.
- Filter and group the library by time and location.
- Import media from external folders and storage devices.
- Keep domain behavior in testable Dart services while platform APIs stay behind
  Android/iOS adapters.

## Development

```bash
flutter pub get
flutter analyze
flutter test -r expanded
```

For Android native changes:

```bash
cd android
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
```

The regression baseline is documented in
[`docs/testing/2026-02-24-rephoto-v1-test-matrix.md`](docs/testing/2026-02-24-rephoto-v1-test-matrix.md).

## Marketing website

The bilingual Next.js site lives in `website/`. It has no waitlist, database,
email service, download-token service, or required runtime secrets.

```bash
cd website
npm ci
npm run dev
```

Before shipping website changes:

```bash
npm test
npm run typecheck
npm run lint
npm run build
npx playwright test
```

## Android release signing

Release builds use a dedicated keystore outside this repository. Gradle reads:

- `PHOTOTEND_KEYSTORE_PATH`
- `PHOTOTEND_KEYSTORE_PASSWORD`
- `PHOTOTEND_KEY_ALIAS`
- `PHOTOTEND_KEY_PASSWORD`

With those variables available:

```bash
flutter build apk --release
```

Never commit a keystore, signing password, `.env` file, APK, or AAB. Back up the
production keystore securely: losing it prevents compatible updates to existing
Android installations.

## License

PhotoTend is licensed under the
[GNU General Public License v3.0](LICENSE). If you distribute a modified
version, you must make its corresponding source available under the same
license.
