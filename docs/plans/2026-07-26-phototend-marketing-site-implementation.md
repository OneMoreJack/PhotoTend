# PhotoTend Marketing Site Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build and deploy a bilingual, responsive PhotoTend marketing site with a secure Supabase-backed waitlist, Resend email delivery, private release downloads, and production hosting at `phototend.onemorejack.top`.

**Architecture:** Keep the site in the existing repository under `website/` as an independent Next.js App Router project. Browser requests go only to typed Next.js server endpoints; those endpoints own Supabase service access, Resend delivery, webhook verification, and short-lived download authorization. Production runs on Vercel, with Supabase Postgres and private Storage as durable state.

**Tech Stack:** Next.js App Router, TypeScript, React, CSS Modules or Tailwind CSS, Vitest, Testing Library, Playwright, Zod, Supabase Postgres/Storage, Resend, React Email, Vercel.

**Design source:** `docs/plans/2026-07-26-phototend-marketing-site-design.md`

---

## Execution rules

- Use @superpowers:test-driven-development for each behavior change.
- Use @frontend-design before implementing the visual page.
- Use @next-best-practices while defining App Router and server boundaries.
- Use @superpowers:verification-before-completion before every completion claim.
- Preserve unrelated Flutter files and existing user changes.
- Do not put secrets, real emails, installation binaries, or generated build output in Git.
- Work autonomously except for login, verification code, service terms, billing, or domain-owner actions.
- Group all unavoidable account-owner actions into one configuration window where possible.
- Create small commits after each completed task.

### Task 1: Establish the website project boundary

**Files:**
- Create: `website/package.json`
- Create: `website/package-lock.json`
- Create: `website/tsconfig.json`
- Create: `website/next.config.ts`
- Create: `website/eslint.config.mjs`
- Create: `website/vitest.config.ts`
- Create: `website/playwright.config.ts`
- Create: `website/src/app/layout.tsx`
- Create: `website/src/app/page.tsx`
- Create: `website/src/app/globals.css`
- Create: `website/src/test/setup.ts`
- Modify: `.gitignore`

**Step 1: Add a failing smoke test**

Create `website/src/app/page.test.tsx` that renders the home page and expects the PhotoTend brand and primary waitlist call to action.

**Step 2: Run the focused test**

Run:

```bash
cd website && npm test -- page.test.tsx
```

Expected: failure because the site project and page do not exist.

**Step 3: Scaffold the independent Next.js project**

Create an App Router TypeScript project under `website/`. Add scripts for `dev`, `build`, `lint`, `typecheck`, `test`, `test:watch`, and `test:e2e`. Keep all generated caches and environment files ignored.

**Step 4: Implement the minimal page**

Render the brand and one accessible call-to-action so the smoke test passes.

**Step 5: Verify**

Run:

```bash
cd website && npm run typecheck && npm run lint && npm test
```

Expected: all commands pass.

**Step 6: Commit**

```bash
git add .gitignore website
git commit -m "chore: scaffold PhotoTend marketing site"
```

### Task 2: Add shared brand assets and design tokens

**Files:**
- Create: `website/public/brand/phototend-mark.svg`
- Create: `website/public/brand/phototend-app-icon.png`
- Create: `website/src/styles/tokens.css`
- Create: `website/src/components/brand/brand-lockup.tsx`
- Test: `website/src/components/brand/brand-lockup.test.tsx`

**Step 1: Write a failing brand test**

Verify that the lockup exposes localized brand text, useful alternative text, and no inaccessible duplicate label.

**Step 2: Run the test and confirm failure**

Run:

```bash
cd website && npm test -- brand-lockup.test.tsx
```

Expected: failure because the component does not exist.

**Step 3: Copy approved source assets**

Copy from `assets/brand/` into the public website directory. Do not redraw or alter the approved logo geometry.

**Step 4: Define tokens**

Mirror the approved palette:

- paper `#F4F0E8`
- surface `#FFFCF6`
- ink `#171A1C`
- muted `#756F66`
- accent `#B55A30`
- accent deep `#7E351F`
- accent soft `#F3D9C8`
- positive `#32795A`
- danger `#C9493A`

Define spacing, type scale, radii, focus ring, content width, and responsive breakpoints without external font hosting.

**Step 5: Implement and verify**

Run:

```bash
cd website && npm run typecheck && npm test -- brand-lockup.test.tsx
```

