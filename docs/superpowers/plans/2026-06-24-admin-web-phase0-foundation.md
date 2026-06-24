# Admin Web — Phase 0 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the `admin-web/` Next.js app from the `marketing-site/` baseline (dark-only), wire the Jobdun design tokens + a shadcn/Radix-ready theme pipeline, and ship the base brand primitives, all verified green on lint + tests + axe.

**Architecture:** A new sibling folder `admin-web/` mirrors `marketing-site/`'s Next 16 / React 19.2 / Tailwind v4 / TS setup. It is its own standalone git repo (`git init`, gitignored from the Jobdun monorepo, matching how `marketing-site/` is structured) — the GitHub remote + first push happen later (Phase 8). Tokens come from the marketing-site `globals.css` `@theme` block, trimmed to **dark-only** and extended with shadcn's CSS-variable aliases so `shadcn add` in later phases renders on-brand. P0 hand-authors the simple atoms (Button/Card/Field/StatusTag/state primitives); the Radix-heavy components (Dialog/DropdownMenu/Select/Table) are pulled via `shadcn add` in later phases where their accessibility earns its keep.

**Tech Stack:** Next.js 16 (App Router), React 19.2, Tailwind v4 (CSS-first `@theme`), TypeScript 5, `class-variance-authority` + `clsx` + `tailwind-merge` (cn), `@phosphor-icons/react`, Vitest + Testing Library + jsdom, Playwright + `@axe-core/playwright`.

**Reference spec:** `docs/superpowers/specs/2026-06-24-admin-web-nextjs-migration-design.md`
**Baseline to mirror:** `/Users/kuya/Documents/Jobdun/marketing-site/`

---

## File Structure (what P0 creates, all under `admin-web/`)

| File | Responsibility |
|---|---|
| `package.json` | Deps + scripts (dev/build/lint/test/axe). |
| `next.config.ts` | Security headers (copied from marketing-site). |
| `tsconfig.json` | TS config + `@/*` alias (copied). |
| `postcss.config.mjs` | Tailwind v4 PostCSS plugin (copied). |
| `eslint.config.mjs` | Flat ESLint (copied). |
| `.gitignore` | Next/node ignores for the standalone repo. |
| `vitest.config.ts` / `vitest.setup.ts` | Component test harness (copied). |
| `app/globals.css` | Jobdun dark tokens + `.t-*` ramp + shadcn alias vars. |
| `app/layout.tsx` | Dark `<html>`, Archivo/Inter fonts, `noindex`. |
| `app/page.tsx` | **Temporary** kitchen-sink demo of all primitives (replaced by the dashboard in P2). |
| `lib/utils.ts` | `cn()` (clsx + tailwind-merge) — shadcn-compatible. |
| `components.json` | shadcn CLI config (infra for later phases). |
| `components/ui/button.tsx` | Button: primary / secondary / danger; sizes sm/md/lg/icon; link-or-button. |
| `components/ui/card.tsx` | Card surface + header/title/content subcomponents. |
| `components/ui/field.tsx` | Label + Input + error (`role="alert"`). |
| `components/ui/status-tag.tsx` | Semantic status chip (icon + uppercase label). |
| `components/ui/skeleton.tsx` | Pulse placeholder on `surface-raised`. |
| `components/ui/empty-state.tsx` | Icon + headline + hint + optional CTA. |
| `components/ui/error-state.tsx` | `role="alert"` title + message + retry. |
| `components/ui/kv-row.tsx` | Label/value row. |
| `components/ui/stat-tile.tsx` | Metric tile (tabular-nums value). |
| `e2e/axe.mjs` | axe-core a11y runner over running routes. |
| `__tests__/*.test.tsx` | Component tests (TDD). |

> **Working directory:** every command below runs from `/Users/kuya/Documents/Jobdun/admin-web` unless stated otherwise. `marketing-site/` is the sibling at `../marketing-site`.

---

## Task 1: Scaffold the app + boot

**Files:**
- Create: `admin-web/package.json`, `next.config.ts`, `tsconfig.json`, `postcss.config.mjs`, `eslint.config.mjs`, `.gitignore`, `app/layout.tsx`, `app/page.tsx`, `app/globals.css` (minimal placeholder, replaced in Task 2).

- [ ] **Step 1: Create the folder and copy verbatim configs from marketing-site**

```bash
mkdir -p /Users/kuya/Documents/Jobdun/admin-web
cd /Users/kuya/Documents/Jobdun/admin-web
cp ../marketing-site/next.config.ts ./next.config.ts
cp ../marketing-site/tsconfig.json ./tsconfig.json
cp ../marketing-site/postcss.config.mjs ./postcss.config.mjs
cp ../marketing-site/eslint.config.mjs ./eslint.config.mjs
```

These four are identical to the marketing-site versions (security headers, `@/*` alias, Tailwind v4 PostCSS, flat ESLint) — no edits needed.

- [ ] **Step 2: Write `package.json`**

