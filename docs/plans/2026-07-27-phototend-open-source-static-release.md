# PhotoTend Open-Source Static Release Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish PhotoTend as a GPLv3 open-source project with a backend-free bilingual marketing site and a formally signed Android APK downloadable from GitHub Releases.

**Architecture:** Remove all Supabase/Resend and tokenized-download code so the Next.js site has no data backend or runtime secret requirement. Serve a stable GitHub Release asset from the marketing CTAs, while Android Gradle reads release-signing credentials from external environment variables and keeps all signing material outside Git.

**Tech Stack:** Flutter/Dart, Android Gradle/Kotlin, Next.js/React/TypeScript, Vitest, Playwright, GitHub Releases, Vercel.

---

### Task 1: Establish a clean baseline and public-release guardrails

**Files:**
- Modify: `.gitignore`
- Create: `LICENSE`
- Modify: `README.md`
- Test: repository file and history scans

**Step 1: Install dependencies and run the existing baseline**

Run:

```bash
flutter pub get
flutter analyze
flutter test -r expanded
cd website && npm ci
npm test
npm run typecheck
npm run lint
npm run build
```

Expected: the checked-out `origin/main` baseline passes, or any pre-existing failure is recorded before implementation.

**Step 2: Add public-release safety assertions**

Add explicit `.gitignore` rules for:

```gitignore
*.jks
*.keystore
key.properties
android/signing.properties
*.apk
*.aab
```

**Step 3: Add GNU GPLv3**

Create the root `LICENSE` with the complete GNU General Public License version 3 text. Update `README.md` with supported-platform truth, build commands, website commands, release-signing environment variable names, and an explicit “do not commit signing material or release binaries” warning.

**Step 4: Scan the current tree and full history**

Run filename and content scans for `.env`, APK/AAB, keystores, signing properties, private-key blocks, and known credential formats. Inspect every positive match; examples and lockfile integrity hashes are not secrets.

Expected: no publish-blocking secret or release binary exists in tracked history.

**Step 5: Commit**

```bash
git add .gitignore LICENSE README.md docs/plans
git commit -m "docs: prepare PhotoTend for open source"
```

### Task 2: Replace waitlist behavior with open-source download actions

**Files:**
- Modify: `website/src/i18n/messages/en.ts`
- Modify: `website/src/i18n/messages/zh-CN.ts`
- Modify: `website/src/components/marketing/final-cta.tsx`
- Modify: `website/src/components/site/site-header.tsx`
- Modify: `website/src/components/site/site-footer.tsx`
- Modify: `website/src/app/[locale]/page.test.tsx`
- Modify: `website/e2e/seo.spec.ts`
- Delete: `website/src/components/waitlist/`
- Delete: `website/src/components/unsubscribe/`

**Step 1: Write failing page tests**

Assert that both locale pages contain:

- The stable `releases/latest/download/phototend-android.apk` URL.
- The GitHub repository URL.
- Android availability.
- macOS/iPhone “Coming soon.”
- GPLv3 open-source copy.

Assert that the page contains no waitlist form, email field, or subscribe action.

**Step 2: Run the focused tests and verify failure**

Run:

```bash
cd website
npm test -- src/app/[locale]/page.test.tsx
```

Expected: FAIL because the current final CTA still renders the email waitlist.

**Step 3: Implement the open-source CTA**

Replace the waitlist component with two clear links and platform-status copy. Add GitHub navigation/footer links with accessible external-link labels. Keep bilingual copy concise and preserve the current visual language.

**Step 4: Delete obsolete client components**

Remove the waitlist hook/form and unsubscribe form after all imports have been removed.

**Step 5: Run focused unit and E2E tests**

Run:

```bash
npm test -- src/app/[locale]/page.test.tsx
npx playwright test e2e/seo.spec.ts
```

Expected: PASS.

**Step 6: Commit**

```bash
git add website
git commit -m "feat: replace waitlist with open-source downloads"
```

### Task 3: Remove the Supabase, Resend, and private-download backend

**Files:**
- Modify: `website/package.json`
- Modify: `website/package-lock.json`
- Modify: `website/next.config.ts`
- Delete: `website/src/app/api/`
- Delete: `website/src/app/download/`
- Delete: `website/src/app/[locale]/unsubscribe/`
- Delete: `website/src/lib/downloads/`
- Delete: `website/src/lib/email/`
- Delete: `website/src/lib/security/`
- Delete: `website/src/lib/supabase/`
- Delete: `website/src/lib/unsubscribe/`
- Delete: `website/src/lib/waitlist/`
- Delete: `website/src/emails/`
- Delete: `website/supabase/`
- Delete: `website/.env.example`
- Delete: `website/docs/service-setup.md`
- Delete: `website/scripts/verify-environment.mjs`
- Delete: `website/scripts/verify-environment.test.ts`
- Delete: `website/src/lib/database.types.ts`

**Step 1: Add a backend-absence regression check**

Update the website tests to ensure the rendered site needs no environment variables and contains no waitlist/API route references.

**Step 2: Remove backend routes and libraries**

Delete database, mail, webhook, rate-limit, token, and unsubscribe code. Remove `@supabase/supabase-js`, `resend`, `server-only`, and `zod` if no remaining source imports use them.

**Step 3: Regenerate the lockfile**

Run:

```bash
cd website
npm install
```

Expected: lockfile contains no Supabase or Resend application dependencies.

**Step 4: Verify the frontend**

Run:

```bash
npm test
npm run typecheck
npm run lint
npm run build
```