Expected: pass.

**Step 6: Commit**

```bash
git add website/public/brand website/src/styles website/src/components/brand
git commit -m "feat: add PhotoTend website brand system"
```

### Task 3: Implement locale routing and metadata

**Files:**
- Create: `website/src/i18n/config.ts`
- Create: `website/src/i18n/messages/zh-CN.ts`
- Create: `website/src/i18n/messages/en.ts`
- Create: `website/src/app/[locale]/layout.tsx`
- Create: `website/src/app/[locale]/page.tsx`
- Create: `website/src/components/locale-switcher.tsx`
- Create: `website/src/middleware.ts`
- Test: `website/src/i18n/config.test.ts`
- Test: `website/src/components/locale-switcher.test.tsx`

**Step 1: Write failing locale tests**

Cover supported locales, fallback behavior, browser-language redirect, localized brand text, metadata title, metadata description, canonical URL, and alternate-language links.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- config.test.ts locale-switcher.test.tsx
```

Expected: failure because locale modules do not exist.

**Step 3: Implement locale dictionaries and routing**

Use typed dictionaries and route-level locale validation. Default Chinese-like browser languages to `zh-CN`, otherwise use `en`. Always permit manual switching.

**Step 4: Add metadata**

Create localized title, description, Open Graph, canonical, and alternate-language metadata for `https://phototend.onemorejack.top`.

**Step 5: Verify**

Run:

```bash
cd website && npm run typecheck && npm test
```

Expected: pass.

**Step 6: Commit**

```bash
git add website/src/i18n website/src/app website/src/components/locale-switcher.tsx website/src/middleware.ts
git commit -m "feat: add bilingual marketing site routing"
```

### Task 4: Build the responsive marketing page

**Files:**
- Create: `website/src/components/site/site-header.tsx`
- Create: `website/src/components/marketing/hero.tsx`
- Create: `website/src/components/marketing/gesture-story.tsx`
- Create: `website/src/components/marketing/import-story.tsx`
- Create: `website/src/components/marketing/feature-grid.tsx`
- Create: `website/src/components/marketing/philosophy.tsx`
- Create: `website/src/components/marketing/platform-status.tsx`
- Create: `website/src/components/marketing/final-cta.tsx`
- Create: `website/src/components/site/site-footer.tsx`
- Create: `website/src/styles/marketing.css`
- Test: `website/src/app/[locale]/page.test.tsx`
- Test: `website/e2e/responsive.spec.ts`

**Step 1: Use @frontend-design**

Translate the approved design into a distinctive editorial page. Keep the warm paper palette, restrained motion, recognizable photo-card geometry, and real product capability claims.

**Step 2: Write failing content and layout tests**

Test the main value proposition, gesture labels, external import section, three core features, platform states, both CTA locations, landmark order, and heading hierarchy.

**Step 3: Write failing responsive E2E checks**

Cover at least:

- 390 × 844 mobile
- 768 × 1024 tablet
- 1440 × 1000 desktop

Check for horizontal overflow, visible calls to action, usable navigation, and no clipped content.

**Step 4: Implement sections**

Use semantic HTML and localized content. The import story must explicitly cover phone library, camera/storage card, external storage, and macOS folder use cases without claiming unsupported cross-platform behavior.

**Step 5: Add purposeful motion**

Use subtle, transform-only reveal or card motion. Respect `prefers-reduced-motion`. Do not hide essential information behind hover.

**Step 6: Verify**

Run:

```bash
cd website && npm run typecheck && npm test && npm run test:e2e -- responsive.spec.ts
```

Expected: pass at all viewports.

**Step 7: Commit**

```bash
git add website/src website/e2e/responsive.spec.ts
git commit -m "feat: build responsive PhotoTend marketing page"
```

### Task 5: Define the Supabase schema and local database contract

**Files:**
- Create: `website/supabase/config.toml`
- Create: `website/supabase/migrations/202607260001_marketing_site.sql`
- Create: `website/src/lib/database.types.ts`
- Create: `website/src/lib/supabase/server.ts`
- Create: `website/src/lib/supabase/schema-contract.test.ts`
- Create: `website/.env.example`

**Step 1: Write the schema contract test**

Assert that migrations contain:

- unique normalized email
- constrained platform/status/event values
- only one active default release per platform
- unique download token hash
- unique provider event identity
- RLS enabled
- no anonymous select policy
- private release bucket contract