```json
{
  "name": "admin-web",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "test": "vitest run",
    "test:watch": "vitest",
    "axe": "node e2e/axe.mjs"
  },
  "dependencies": {
    "@phosphor-icons/react": "^2.1.10",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "next": "16.2.9",
    "react": "19.2.4",
    "react-dom": "19.2.4",
    "tailwind-merge": "^3.3.1"
  },
  "devDependencies": {
    "@axe-core/playwright": "^4.11.3",
    "@playwright/test": "^1.61.0",
    "@tailwindcss/postcss": "^4",
    "@testing-library/jest-dom": "^6.9.1",
    "@testing-library/react": "^16.3.2",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "@vitejs/plugin-react": "^6.0.2",
    "eslint": "^9",
    "eslint-config-next": "16.2.9",
    "jsdom": "^29.1.1",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^4.1.9"
  }
}
```

- [ ] **Step 3: Write `.gitignore`**

```gitignore
/node_modules
/.next/
/out/
/build
.DS_Store
*.pem
npm-debug.log*
.env*
!.env.example
/coverage
next-env.d.ts
.vercel
*.tsbuildinfo
/e2e/shots
```

- [ ] **Step 4: Write a minimal `app/globals.css`** (full tokens land in Task 2)

```css
@import "tailwindcss";

body {
  background-color: #0f172a;
  color: #f1f5f9;
}
```

- [ ] **Step 5: Write `app/layout.tsx`**

```tsx
import type { Metadata } from "next";
import { Archivo, Inter } from "next/font/google";
import "./globals.css";

/** Archivo — display / headings / buttons. */
const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
  display: "swap",
  weight: ["400", "500", "600", "700", "800"],
});

/** Inter — body / UI / captions. */
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: { default: "Jobdun Admin", template: "%s · Jobdun Admin" },
  description: "Jobdun admin console.",
  // The console is access-gated — never index it.
  robots: { index: false, follow: false },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en-AU"
      className={`${archivo.variable} ${inter.variable} h-full dark`}
    >
      <body className="min-h-full bg-background text-text1 antialiased">
        {children}
      </body>
    </html>
  );
}
```

- [ ] **Step 6: Write a placeholder `app/page.tsx`**

```tsx
export default function Home() {
  return (
    <main className="p-8">
      <h1 className="t-display-md">Jobdun Admin — Foundation</h1>
    </main>
  );
}
```

- [ ] **Step 7: Install dependencies**

Run: `npm install`
Expected: completes without peer-dependency errors; `node_modules/` + `package-lock.json` created.

- [ ] **Step 8: Verify the build boots**

Run: `npm run build`
Expected: `✓ Compiled successfully`; route `/` listed as a static page; exit 0.

- [ ] **Step 9: Initialise the standalone git repo + commit**

```bash
cd /Users/kuya/Documents/Jobdun/admin-web
git init
git add -A
git commit -m "chore: scaffold admin-web Next.js app from marketing-site baseline"
```

- [ ] **Step 10: Ignore `admin-web/` from the Jobdun monorepo**

```bash
cd /Users/kuya/Documents/Jobdun
printf '\n# Nested standalone admin console (own repo, deployed separately)\n/admin-web/\n' >> .gitignore
git add .gitignore
git commit -m "chore: gitignore nested admin-web repo"
```

Run: `git -C /Users/kuya/Documents/Jobdun status --short`
Expected: `admin-web/` does NOT appear (ignored); working tree clean.

---

## Task 2: Design tokens + typography

**Files:**
- Modify: `admin-web/app/globals.css` (replace the placeholder with the full dark-only token system + shadcn aliases).

- [ ] **Step 1: Write the full `app/globals.css`**

Dark-only (no `.light`, no next-themes variant). Jobdun tokens + `.t-*` ramp ported 1:1 from marketing-site, plus a `--danger`/`--on-danger` pair (AA-safe red for danger buttons) and the shadcn alias variables.