Expected: PASS and no server-only marketing API routes in the Next.js route list.

**Step 5: Commit**

```bash
git add website
git commit -m "refactor: remove marketing backend services"
```

### Task 4: Give Android a production identity and signing configuration

**Files:**
- Modify: `android/app/build.gradle.kts`
- Move: `android/app/src/main/kotlin/com/example/rephoto/MainActivity.kt` to `android/app/src/main/kotlin/top/onemorejack/phototend/MainActivity.kt`
- Move: `android/app/src/main/kotlin/com/example/rephoto/ExternalImportService.kt` to `android/app/src/main/kotlin/top/onemorejack/phototend/ExternalImportService.kt`
- Move: `android/app/src/main/kotlin/com/example/rephoto/MediaProjectionPolicy.kt` to `android/app/src/main/kotlin/top/onemorejack/phototend/MediaProjectionPolicy.kt`
- Move: `android/app/src/test/kotlin/com/example/rephoto/MediaProjectionPolicyTest.kt` to `android/app/src/test/kotlin/top/onemorejack/phototend/MediaProjectionPolicyTest.kt`
- Modify: Android package declarations and manifest references discovered by `rg`

**Step 1: Write a Gradle configuration check**

Verify the build file contains:

- `namespace = "top.onemorejack.phototend"`
- `applicationId = "top.onemorejack.phototend"`
- A release signing config sourced from `PHOTOTEND_KEYSTORE_PATH`, `PHOTOTEND_KEYSTORE_PASSWORD`, `PHOTOTEND_KEY_ALIAS`, and `PHOTOTEND_KEY_PASSWORD`.
- No debug signing config for release.

**Step 2: Move Kotlin sources and update package declarations**

Keep channel names and payloads unchanged. Change only the Java/Kotlin package identity and paths.

**Step 3: Implement external release signing**

Configure Gradle so release builds require the four environment variables and load the keystore outside the repository. Do not add a signing properties file.

**Step 4: Verify Android compilation and tests**

Run:

```bash
cd android
./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
```

Expected: PASS.

**Step 5: Verify Flutter**

Run:

```bash
flutter analyze
flutter test -r expanded
```

Expected: PASS.

**Step 6: Commit**

```bash
git add android
git commit -m "build: configure PhotoTend Android release identity"
```

### Task 5: Generate and verify the formal Android release

**Files outside repository:**
- Create: a dedicated PhotoTend release keystore in a user-controlled secure directory
- Store: keystore and key passwords in macOS Keychain

**Step 1: Generate strong signing credentials**

Generate independent high-entropy passwords without printing them. Create a long-lived RSA release key with alias `phototend`.

**Step 2: Store credentials outside Git**

Save the keystore outside the repository and store secrets in macOS Keychain. Provide a backup warning because losing the key prevents future compatible upgrades.

**Step 3: Build the release APK**

Read secrets from Keychain into the four `PHOTOTEND_*` environment variables for one build process, then run:

```bash
flutter build apk --release
```

Expected: `build/app/outputs/flutter-apk/app-release.apk`.

**Step 4: Verify artifact identity and signature**

Run Android build-tool inspection (`apkanalyzer`/`aapt` and `apksigner`) to prove:

- Package: `top.onemorejack.phototend`
- Version: `1.0.0` / code `1`
- Signature verifies
- The certificate is not the Android debug certificate

Copy only for upload under the transient asset name `phototend-android.apk`; never stage it.

### Task 6: Complete release verification and publish through GitHub

**Files:**
- Modify only files required by findings from the release review

**Step 1: Run the complete local verification suite**

Run:

```bash
flutter analyze
flutter test -r expanded
cd website
npm test
npm run typecheck
npm run lint
npm run build
npx playwright test
```

Expected: PASS.

**Step 2: Re-run public safety audit**

Check `git status --short --branch -uall`, staged contents, current tracked files, full history, and the exact APK upload asset. Confirm no keystore, password, `.env`, APK, AAB, or service credential is committed.

**Step 3: Push and open a pull request**

```bash
git push -u origin codex/open-source-static-release
gh pr create --base main --head codex/open-source-static-release
```

Include behavior, touched layers, exact tests, responsive verification, Android package/signing verification, and platform limitations.

**Step 4: Merge after checks**

Inspect PR checks and merge only when green. Re-read remote `main` to confirm the merge commit.

**Step 5: Make the repository public**

Change `OneMoreJack/PhotoTend` visibility to public only after the clean-history audit and merged source verification.

**Step 6: Create and verify GitHub Release**

Create tag `v1.0.0` from the merged `main`, publish release notes, and upload the signed file as `phototend-android.apk`. Re-read the release and test the stable latest-download URL.

### Task 7: Verify Vercel production and custom domain

**Files:**
- No source changes unless a production-only defect is found

**Step 1: Confirm Vercel production deployment**

Verify the deployment corresponds to merged `main` and reports Ready.

**Step 2: Verify DNS and HTTPS**

Check `phototend.onemorejack.top` resolution and load:

- `/zh-CN`
- `/en`
- `robots.txt`
- `sitemap.xml`

Expected: valid HTTPS responses with the current open-source site.

**Step 3: Smoke-test production interactions**

Verify desktop and mobile layouts, hero interaction, GitHub navigation, platform status, and the Android download response.

**Step 4: Report final shipped state**

Report commit/PR/tag/release URLs, deployment URL, download URL, verification commands, signing-certificate fingerprint, and any DNS or platform limitations.