**Step 2: Run and confirm failure**

Run:

```bash
cd website && npm test -- schema-contract.test.ts
```

Expected: failure because the migration is absent.

**Step 3: Write the migration**

Create `waitlist_entries`, `releases`, `download_grants`, `download_events`, and `email_events`. Add timestamps, indexes, foreign keys, constrained enums/checks, RLS, and least-privilege policies. Add a private `releases` Storage bucket.

**Step 4: Implement the server-only client**

Reject initialization when required environment variables are absent. Mark the module server-only.

**Step 5: Verify**

Run local Supabase database tests if the CLI runtime is available; otherwise run the schema contract test and document that remote migration verification remains pending.

**Step 6: Commit**

```bash
git add website/supabase website/src/lib website/.env.example
git commit -m "feat: define marketing data schema"
```

### Task 6: Implement waitlist validation and persistence

**Files:**
- Create: `website/src/lib/waitlist/schema.ts`
- Create: `website/src/lib/waitlist/service.ts`
- Create: `website/src/lib/waitlist/service.test.ts`
- Create: `website/src/app/api/waitlist/route.ts`
- Create: `website/src/app/api/waitlist/route.test.ts`

**Step 1: Write failing domain tests**

Cover:

- lowercasing and trimming email
- invalid email and oversized fields
- supported platform and locale
- honeypot rejection
- first insert
- duplicate idempotent update
- available release result
- unavailable release result
- database failure without partial success claim

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- service.test.ts route.test.ts
```

Expected: failure because the service and route do not exist.

**Step 3: Implement the minimal service**

Use Zod at the boundary and a repository interface for database calls. Keep user-visible results neutral so the API does not reveal whether an email already exists.

**Step 4: Implement the route**

Accept JSON POST only, validate origin/content type, apply cache prevention, and return localized result codes rather than provider errors.

**Step 5: Verify**

Run:

```bash
cd website && npm run typecheck && npm test -- service.test.ts route.test.ts
```

Expected: pass.

**Step 6: Commit**

```bash
git add website/src/lib/waitlist website/src/app/api/waitlist
git commit -m "feat: add secure waitlist endpoint"
```

### Task 7: Add rate limiting and abuse controls

**Files:**
- Create: `website/src/lib/security/rate-limit.ts`
- Create: `website/src/lib/security/request-fingerprint.ts`
- Create: `website/src/lib/security/rate-limit.test.ts`
- Modify: `website/src/app/api/waitlist/route.ts`
- Modify: `website/.env.example`

**Step 1: Write failing abuse tests**

Cover per-email cooldown, per-request-source limits, expiration, privacy-preserving source hash, malformed forwarding headers, and fail-safe provider errors.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- rate-limit.test.ts route.test.ts
```

Expected: failure.

**Step 3: Implement a provider boundary**

Use an injectable limiter. For production, use a durable serverless-compatible limit store; do not rely solely on process memory. Store only a keyed hash of request source data with a short lifetime.

**Step 4: Integrate with neutral responses**

Rate-limited requests must not reveal account existence and must not trigger database or email work.

**Step 5: Verify and commit**

```bash
cd website && npm run typecheck && npm test
git add website/src/lib/security website/src/app/api/waitlist/route.ts website/.env.example
git commit -m "feat: protect waitlist from abuse"
```

### Task 8: Implement download grants and private release delivery

**Files:**
- Create: `website/src/lib/downloads/token.ts`
- Create: `website/src/lib/downloads/service.ts`
- Create: `website/src/lib/downloads/service.test.ts`
- Create: `website/src/app/download/[token]/route.ts`
- Create: `website/src/app/download/[token]/route.test.ts`
- Create: `website/src/app/[locale]/download-error/page.tsx`

**Step 1: Write failing token tests**