```css
@import "tailwindcss";

/* ============================================================================
   Jobdun admin design tokens (Tailwind v4, CSS-first @theme). Dark-only.
   Ported 1:1 from marketing-site/app/globals.css (which ported the Flutter app
   lib/app/theme/*). Light theme + next-themes dropped — the console is dark-only.
   Extended with: a danger-button pair, and shadcn CSS-variable aliases so
   `shadcn add` components render on-brand in later phases.
   ========================================================================== */
:root {
  --background: #0f172a;
  --surface: #1e293b;
  --surface-raised: #334155;
  --border: #334155;
  --border-strong: #708096;
  --text1: #f1f5f9;
  --text2: #94a3b8;
  --text3: #8b98ab;
  --action: #f97316;
  --action-pressed: #ea6c0a;
  --action-bg: #431407;
  --action-tx: #fed7aa;
  --action-ink: #f97316;
  --on-action: #0f172a;
  --verified: #22c55e;
  --verified-bg: #052e16;
  --verified-tx: #86efac;
  --urgent: #ef4444;
  --urgent-bg: #450a0a;
  --urgent-tx: #fca5a5;
  --available: #3b82f6;
  --available-bg: #1e3a5f;
  --available-tx: #93c5fd;
  --warning: #f59e0b;
  --warning-bg: #451a03;
  --warning-tx: #fcd34d;
  --star: #f59e0b;

  /* Danger BUTTON fill — deeper red so white ink clears WCAG AA (≈5.4:1).
     Status text/icons still use the --urgent / --urgent-tx pair above. */
  --danger: #b91c1c;
  --on-danger: #f8fafc;

  /* ---- shadcn/ui aliases → Jobdun tokens (consumed by `shadcn add`) ---- */
  --radius: 0.375rem; /* 6px — the btn/input band */
  --foreground: var(--text1);
  --card: var(--surface);
  --card-foreground: var(--text1);
  --popover: var(--surface);
  --popover-foreground: var(--text1);
  --primary: var(--action);
  --primary-foreground: var(--on-action);
  --secondary: var(--surface-raised);
  --secondary-foreground: var(--text1);
  --muted: var(--surface-raised);
  --muted-foreground: var(--text2);
  --accent: var(--surface-raised);
  --accent-foreground: var(--text1);
  --destructive: var(--danger);
  --destructive-foreground: var(--on-danger);
  --input: var(--border);
  --ring: var(--action);

  color-scheme: dark;
}

@theme inline {
  /* Jobdun colours → utilities (bg-background, text-text1, border-border-strong …) */
  --color-background: var(--background);
  --color-surface: var(--surface);
  --color-surface-raised: var(--surface-raised);
  --color-border: var(--border);
  --color-border-strong: var(--border-strong);
  --color-text1: var(--text1);
  --color-text2: var(--text2);
  --color-text3: var(--text3);
  --color-action: var(--action);
  --color-action-pressed: var(--action-pressed);
  --color-action-bg: var(--action-bg);
  --color-action-tx: var(--action-tx);
  --color-action-ink: var(--action-ink);
  --color-on-action: var(--on-action);
  --color-verified: var(--verified);
  --color-verified-bg: var(--verified-bg);
  --color-verified-tx: var(--verified-tx);
  --color-urgent: var(--urgent);
  --color-urgent-bg: var(--urgent-bg);
  --color-urgent-tx: var(--urgent-tx);
  --color-available: var(--available);
  --color-available-bg: var(--available-bg);
  --color-available-tx: var(--available-tx);
  --color-warning: var(--warning);
  --color-warning-bg: var(--warning-bg);
  --color-warning-tx: var(--warning-tx);
  --color-star: var(--star);
  --color-danger: var(--danger);
  --color-on-danger: var(--on-danger);

  /* shadcn colour utilities (bg-card, text-muted-foreground, ring-ring …) */
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-input: var(--input);
  --color-ring: var(--ring);

  /* Fonts (wired in app/layout.tsx via next/font) */
  --font-display: var(--font-archivo), "Archivo", system-ui, sans-serif;
  --font-body: var(--font-inter), "Inter", system-ui, sans-serif;

  /* Radii — sharp band only. */
  --radius-badge: 4px;
  --radius-chip: 6px;
  --radius-btn: 6px;
  --radius-input: 6px;
  --radius-card: 8px;

  /* Motion — fast, no bounce/spring. */
  --ease-jobdun: cubic-bezier(0.33, 1, 0.68, 1);

  /* Breakpoints mirror the rest of Jobdun web. */
  --breakpoint-tablet: 768px;
  --breakpoint-laptop: 960px;
  --breakpoint-desktop: 1200px;
}

/* ============================================================================ Base */
@layer base {
  html {
    -webkit-text-size-adjust: 100%;
  }
  body {
    background-color: var(--background);
    color: var(--text1);
    font-family: var(--font-body);
    -webkit-font-smoothing: antialiased;
    text-rendering: optimizeLegibility;
  }
  ::selection {
    background-color: var(--action);
    color: var(--on-action);
  }
  /* Visible keyboard focus — orange ring, never removed. */
  :focus-visible {
    outline: 2px solid var(--action);
    outline-offset: 2px;
    border-radius: 2px;
  }
  @media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
      animation-duration: 0.001ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.001ms !important;
    }
  }
}

/* ============================================================================ Type ramp */
@layer components {
  .t-display-lg {
    font-family: var(--font-display);
    font-weight: 800;
    font-size: clamp(2.5rem, 1.6rem + 3.8vw, 4.5rem);
    line-height: 1.04;
    letter-spacing: -0.02em;
  }
  .t-display-md {
    font-family: var(--font-display);
    font-weight: 800;
    font-size: clamp(2rem, 1.4rem + 2.6vw, 3.25rem);
    line-height: 1.06;
    letter-spacing: -0.015em;
  }
  .t-headline-lg {
    font-family: var(--font-display);
    font-weight: 800;
    font-size: clamp(1.75rem, 1.3rem + 1.9vw, 2.5rem);
    line-height: 1.12;
    letter-spacing: -0.01em;
  }
  .t-headline-md {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(1.4rem, 1.15rem + 1vw, 1.75rem);
    line-height: 1.2;
  }
  .t-headline-sm {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.375rem;
    line-height: 1.25;
  }
  .t-title-lg {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.125rem;
    line-height: 1.3;
  }
  .t-title-md {
    font-family: var(--font-body);
    font-weight: 600;
    font-size: 1rem;
    line-height: 1.5;
  }
  .t-body-lg {
    font-family: var(--font-body);
    font-weight: 400;
    font-size: 1rem;
    line-height: 1.6;
  }
  .t-body-md {
    font-family: var(--font-body);
    font-weight: 400;
    font-size: 0.875rem;
    line-height: 1.6;
  }
  .t-body-sm {
    font-family: var(--font-body);
    font-weight: 500;
    font-size: 0.75rem;
    line-height: 1.45;
  }
  .t-label {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.875rem;
    line-height: 1.1;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  .t-eyebrow {
    font-family: var(--font-body);
    font-weight: 700;
    font-size: 0.75rem;
    line-height: 1.2;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }
  .nums {
    font-variant-numeric: tabular-nums;
    font-feature-settings: "tnum";
  }
}

/* ============================================================================ Utilities */
@layer utilities {
  .transition-jobdun {
    transition-timing-function: var(--ease-jobdun);
    transition-duration: 180ms;
  }
}
```

