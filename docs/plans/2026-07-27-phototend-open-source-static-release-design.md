# PhotoTend Open-Source Static Release Design

## Objective

Turn PhotoTend into a public GPLv3 project with a backend-free bilingual marketing site, a direct Android download, and a reproducible formally signed Android release. Android is the only downloadable platform; macOS and iPhone remain marked “Coming soon.”

## Product and Content

The existing editorial marketing direction remains:

- A responsive Chinese/English landing page.
- An interactive hero that demonstrates the app’s gesture-first photo workflow.
- A dedicated external-import story that shows phone, camera, memory-card, and external-storage sources.
- Clear product benefits: fast photo triage, reversible trash-first organization, timeline context, and local-first organization.
- Android as the primary call to action.
- macOS and iPhone as non-clickable “Coming soon” platform statuses.

The waitlist is removed. Because Android is available for direct download, requiring or collecting an email adds unnecessary friction. No email form, database, transactional email, unsubscribe flow, download token, or rate-limit backend remains.

## Open-Source Presentation

The final call-to-action area becomes an open-source section with:

- A direct “Download for Android” action.
- A “View source on GitHub” action.
- A concise GNU GPLv3 notice explaining that derivative distributions must remain under the same license.
- A visible GitHub link in the site navigation and footer.

The root repository receives the complete GNU GPLv3 license and an updated README covering product scope, supported platforms, local development, website development, release signing, and security expectations.

## Distribution Architecture

The website remains a Next.js application deployed from `website/` on Vercel, but contains no application backend or required runtime secrets. Its Android button points to a stable GitHub Release URL:

`https://github.com/OneMoreJack/PhotoTend/releases/latest/download/phototend-android.apk`

GitHub Releases stores the signed APK under the fixed asset name `phototend-android.apk`. The repository does not track APKs, AABs, keystores, signing properties, or credentials.

## Android Identity and Signing

The Android application ID and Kotlin package become:

`top.onemorejack.phototend`

Release builds use a dedicated production keystore rather than Flutter’s debug key. The keystore and passwords live outside the repository. Gradle reads signing values from environment variables, fails clearly when a release build lacks them, and retains normal unsigned/debug development behavior where appropriate.

The first public artifact is version `1.0.0+1`, tagged `v1.0.0`. Before upload, the APK’s package name and signature are verified.

## Public-Repository Safety

Before changing repository visibility, inspect both the current tree and full Git history for:

- API keys, OAuth credentials, private keys, service-role tokens, and real `.env` files.
- Android keystores, signing properties, APK/AAB build outputs, and other binary artifacts.
- Personal paths or operational documentation that should not be public.

Add explicit ignore rules for Android signing files and release artifacts. Only after the audit and tests pass should the repository become public.

## Deployment

The existing Vercel project continues to deploy `website/`. Pushing the release branch and merging it to `main` triggers production deployment. The custom domain is:

`https://phototend.onemorejack.top`

After DNS propagation, verify:

- HTTPS and locale routing.
- Desktop and mobile layout.
- GitHub links.
- The stable Android download URL.
- No waitlist or backend endpoints are exposed or referenced.

## Verification

Release readiness requires:

- `flutter analyze`
- `flutter test -r expanded`
- Android Kotlin compile checks after the package move
- A formally signed `flutter build apk --release`
- Package-name and signature inspection
- Website unit tests, typecheck, lint, production build, and focused Playwright checks
- Current-tree and full-history secret/artifact scans
- Public GitHub repository, tag, release, and APK asset inspection
- Production Vercel and custom-domain smoke tests