Cover strong random token generation, keyed hashing, expiration, revocation, retired release, missing private object, successful signed URL, and event recording.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- downloads
```

Expected: failure.

**Step 3: Implement token and grant services**

Return the raw token once, store only the hash, and set an explicit expiration. Generate short-lived Supabase Storage signed URLs only after authorization succeeds.

**Step 4: Implement the download route**

Prevent token logging and referrer leakage. Record a minimal event, then redirect. Send invalid or expired grants to a localized recovery page.

**Step 5: Verify and commit**

```bash
cd website && npm run typecheck && npm test -- downloads
git add website/src/lib/downloads website/src/app/download website/src/app/[locale]/download-error
git commit -m "feat: add secure release downloads"
```

### Task 9: Add transactional email

**Files:**
- Create: `website/src/emails/download-email.tsx`
- Create: `website/src/emails/waitlist-email.tsx`
- Create: `website/src/lib/email/client.ts`
- Create: `website/src/lib/email/service.ts`
- Create: `website/src/lib/email/service.test.ts`
- Modify: `website/src/lib/waitlist/service.ts`
- Modify: `website/.env.example`

**Step 1: Write failing email tests**

Cover localized subject/body, platform/version, token URL, expiration text, unsubscribe link, available versus waiting platform, Resend failure, and idempotency key generation.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- email
```

Expected: failure.

**Step 3: Implement React Email templates**

Use simple email-client-safe markup, branded colors, plain-text fallback, one primary action, and no binary attachments.

**Step 4: Implement the Resend boundary**

Keep the API key server-only. Tag messages with safe internal IDs. Use an idempotency key scoped to entry, release, and send window.

**Step 5: Integrate without corrupting persistence**

Record the waitlist entry before sending. If delivery API submission fails, preserve the entry and return a retryable result without creating duplicate grants.

**Step 6: Verify and commit**

```bash
cd website && npm run typecheck && npm test
git add website/src/emails website/src/lib/email website/src/lib/waitlist website/.env.example
git commit -m "feat: email PhotoTend download links"
```

### Task 10: Implement verified Resend webhooks

**Files:**
- Create: `website/src/lib/email/webhook.ts`
- Create: `website/src/lib/email/webhook.test.ts`
- Create: `website/src/app/api/webhooks/resend/route.ts`
- Create: `website/src/app/api/webhooks/resend/route.test.ts`

**Step 1: Write failing webhook tests**

Cover valid signature, missing/invalid signature, duplicate event, sent, delivered, bounced, complained, clicked, unknown event, and malformed payload.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- webhook
```

Expected: failure.

**Step 3: Implement raw-body signature verification**

Verify before parsing or writing. Use the official provider verification path. Persist provider event identity uniquely so retries are idempotent.

**Step 4: Apply suppression behavior**

Bounce and complaint events change the waitlist status so future non-essential sends stop.

**Step 5: Verify and commit**

```bash
cd website && npm run typecheck && npm test -- webhook
git add website/src/lib/email/webhook.ts website/src/lib/email/webhook.test.ts website/src/app/api/webhooks/resend
git commit -m "feat: process verified email events"
```

### Task 11: Build the interactive waitlist experience

**Files:**
- Create: `website/src/components/waitlist/waitlist-form.tsx`
- Create: `website/src/components/waitlist/waitlist-form.test.tsx`
- Create: `website/src/components/waitlist/use-waitlist.ts`
- Modify: `website/src/components/marketing/hero.tsx`
- Modify: `website/src/components/marketing/final-cta.tsx`

**Step 1: Write failing component tests**

Cover:

- visible email label
- platform selection
- consent text
- disabled submitting state
- inline validation
- available-release success
- waitlist-only success
- neutral repeat success
- retryable failure
- keyboard submission
- focus management and live-region announcement

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- waitlist-form.test.tsx
```

Expected: failure.

**Step 3: Implement a shared form**

Both page locations reuse one form component. Use progressive enhancement and preserve typed values on recoverable failure.

**Step 4: Verify**

Run:

```bash
cd website && npm run typecheck && npm test
```

Expected: pass.

**Step 5: Commit**

```bash
git add website/src/components/waitlist website/src/components/marketing
git commit -m "feat: add accessible waitlist experience"
```

### Task 12: Add privacy, unsubscribe, and data deletion paths

**Files:**
- Create: `website/src/app/[locale]/privacy/page.tsx`
- Create: `website/src/app/[locale]/unsubscribe/[token]/page.tsx`
- Create: `website/src/app/api/unsubscribe/route.ts`
- Create: `website/src/app/api/unsubscribe/route.test.ts`
- Create: `website/src/app/[locale]/data-request/page.tsx`
- Modify: `website/src/components/site/site-footer.tsx`
- Modify: `website/src/i18n/messages/zh-CN.ts`
- Modify: `website/src/i18n/messages/en.ts`

**Step 1: Write failing behavior tests**