- [ ] **Step 2: Verify tokens compile and render**

Run: `npm run build`
Expected: build succeeds (no unknown-utility errors from Tailwind).

- [ ] **Step 3: Visual smoke check**

Run: `npm run dev`, open `http://localhost:3000`.
Expected: dark slate `#0F172A` background, off-white `#F1F5F9` Archivo heading "Jobdun Admin — Foundation". Stop the server.

- [ ] **Step 4: Commit**

```bash
git add app/globals.css
git commit -m "feat: dark-only Jobdun design tokens + type ramp + shadcn aliases"
```

---

## Task 3: Test + axe harness

**Files:**
- Create: `admin-web/vitest.config.ts`, `vitest.setup.ts`, `e2e/axe.mjs`, `__tests__/smoke.test.tsx`.

- [ ] **Step 1: Copy the Vitest harness from marketing-site**

```bash
cp ../marketing-site/vitest.config.ts ./vitest.config.ts
cp ../marketing-site/vitest.setup.ts ./vitest.setup.ts
```

`vitest.config.ts` (for reference — identical to source): jsdom env, globals on, `setupFiles: ["./vitest.setup.ts"]`, `include: ["__tests__/**/*.test.{ts,tsx}"]`, `@` alias → repo root. `vitest.setup.ts` imports `@testing-library/jest-dom/vitest`.

- [ ] **Step 2: Write a failing smoke test**

`__tests__/smoke.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import Home from "@/app/page";

test("home renders the foundation heading", () => {
  render(<Home />);
  expect(
    screen.getByRole("heading", { name: /jobdun admin/i }),
  ).toBeInTheDocument();
});
```

- [ ] **Step 3: Run it — expect PASS** (the placeholder `app/page.tsx` already renders that heading)

Run: `npm run test`
Expected: 1 passed. (If it fails on module resolution, the `@` alias in `vitest.config.ts` is misconfigured — fix before continuing.)

- [ ] **Step 4: Write the axe runner `e2e/axe.mjs`**

```js
// Runs axe-core against the listed routes of a RUNNING server.
// Usage: start the app (npm run dev OR npm run build && npm start), then `npm run axe`.
import { chromium } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const BASE = process.env.AXE_BASE_URL ?? "http://localhost:3000";
const ROUTES = (process.env.AXE_ROUTES ?? "/").split(",");

const browser = await chromium.launch();
const page = await browser.newPage();
let total = 0;

for (const route of ROUTES) {
  await page.goto(`${BASE}${route}`, { waitUntil: "networkidle" });
  const { violations } = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
    .analyze();
  if (violations.length === 0) {
    console.log(`✓ ${route} — 0 violations`);
  } else {
    total += violations.length;
    console.error(`✗ ${route} — ${violations.length} violation(s):`);
    for (const v of violations) {
      console.error(`  [${v.impact}] ${v.id}: ${v.help}`);
    }
  }
}

await browser.close();
if (total > 0) {
  console.error(`\naxe: ${total} total violation(s)`);
  process.exit(1);
}
console.log("\naxe: clean");
```

- [ ] **Step 5: Install the Playwright Chromium binary**

Run: `npx playwright install chromium`
Expected: Chromium downloaded.

- [ ] **Step 6: Verify axe runs clean on the placeholder page**

Run (two terminals, or background the server):
```bash
npm run build && (npm start &) && sleep 4 && npm run axe ; kill %1 2>/dev/null
```
Expected: `✓ / — 0 violations` then `axe: clean`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add vitest.config.ts vitest.setup.ts __tests__/smoke.test.tsx e2e/axe.mjs
git commit -m "test: vitest + testing-library + axe harness"
```

---

## Task 4: shadcn pipeline (cn + components.json)

**Files:**
- Create: `admin-web/lib/utils.ts`, `admin-web/components.json`.

- [ ] **Step 1: Write `lib/utils.ts` (cn — shadcn-compatible)**

```ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/** Merge class names with Tailwind conflict resolution (shadcn convention). */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
```

- [ ] **Step 2: Write `components.json` (shadcn CLI config for later phases)**

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "iconLibrary": "lucide",
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
```

> Note: `iconLibrary` is `lucide` (a valid shadcn value) so `shadcn add` works in later phases. When a pulled component imports a `lucide-react` icon, swap it for the Phosphor equivalent during the reskin (Jobdun uses Phosphor). No shadcn components are pulled in P0.

- [ ] **Step 3: Add a cn unit test**

`__tests__/utils.test.ts`:

```ts
import { cn } from "@/lib/utils";

test("cn merges and dedupes tailwind classes", () => {
  expect(cn("px-2", false, "px-4")).toBe("px-4");
  expect(cn("text-text1", undefined, "font-bold")).toBe("text-text1 font-bold");
});
```

- [ ] **Step 4: Run the test — expect PASS**

