# PhotoTend Marketing Motion Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the static Hero mock with an interactive gesture demo, refine the SD import illustration, and improve waitlist form spacing without adding heavy media or animation dependencies.

**Architecture:** Build a client-side Hero demo using Pointer Events and a small deterministic state machine, rendered with semantic HTML, inline SVG, and CSS transforms. Keep the SD illustration server-rendered as an accessible decorative SVG. Restrict form work to markup grouping and responsive CSS so submission behavior remains unchanged.

**Tech Stack:** Next.js App Router, React, TypeScript, CSS, inline SVG, Vitest, Testing Library, Playwright.

---

### Task 1: Interactive Hero gesture demo

**Files:**
- Create: `website/src/components/marketing/hero-demo.tsx`
- Test: `website/src/components/marketing/hero-demo.test.tsx`
- Modify: `website/src/components/marketing/hero.tsx`
- Modify: `website/src/styles/marketing.css`

**Step 1: Write failing component tests**

Test that the demo exposes a localized interaction label, renders multiple photo states, uses a pointer-draggable surface,
and provides an `aria-live` status for left, up, and down actions.

**Step 2: Verify failure**

Run: `cd website && npm test -- hero-demo.test.tsx`

Expected: fail because `HeroDemo` does not exist.

**Step 3: Implement the state machine**

Create three photo scenes and action states `idle`, `next`, `trash`, and `undo`. Use Pointer Events,
direction locking, a 56px completion threshold, and delayed auto-play. Never animate layout properties.

**Step 4: Add reduced-motion behavior**

Use `matchMedia("(prefers-reduced-motion: reduce)")` to disable timers and transition classes.

**Step 5: Verify**

Run: `cd website && npm test -- hero-demo.test.tsx && npm run typecheck`

Expected: pass.

### Task 2: Refined SD import illustration

**Files:**
- Create: `website/src/components/marketing/sd-import-visual.tsx`
- Test: `website/src/components/marketing/sd-import-visual.test.tsx`
- Modify: `website/src/components/marketing/import-story.tsx`
- Modify: `website/src/styles/marketing.css`

**Step 1: Write a failing SVG structure test**

Require an SVG title, SD card outline, contact group, transfer path, and at least two traveling photo thumbnails.

**Step 2: Verify failure**

Run: `cd website && npm test -- sd-import-visual.test.tsx`

Expected: fail because the component does not exist.

**Step 3: Implement the illustration**

Draw the card with a clipped-corner path and detailed contacts. Add thumbnail groups that move along the transfer path
using transform and opacity only. Replace the old `SD` rectangle in `ImportStory`.

**Step 4: Verify**

Run: `cd website && npm test -- sd-import-visual.test.tsx`

Expected: pass.

### Task 3: Form spacing and responsive layout

**Files:**
- Modify: `website/src/components/waitlist/waitlist-form.tsx`
- Modify: `website/src/components/waitlist/waitlist-form.test.tsx`
- Modify: `website/src/styles/marketing.css`
- Modify: `website/e2e/responsive.spec.ts`

**Step 1: Write failing form structure assertions**

Require dedicated field groups for identity, preferences, consent, and submit/privacy actions.

**Step 2: Verify failure**

Run: `cd website && npm test -- waitlist-form.test.tsx`

Expected: fail because the grouping hooks are absent.

**Step 3: Group existing controls and adjust CSS**

Add semantic classes without changing field names or submission behavior. Increase vertical rhythm,
make consent a padded click target, and switch platform options to one column on narrow screens.

**Step 4: Verify**

Run: `cd website && npm test -- waitlist-form.test.tsx`

Expected: pass.

### Task 4: Browser interaction and quality gate

**Files:**
- Create: `website/e2e/hero-interaction.spec.ts`
- Modify: files implicated by failures only

**Step 1: Add browser behavior checks**

Verify the Hero status changes after a pointer drag and stays static with reduced motion.

**Step 2: Run focused browser checks**

Run: `cd website && npm run test:e2e -- hero-interaction.spec.ts responsive.spec.ts accessibility.spec.ts`

Expected: pass on Chromium.

**Step 3: Run full gate**

Run:

```bash
cd website
npm test
npm run typecheck
npm run lint
npm run build
npm run test:e2e
```

Expected: all pass.

**Step 4: Commit**

```bash
git add docs/plans website
git commit -m "feat: add interactive marketing visuals"
```