Cover valid unsubscribe, repeat unsubscribe, invalid token, no raw token storage, suppression of non-essential email, and accessible privacy/data-request pages.

**Step 2: Verify failure**

Run:

```bash
cd website && npm test -- unsubscribe privacy
```

Expected: failure.

**Step 3: Implement privacy content**

Accurately describe collected fields, purpose, Vercel/Supabase/Resend processing, cross-border infrastructure, retention, deletion, unsubscribe, and contact route. Mark the content for operator/legal review before broad paid promotion.

**Step 4: Implement unsubscribe**

Use a hashed token and neutral results. Preserve suppression records rather than immediately deleting proof of opt-out.

**Step 5: Add data request contact path**

Provide a clear request mechanism without inventing an operator identity or unconfirmed address. Use an environment-configured support address.

**Step 6: Verify and commit**

```bash
cd website && npm run typecheck && npm test
git add website/src/app website/src/components/site/site-footer.tsx website/src/i18n
git commit -m "feat: add privacy and email controls"
```

### Task 13: Add SEO, sharing assets, and accessibility checks

**Files:**
- Create: `website/src/app/robots.ts`
- Create: `website/src/app/sitemap.ts`
- Create: `website/src/app/opengraph-image.tsx`
- Create: `website/src/app/icon.png`
- Create: `website/e2e/accessibility.spec.ts`
- Create: `website/e2e/seo.spec.ts`

**Step 1: Write failing E2E checks**

Verify:

- one main landmark
- heading order
- named form controls
- keyboard-visible focus
- no serious automated accessibility violations
- localized title/description
- canonical and alternate links
- Open Graph image
- robots and sitemap

**Step 2: Verify failure**

Run:

```bash
cd website && npm run test:e2e -- accessibility.spec.ts seo.spec.ts
```

Expected: failure.

**Step 3: Implement SEO and fix accessibility issues**

Generate assets from approved brand sources. Do not add tracking scripts before consent and privacy decisions are finalized.

**Step 4: Verify and commit**

```bash
cd website && npm run test:e2e -- accessibility.spec.ts seo.spec.ts
git add website/src/app website/e2e
git commit -m "feat: complete marketing SEO and accessibility"
```

### Task 14: Prepare external service configuration

**Files:**
- Create: `website/docs/service-setup.md`
- Create: `website/scripts/verify-environment.mjs`
- Create: `website/scripts/verify-environment.test.ts`
- Modify: `website/.env.example`

**Step 1: Write a failing environment verifier test**

Cover missing, placeholder, malformed, and complete values without printing secret contents.

**Step 2: Implement the verifier**

Check all required public and private environment values. Output only variable names and readiness status.

**Step 3: Document exact external steps**

Document:

- Supabase project region and migration application
- private Storage bucket
- Resend registration and domain verification DNS records
- Resend API key and Webhook signing secret
- Vercel project root `website/`
- preview versus production variables
- production domain
- DNS records

**Step 4: Verify and commit**

```bash
cd website && npm test -- verify-environment && node scripts/verify-environment.mjs
git add website/docs website/scripts website/.env.example
git commit -m "docs: add production service setup"
```

### Task 15: Create Supabase, Resend, and Vercel resources

**External state:**
- Supabase project
- Resend account/domain/API key/webhook
- Vercel project/environment/domain
- DNS provider records

**Step 1: Inspect authenticated browser state**

Use @chrome:control-chrome because account-dependent setup may rely on the user's existing sessions. Do not ask for credentials in chat.

**Step 2: Create the Supabase project**

Use a region suitable for the chosen cross-border compromise. Generate a strong database password and store it only in the approved secret manager or service configuration. Apply migrations and verify RLS and private Storage.

**Step 3: Create the Vercel project**

Connect the current repository and set root directory to `website/`. Keep preview and production secrets separated.

**Step 4: Batch the user-owned actions**

Ask the user once to complete any required:

- Resend registration/login verification
- Supabase or Vercel login verification
- service terms
- DNS-provider verification
- paid-plan confirmation

Continue all independent local work while waiting when possible.

**Step 5: Configure Resend**

Verify the sending domain, create a least-privilege API key, register the production webhook, and store secrets only in Vercel.

**Step 6: Configure the production domain**

Add `phototend.onemorejack.top` to Vercel. Copy the exact DNS record Vercel requests into the current DNS provider. Verify DNS and HTTPS.