Run: `npm run test`
Expected: all tests pass (2 files).

- [ ] **Step 5: Commit**

```bash
git add lib/utils.ts components.json __tests__/utils.test.ts
git commit -m "feat: cn() util + shadcn components.json pipeline"
```

---

## Task 5: Brand atoms — Button, Card, Field

**Files:**
- Create: `components/ui/button.tsx`, `card.tsx`, `field.tsx`.
- Test: `__tests__/button.test.tsx`, `__tests__/field.test.tsx`.

- [ ] **Step 1: Write the failing Button test**

`__tests__/button.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/ui/button";

test("renders a button with its label", () => {
  render(<Button>Save</Button>);
  expect(screen.getByRole("button", { name: "Save" })).toBeInTheDocument();
});

test("danger variant uses the danger fill", () => {
  render(<Button variant="danger">Delete</Button>);
  expect(screen.getByRole("button", { name: "Delete" }).className).toContain(
    "bg-danger",
  );
});

test("renders an internal link when href is set", () => {
  render(<Button href="/users">Users</Button>);
  const link = screen.getByRole("link", { name: "Users" });
  expect(link).toHaveAttribute("href", "/users");
});
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `npm run test -- button`
Expected: FAIL — `Cannot find module '@/components/ui/button'`.

- [ ] **Step 3: Write `components/ui/button.tsx`**

```tsx
import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

