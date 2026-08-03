# PhotoTend Root Marketing Page Restore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the PhotoTend root URL render the same complete Chinese marketing experience as `/zh-CN` while preserving the bilingual static routes.

**Architecture:** Extract the shared marketing-page composition into a locale-aware component used by both root and localized route modules. Load the marketing stylesheet from the root layout so the root route receives the same visual treatment during static export.

**Tech Stack:** Next.js App Router, React, TypeScript, Vitest, Testing Library, static export.

---

### Task 1: Add a root-page regression test

**Files:**
- Modify: `website/src/app/page.test.tsx`

**Step 1: Replace the simplified-page assertion with complete-story assertions**

Assert that `/` renders the Chinese hero heading, the gesture section, the import section, and all three Android download links.

**Step 2: Run the focused test and verify it fails**

Run: `cd website && npm test -- src/app/page.test.tsx`

Expected: FAIL because the current root page only renders the simplified heading, paragraph, and one download link.

### Task 2: Share the complete marketing composition with the root route

**Files:**
- Create: `website/src/components/marketing/marketing-page.tsx`
- Modify: `website/src/app/page.tsx`
- Modify: `website/src/app/[locale]/page.tsx`
- Modify: `website/src/app/layout.tsx`
- Modify: `website/src/app/[locale]/layout.tsx`

**Step 1: Extract the shared page composition**

Create `MarketingPageContent({ locale })` containing the skip link, header, seven marketing sections, and footer currently assembled by the localized page.

**Step 2: Render the shared component at both route types**

Render `MarketingPageContent` with `defaultLocale` at `/`. Keep locale validation and static params in `[locale]/page.tsx`, then render the same component with the validated locale.

**Step 3: Make the stylesheet available to the root route**

Move the `marketing.css` import from `[locale]/layout.tsx` to the root layout. Do not alter visual styles or copy.

**Step 4: Run focused page tests**

Run: `cd website && npm test -- src/app/page.test.tsx 'src/app/[locale]/page.test.tsx'`

Expected: PASS.

**Step 5: Commit the implementation**

```bash
git add website/src/app website/src/components/marketing/marketing-page.tsx
git commit -m "fix: restore complete root marketing page"
```

### Task 3: Verify the static release output

**Files:**
- Verify generated output only; do not commit `website/out/`.

**Step 1: Run all website checks**

Run:

```bash
cd website
npm test
npm run typecheck
npm run lint
npm run build
```

Expected: all commands pass and the static export completes.

**Step 2: Inspect the root export**

Confirm `website/out/index.html` contains `class="marketing-page"`, the Chinese hero heading, and three Android download actions.

**Step 3: Review the final diff and repository status**

Ensure only the plan, tests, route composition, and stylesheet import location changed; generated output remains untracked or ignored.