**Step 7: Capture non-secret evidence**

Record project IDs, regions, endpoint names, and verification statuses in an operator handoff. Never commit credentials.

### Task 16: Add a real release and run end-to-end tests

**Files:**
- Create: `website/e2e/waitlist.spec.ts`
- Create: `website/e2e/download.spec.ts`
- Create: `website/docs/release-runbook.md`

**Step 1: Determine release readiness**

Inspect the Flutter project for existing signed Android and macOS distributables. Do not claim a platform is downloadable without a verified installable artifact. Keep iPhone in waitlist-only mode unless an approved TestFlight/public distribution path exists.

**Step 2: Create or obtain approved release artifacts**

If producing signed artifacts needs certificates, keys, notarization, or account authority not already available, request only that specific owner action. Never upload an unsigned or unverified binary as a public experience release.

**Step 3: Upload to private Storage**

Store verified binaries under versioned paths and create active release records.

**Step 4: Write production-safe E2E tests**

Use a designated test email/domain and test records. Verify waitlist submission, email provider submission, download grant, signed Storage redirect, expiration, and unsubscribe. Avoid sending to arbitrary addresses.

**Step 5: Execute real chain**

Submit a controlled test email, confirm Resend accepted and delivered it, click the received link, download the expected artifact, and verify file identity/checksum.

**Step 6: Write the release runbook**

Document how to upload, activate, retire, revoke, resend, inspect events, and roll back a release.

**Step 7: Commit**

```bash
git add website/e2e website/docs/release-runbook.md
git commit -m "test: verify waitlist and release delivery"
```

### Task 17: Production quality and cross-region verification

**Files:**
- Create: `website/docs/production-verification.md`
- Modify: files implicated by verification failures only

**Step 1: Run the complete local gate**

Run:

```bash
cd website
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
```

Expected: all commands pass.

**Step 2: Inspect production deployment**

Verify desktop, tablet, and mobile layouts against production. Check console errors, network failures, forms, focus behavior, reduced motion, localization, metadata, and error pages.

**Step 3: Verify security boundaries**

Confirm:

- no secrets in client bundles
- no public table reads
- no public release objects
- invalid webhook signatures rejected
- raw tokens absent from logs
- expired/revoked grants denied
- rate limits active

**Step 4: Verify networks**

Test at least one China-mainland network path and one overseas path. Record DNS, TLS, page load, asset load, form submission, and email/download behavior. Clearly document limitations rather than claiming universal availability.

**Step 5: Run the Flutter regression gate**

The new subproject must not break the existing app:

```bash
flutter analyze
flutter test -r expanded
```

Expected: pass, or document pre-existing failures with evidence and no regression.

**Step 6: Record evidence**

Write exact commands, timestamps, production URL, tested viewports, test email redaction, release checksum, network observations, and remaining platform-specific risks.

**Step 7: Commit fixes and evidence**

```bash
git add website
git commit -m "chore: verify PhotoTend marketing production"
```

### Task 18: Completion audit and handoff

**Files:**
- Modify: `README.md`
- Modify: `website/README.md`
- Review: `docs/plans/2026-07-26-phototend-marketing-site-design.md`
- Review: `docs/plans/2026-07-26-phototend-marketing-site-implementation.md`

**Step 1: Perform requirement-by-requirement audit**

For every design acceptance criterion, point to authoritative evidence: code, passing test, deployed endpoint, database policy, storage access check, email event, downloaded artifact, screenshot, or production verification record.

**Step 2: Resolve every missing or weak item**

Do not treat a plausible implementation or narrow unit test as proof of an end-to-end requirement.

**Step 3: Update repository documentation**

Explain local development, environment setup, testing, deployment, release operations, and the boundary between Flutter and `website/`.

**Step 4: Run final verification**

Repeat all website gates and relevant Flutter gates after the last documentation or code change.

**Step 5: Commit**

```bash
git add README.md website/README.md website
git commit -m "docs: hand off PhotoTend marketing site"
```

**Step 6: Mark the Goal complete only if proven**

Completion requires:

- production URL works
- responsive bilingual page works
- Waitlist persists securely
- real email delivery works
- secure real artifact download works for every advertised available platform
- privacy and unsubscribe work
- external service and DNS configuration are verified
- all applicable automated and manual gates pass
- no required work remains