export const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 t-label rounded-btn select-none cursor-pointer " +
    "transition-jobdun focus-visible:outline-2 focus-visible:outline-offset-2 " +
    "focus-visible:outline-action disabled:opacity-50 disabled:pointer-events-none",
  {
    variants: {
      // No ghost/outline variants — every Jobdun button is filled (MASTER rule).
      variant: {
        primary:
          "bg-action text-on-action hover:bg-action-pressed active:bg-action-pressed",
        secondary:
          "bg-surface-raised text-text1 border border-border hover:brightness-110 active:brightness-95",
        danger:
          "bg-danger text-on-danger hover:brightness-110 active:brightness-95",
      },
      size: {
        sm: "h-9 px-3",
        md: "h-11 px-4",
        lg: "h-14 px-6",
        icon: "h-11 w-11 p-0",
      },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);

type ButtonBase = VariantProps<typeof buttonVariants> & {
  children: ReactNode;
  className?: string;
};

/** Renders a Next <Link> (internal), <a> (external), or <button>. */
export function Button(
  props: ButtonBase &
    (
      | ({ href: string } & Omit<ComponentProps<typeof Link>, "href" | "className">)
      | ({ href?: undefined } & Omit<ComponentProps<"button">, "className">)
    ),
) {
  const { variant, size, children, className, ...rest } = props;
  const classes = cn(buttonVariants({ variant, size }), className);

  if ("href" in props && props.href !== undefined) {
    const { href, ...linkRest } = rest as { href: string } & Record<string, unknown>;
    const external = /^(https?:|mailto:|tel:)/.test(href);
    if (external) {
      return (
        <a href={href} className={classes} {...(linkRest as ComponentProps<"a">)}>
          {children}
        </a>
      );
    }
    return (
      <Link href={href} className={classes} {...(linkRest as object)}>
        {children}
      </Link>
    );
  }

  return (
    <button className={classes} {...(rest as ComponentProps<"button">)}>
      {children}
    </button>
  );
}
```

- [ ] **Step 4: Run the Button test — expect PASS**

Run: `npm run test -- button`
Expected: 3 passed.

- [ ] **Step 5: Write `components/ui/card.tsx`**

```tsx
import type { ComponentProps, ReactNode } from "react";
import { cn } from "@/lib/utils";

/** Surface card — border defines the edge (no shadows, MASTER rule). */
export function Card({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      className={cn(
        "rounded-card border border-border bg-surface p-4",
        className,
      )}
      {...props}
    />
  );
}

export function CardHeader({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("mb-3 flex flex-col gap-1", className)} {...props} />;
}

export function CardTitle({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return <h3 className={cn("t-title-lg text-text1", className)}>{children}</h3>;
}

export function CardContent({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("t-body-md text-text2", className)} {...props} />;
}
```

- [ ] **Step 6: Write the failing Field test**

`__tests__/field.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { Field } from "@/components/ui/field";

test("label is associated with the input", () => {
  render(<Field label="Email" name="email" />);
  expect(screen.getByLabelText("Email")).toBeInTheDocument();
});

test("error renders in an alert region", () => {
  render(<Field label="Email" name="email" error="Required" />);
  const alert = screen.getByRole("alert");
  expect(alert).toHaveTextContent("Required");
});
```

- [ ] **Step 7: Run it — expect FAIL**

Run: `npm run test -- field`
Expected: FAIL — module not found.

- [ ] **Step 8: Write `components/ui/field.tsx`**

```tsx
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

type FieldProps = ComponentProps<"input"> & {
  label: string;
  name: string;
  error?: string;
};

/** Labelled text input on a dark surface with an orange focus border. */
export function Field({ label, name, error, className, ...props }: FieldProps) {
  const errorId = error ? `${name}-error` : undefined;
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={name} className="t-eyebrow text-text2">
        {label}
      </label>
      <input
        id={name}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={errorId}
        className={cn(
          "h-11 rounded-input border bg-surface px-4 t-body-md text-text1 " +
            "placeholder:text-text3 transition-jobdun " +
            "focus-visible:outline-none focus-visible:border-action focus-visible:ring-2 focus-visible:ring-action",
          error ? "border-urgent" : "border-border",
          className,
        )}
        {...props}
      />
      {error ? (
        <p id={errorId} role="alert" className="t-body-sm text-urgent-tx">
          {error}
        </p>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 9: Run all tests — expect PASS**

Run: `npm run test`
Expected: all pass (button 3, field 2, utils, smoke).

- [ ] **Step 10: Commit**

```bash
git add components/ui/button.tsx components/ui/card.tsx components/ui/field.tsx __tests__/button.test.tsx __tests__/field.test.tsx
git commit -m "feat: brand atoms — Button (primary/secondary/danger), Card, Field"
```

---

## Task 6: StatusTag (semantic chips)

**Files:**
- Create: `components/ui/status-tag.tsx`.
- Test: `__tests__/status-tag.test.tsx`.

- [ ] **Step 1: Write the failing test**

`__tests__/status-tag.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { StatusTag } from "@/components/ui/status-tag";

test("renders the label in uppercase-able text", () => {
  render(<StatusTag tone="verified">Approved</StatusTag>);
  expect(screen.getByText("Approved")).toBeInTheDocument();
});

test("pending tone uses the warning pair, not urgent", () => {
  render(<StatusTag tone="pending">In review</StatusTag>);
  const el = screen.getByText("In review").closest("span");
  expect(el?.className).toContain("text-warning-tx");
});

test("decorative icon is hidden from a11y tree", () => {
  const { container } = render(<StatusTag tone="rejected">Rejected</StatusTag>);
  expect(container.querySelector('svg[aria-hidden="true"]')).not.toBeNull();
});
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `npm run test -- status-tag`
Expected: FAIL — module not found.

- [ ] **Step 3: Write `components/ui/status-tag.tsx`**

Status is conveyed by icon + text, never colour alone (a11y rule). Pending/in-review = warning amber (never urgent red, never brand orange — MASTER).

```tsx
import type { ReactNode } from "react";
import {
  CheckCircle,
  Clock,
  XCircle,
  Info,
  Circle,
} from "@phosphor-icons/react/dist/ssr";
// The `Icon` TYPE is exported from the package root, NOT the /dist/ssr subpath
// (which re-exports icon component values only). Type-only import → no runtime cost.
import type { Icon } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

export type StatusTone = "neutral" | "verified" | "pending" | "rejected" | "info";

const tones: Record<StatusTone, { cls: string; Icon: Icon }> = {
  neutral: { cls: "bg-surface-raised text-text1", Icon: Circle },
  verified: { cls: "bg-verified-bg text-verified-tx", Icon: CheckCircle },
  pending: { cls: "bg-warning-bg text-warning-tx", Icon: Clock },
  rejected: { cls: "bg-urgent-bg text-urgent-tx", Icon: XCircle },
  info: { cls: "bg-available-bg text-available-tx", Icon: Info },
};

export function StatusTag({
  tone,
  children,
}: {
  tone: StatusTone;
  children: ReactNode;
}) {
  const { cls, Icon } = tones[tone];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-chip px-2 py-0.5 t-eyebrow",
        cls,
      )}
    >
      <Icon size={12} weight="fill" aria-hidden="true" />
      {children}
    </span>
  );
}
```

- [ ] **Step 4: Run the test — expect PASS**

Run: `npm run test -- status-tag`
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
git add components/ui/status-tag.tsx __tests__/status-tag.test.tsx
git commit -m "feat: StatusTag semantic chips (icon + text, AA pairs)"
```

---

## Task 7: State primitives — Skeleton, EmptyState, ErrorState, KVRow, StatTile

**Files:**
- Create: `components/ui/skeleton.tsx`, `empty-state.tsx`, `error-state.tsx`, `kv-row.tsx`, `stat-tile.tsx`.
- Test: `__tests__/states.test.tsx`.

- [ ] **Step 1: Write the failing test**

`__tests__/states.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { KVRow } from "@/components/ui/kv-row";
import { StatTile } from "@/components/ui/stat-tile";
import { Folder } from "@phosphor-icons/react/dist/ssr";

test("EmptyState shows headline and CTA", () => {
  render(
    <EmptyState
      icon={Folder}
      headline="No verifications"
      action={{ label: "Refresh", href: "/verifications" }}
    />,
  );
  expect(screen.getByText("No verifications")).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "Refresh" })).toBeInTheDocument();
});

test("ErrorState is an alert with a retry button", () => {
  const onRetry = vi.fn();
  render(<ErrorState message="Load failed" onRetry={onRetry} />);
  expect(screen.getByRole("alert")).toHaveTextContent("Load failed");
  screen.getByRole("button", { name: /retry/i }).click();
  expect(onRetry).toHaveBeenCalledOnce();
});

test("KVRow renders label and value", () => {
  render(<KVRow label="ABN" value="51 824 753 556" />);
  expect(screen.getByText("ABN")).toBeInTheDocument();
  expect(screen.getByText("51 824 753 556")).toBeInTheDocument();
});

test("StatTile renders label and value", () => {
  render(<StatTile label="Open jobs" value={42} />);
  expect(screen.getByText("Open jobs")).toBeInTheDocument();
  expect(screen.getByText("42")).toBeInTheDocument();
});
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `npm run test -- states`
Expected: FAIL — modules not found.

- [ ] **Step 3: Write `components/ui/skeleton.tsx`**

```tsx
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

/** Content-shaped loading placeholder on the raised surface. */
export function Skeleton({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      className={cn("animate-pulse rounded-chip bg-surface-raised", className)}
      {...props}
    />
  );
}
```

- [ ] **Step 4: Write `components/ui/empty-state.tsx`**

```tsx
import type { Icon } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";

type Action = { label: string; href?: string; onClick?: () => void };

export function EmptyState({
  icon: IconCmp,
  headline,
  hint,
  action,
}: {
  icon: Icon;
  headline: string;
  hint?: string;
  action?: Action;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-center">
      <IconCmp size={40} weight="bold" aria-hidden="true" className="text-text3" />
      <p className="t-title-lg text-text1">{headline}</p>
      {hint ? <p className="t-body-md max-w-sm text-text2">{hint}</p> : null}
      {action ? (
        action.href ? (
          <Button href={action.href} size="sm">
            {action.label}
          </Button>
        ) : (
          <Button size="sm" onClick={action.onClick}>
            {action.label}
          </Button>
        )
      ) : null}
    </div>
  );
}
```

- [ ] **Step 5: Write `components/ui/error-state.tsx`**

```tsx
import { Button } from "@/components/ui/button";

export function ErrorState({
  title = "Something went wrong",
  message,
  onRetry,
}: {
  title?: string;
  message: string;
  onRetry?: () => void;
}) {
  return (
    <div
      role="alert"
      className="flex flex-col items-center justify-center gap-3 py-16 text-center"
    >
      <p className="t-title-lg text-urgent-tx">{title}</p>
      <p className="t-body-md max-w-sm text-text2">{message}</p>
      {onRetry ? (
        <Button variant="secondary" size="sm" onClick={onRetry}>
          Retry
        </Button>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 6: Write `components/ui/kv-row.tsx`**

```tsx
import type { ReactNode } from "react";

/** A label/value row for detail panes (profile fields, claim metadata). */
export function KVRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-border py-2 last:border-0">
      <dt className="t-eyebrow shrink-0 text-text2">{label}</dt>
      <dd className="t-body-md text-right text-text1">{value}</dd>
    </div>
  );
}
```

- [ ] **Step 7: Write `components/ui/stat-tile.tsx`**

```tsx
import type { Icon } from "@phosphor-icons/react";

/** Dashboard metric tile — tabular-nums value. */
export function StatTile({
  label,
  value,
  icon: IconCmp,
}: {
  label: string;
  value: string | number;
  icon?: Icon;
}) {
  return (
    <div className="flex flex-col gap-2 rounded-card border border-border bg-surface p-4">
      <div className="flex items-center justify-between">
        <span className="t-eyebrow text-text2">{label}</span>
        {IconCmp ? (
          <IconCmp size={18} weight="bold" aria-hidden="true" className="text-text3" />
        ) : null}
      </div>
      <span className="nums t-display-md text-text1">{value}</span>
    </div>
  );
}
```

- [ ] **Step 8: Run all tests — expect PASS**

Run: `npm run test`
Expected: all suites pass.

- [ ] **Step 9: Commit**

```bash
git add components/ui/skeleton.tsx components/ui/empty-state.tsx components/ui/error-state.tsx components/ui/kv-row.tsx components/ui/stat-tile.tsx __tests__/states.test.tsx
git commit -m "feat: state primitives — Skeleton, EmptyState, ErrorState, KVRow, StatTile"
```

---

## Task 8: Kitchen-sink demo route + axe gate

**Files:**
- Modify: `admin-web/app/page.tsx` (replace placeholder with a primitives showcase — temporary, replaced by the dashboard in P2).

- [ ] **Step 1: Write `app/page.tsx`**

```tsx
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Field } from "@/components/ui/field";
import { StatusTag } from "@/components/ui/status-tag";
import { Skeleton } from "@/components/ui/skeleton";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { KVRow } from "@/components/ui/kv-row";
import { StatTile } from "@/components/ui/stat-tile";
import { ShieldCheck, Folder } from "@phosphor-icons/react/dist/ssr";

/**
 * TEMPORARY foundation showcase — renders every P0 primitive so we can eyeball
 * the brand reskin and run axe against real components. Deleted in P2 when the
 * real dashboard lands at `/`.
 */
export default function Home() {
  return (
    <main className="mx-auto flex max-w-5xl flex-col gap-8 p-8">
      <header className="flex flex-col gap-2">
        <span className="t-eyebrow text-action-ink">Foundation</span>
        <h1 className="t-display-md">Jobdun Admin primitives</h1>
      </header>

      <section className="flex flex-wrap gap-3" aria-label="Buttons">
        <Button>Approve</Button>
        <Button variant="secondary">Cancel</Button>
        <Button variant="danger">Revoke</Button>
        <Button size="sm">Small</Button>
        <Button size="icon" aria-label="Shield">
          <ShieldCheck size={18} weight="bold" aria-hidden="true" />
        </Button>
      </section>

      <section className="flex flex-wrap gap-2" aria-label="Status tags">
        <StatusTag tone="verified">Approved</StatusTag>
        <StatusTag tone="pending">In review</StatusTag>
        <StatusTag tone="rejected">Rejected</StatusTag>
        <StatusTag tone="info">Open</StatusTag>
        <StatusTag tone="neutral">Archived</StatusTag>
      </section>

      <section className="grid gap-4 tablet:grid-cols-3" aria-label="Stat tiles">
        <StatTile label="Total users" value={1284} icon={ShieldCheck} />
        <StatTile label="Pending verifications" value={37} />
        <StatTile label="Open jobs" value={92} />
      </section>

      <Card>
        <CardHeader>
          <CardTitle>Claim metadata</CardTitle>
        </CardHeader>
        <CardContent>
          <dl>
            <KVRow label="ABN" value="51 824 753 556" />
            <KVRow label="Entity" value="JOBDUN PTY LTD" />
            <KVRow label="GST" value="Registered" />
          </dl>
        </CardContent>
      </Card>

      <section className="grid gap-4 tablet:grid-cols-2" aria-label="Form + loading">
        <Card>
          <CardHeader>
            <CardTitle>Sign in</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col gap-4">
              <Field label="Email" name="email" type="email" placeholder="you@jobdun.com.au" />
              <Field label="Password" name="password" type="password" error="Required" />
            </div>
          </CardContent>
        </Card>
        <div className="flex flex-col gap-3">
          <Skeleton className="h-6 w-2/3" />
          <Skeleton className="h-6 w-1/2" />
          <Skeleton className="h-24 w-full" />
        </div>
      </section>

      <EmptyState
        icon={Folder}
        headline="No verifications in the queue"
        hint="When a trade or builder uploads a document, it lands here for review."
        action={{ label: "Refresh", href: "/" }}
      />

      <ErrorState message="Could not load the queue. Check your connection." />
    </main>
  );
}
```

- [ ] **Step 2: Update the smoke test for the new heading**

Replace `__tests__/smoke.test.tsx` body:

```tsx
import { render, screen } from "@testing-library/react";
import Home from "@/app/page";

test("home renders the primitives showcase heading", () => {
  render(<Home />);
  expect(
    screen.getByRole("heading", { name: /jobdun admin primitives/i }),
  ).toBeInTheDocument();
});
```

- [ ] **Step 3: Run unit tests + lint — expect PASS/clean**

Run: `npm run test && npm run lint`
Expected: all tests pass; eslint reports no errors.

- [ ] **Step 4: Build + axe the showcase**

Run:
```bash
npm run build && (npm start &) && sleep 4 && npm run axe ; kill %1 2>/dev/null
```
Expected: build succeeds; `✓ / — 0 violations`; `axe: clean`; exit 0.
If axe reports a contrast violation, the offending token pair must be fixed in `globals.css` before committing (do not suppress).

- [ ] **Step 5: Visual parity eyeball (manual)**

Run `npm run dev`, open `http://localhost:3000`. Confirm against the MASTER checklist: dark `#0F172A` background, filled orange primary with **dark** ink (not white), all-caps Archivo button labels, sharp 4–8px radii, amber (not red) "In review" tag, visible orange focus ring on Tab. Stop the server.

- [ ] **Step 6: Commit**

```bash
git add app/page.tsx __tests__/smoke.test.tsx
git commit -m "feat: foundation primitives showcase route + green axe gate"
```

---

## Phase 0 Done-When

- `npm run build` succeeds; `npm run test` all green; `npm run lint` clean; `npm run axe` = 0 violations on `/`.
- The showcase route renders every primitive on-brand (dark slate + safety orange, Archivo/Inter, dark-on-orange, amber pending, sharp radii, visible focus).
- `admin-web/` is its own git repo with the commit history above; the Jobdun monorepo ignores it.
- **Not yet:** no Supabase, no auth, no app shell, no real routes — those are P1. The showcase `/` is temporary and gets replaced by the dashboard in P2.

---

## Self-Review (against the spec's P0 row)

- **Spec P0 deliverables** — scaffold from marketing-site ✓ (T1); dark-only tokens + Archivo/Inter ✓ (T2); shadcn pipeline wired to Jobdun tokens ✓ (T2 aliases + T4 components.json); base primitives Button/danger, Card, Field, StatusTag, Skeleton, EmptyState, ErrorState, KVRow (+StatTile) ✓ (T5–T7); test + axe harness ✓ (T3); "boots + on-brand showcase + axe clean" done-when ✓ (T8).
- **Placeholder scan** — no TBD/TODO; every file has complete content; every test has real assertions. ✓
- **Type consistency** — `cn` from `@/lib/utils` used everywhere; `Button` props/variants (`primary|secondary|danger`, `sm|md|lg|icon`) consistent across atoms and the showcase; `StatusTone` union matches `tones` map; the `Icon` TYPE is imported from the `@phosphor-icons/react` root (the `/dist/ssr` subpath exports icon component values only, not the type — importing the type from there fails `tsc`/`next build` with TS2724). ✓
- **Note** — `--danger #b91c1c` is a P0-introduced token (AA-safe danger-button fill) not present in marketing-site; documented inline in `globals.css`. The Supabase deps listed in the spec's §3.1 are intentionally deferred to P1 (YAGNI for the foundation).
