# Admin Web → Next.js Migration — Design Spec

> **Date:** 2026-06-24
> **Status:** Draft for review
> **Author:** Brainstormed via `superpowers:brainstorming` + `ui-ux-pro-max`
> **Supersedes nothing.** This is a frontend re-platform of the existing Flutter admin console.

---

## 1. Goal

Re-platform the Jobdun **admin console** from its current Flutter Web entrypoint
(`lib/admin/`, ~8,200 LOC / 85 files, live on Cloudflare Pages) to a new
**Next.js** application in a sibling folder, matching the conventions already
established by the `marketing-site/` migration.

The admin console is a **gated, functional, stateful** app (auth, role gate,
Supabase reads/writes, audited RPC mutations) — unlike the static marketing
site. So the migration is a true app port, not a content port. SEO is irrelevant
here (the console is `noindex` and access-gated); the motivation is a single
modern React web stack, escape from Flutter Web's heavy CanvasKit bundle, and
better maintainability.

**Hard constraint: zero backend changes.** Same Supabase project, same tables,
same RPCs, same storage buckets, same `custom_access_token_hook`. This is purely
a new frontend talking to the unchanged backend, which de-risks the whole effort.

---

## 2. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Host + auth** | **Vercel + SSR-protected** (`@supabase/ssr` + middleware) | Matches marketing-site host; server-validated sessions (no client flash); idiomatic Next.js. |
| **Placeholders** | **Port them too** | Full visual parity with today's console (payments, suspend/ban, job hide/remove rendered as disabled roadmap surfaces). |
| **Typography** | **Unify to Archivo / Inter** | Match marketing site + mobile app; reuse marketing-site's `next/font` pipeline + `.t-*` classes. CLAUDE.md flags admin's Oswald/Open Sans as temporary. |
| **Component primitives** | **shadcn/ui (Radix), reskinned to Jobdun tokens** | Accessible dialogs/dropdowns/tables/focus-management out of the box for an interaction-heavy console; faster than hand-rolling. |

---

## 3. Architecture

### 3.1 Stack

Clone the `marketing-site/` baseline into a new **`admin-web/`** folder:

- **Next.js 16** (App Router) · **React 19.2** · **Tailwind v4** (CSS-first
  `@theme`) · **TypeScript 5** · `@/*` path alias · flat ESLint 9 · security
  headers via `next.config.ts`.
- **Dark-only.** The admin is dark-only today; we hardcode `<html class="dark">`
  and skip the `next-themes` toggle the marketing site has. Tokens still come
  from the same `@theme` block.

**Added dependencies** (not in marketing-site):

| Package | Purpose | Replaces (Flutter) |
|---|---|---|
| `@supabase/supabase-js` | Supabase client | `supabase_flutter` |
| `@supabase/ssr` | Cookie-based SSR auth | localStorage session |
| `@phosphor-icons/react` | Icons (already used by marketing-site) | `AppIcons` / `phosphor_flutter` |
| `react-hook-form` + `zod` + `@hookform/resolvers` | Forms + validation | `flutter_form_builder` + `form_builder_validators` |
| `@tanstack/react-table` | Headless dense data tables | `infinite_scroll_pagination` lists |
| `react-zoom-pan-pinch` | Zoom/pan in the doc viewer | `photo_view` |
| shadcn/ui (Radix primitives) | dialog, dropdown-menu, select, tabs, tooltip, toast | dialogs / `showJSheet` / Material |

> Library choices (esp. `@supabase/ssr` middleware pattern and shadcn/Tailwind-v4
> wiring) get verified against current docs via **context7 / the `supabase` skill**
> at implementation time, per CLAUDE.md.

### 3.2 Auth — SSR gate

The existing `custom_access_token_hook` injects a **`user_role`** claim into the
JWT. We rely on it exactly as the Flutter app does.

- `lib/supabase/server.ts` — `createServerClient` bound to Next cookies (Server
  Components + Server Actions).
- `lib/supabase/client.ts` — `createBrowserClient` (minimal client-component use).
- `lib/supabase/middleware.ts` — `updateSession()` (token refresh helper).
- `middleware.ts` (root) — runs `updateSession`, decodes the `user_role` claim,
  and gates the `(admin)` route group:
  - not authenticated **or** `user_role != 'admin'` → redirect to `/login`
    (and sign out non-admins, mirroring the Flutter `NotAdminException` path).
  - authenticated admin at `/login` → redirect to `/`.
  - Server-validated, so there is **no client-side redirect flash** (an
    improvement over the Flutter SPA).
- `lib/auth.ts` — `getAdminSession()` server helper returning `{ userId, email }`
  or `null` (the React equivalent of `AdminSession` / `AdminSessionService`).

**Login** and **every mutation** run as **Server Actions** — no bespoke API
routes. Sign-in calls `signInWithPassword`, verifies the role claim, sets
cookies, redirects.

### 3.3 Data layer

- **Reads**: async **Server Components** query Supabase directly (RLS-enforced).
  Lists are **URL-driven server pagination** (`?page=&role=&status=&q=&filter=`),
  page size **50** to match the Flutter app. Signed URLs for the verification doc
  viewer are minted **server-side** (60s expiry, same as today).
- **Writes**: **Server Actions** call the **existing RPCs** unchanged. The server
  Supabase client carries the admin's JWT via cookies (anon key + admin role —
  the same auth path the Flutter app uses), so RLS + `SECURITY DEFINER` gating is
  identical.

**Backend surface reused as-is (no changes):**

- Tables: `profiles`, `builder_profiles`, `trade_profiles`, `user_roles`,
  `user_role_events`, `verification_documents`, `verifications`,
  `verification_events`, `jobs`.
- RPCs: `review_verification_document`, `revoke_verification`,
  `admin_view_verification_raw`, `admin_broadcast`, `admin_set_job_status`,
  `admin_set_user_status`.
  - `admin_set_user_status` / `admin_set_job_status` are listed for
    completeness but **remain unwired** in this migration — user/job moderation
    is a disabled placeholder today (Flutter Phase 2), and we port the
    placeholder, not a live control.
- Storage: `private-docs` (signed-URL doc reads).

### 3.4 Design tokens & typography

- Copy marketing-site's `app/globals.css` `@theme` block (Jobdun tokens already
  ported 1:1 — `--background #0F172A`, `--surface #1E293B`,
  `--surface-raised #334155`, `--action #F97316`, `--text1/2/3`, status pairs,
  etc.). Keep the **dark** values as the only theme.
- Reuse the `.t-display-*`, `.t-headline-*`, `.t-title-*`, `.t-body-*`, `.t-label`,
  `.t-eyebrow` classes, loaded from **Archivo + Inter** via `next/font`.
- **shadcn reskin**: map shadcn's theme CSS variables (`--primary`,
  `--background`, `--card`, `--border`, `--destructive`, `--ring`, …) onto the
  Jobdun tokens so every Radix component renders dark-slate + safety-orange with
  zero per-component overrides. Orange foregrounds are **dark `on-action`**,
  never white (WCAG — white-on-orange is 2.8:1).

### 3.5 Folder & deploy structure

- Build as **`admin-web/`** (sibling to `marketing-site/`) during development.
- **Deploy (decided)**: its own **standalone Git repo** (mirroring marketing-site,
  on the personal `KpG782` account where Vercel/GitHub live) + its own **Vercel
  project**, served at **`admin.jobdun.com.au`**, `noindex` robots, security
  headers in `next.config.ts`. The standalone repo + Vercel project + DNS are
  created at **P8** (or whenever we first push code) — there is nothing to push
  during the early build phases, so the build phases stay host-agnostic.
- The admin's "second lock" on Vercel is the **SSR middleware admin gate + RLS**
  (the Cloudflare Zero Trust Access plan was CF-specific). Vercel deployment
  protection is an optional paid extra, noted but not required.

---

## 4. Route & component map (Flutter → Next.js)

### Routes (App Router)

| Path | File | Source (Flutter) |
|---|---|---|
| `/login` | `app/login/page.tsx` | `admin_login_page.dart` |
| `/` | `app/(admin)/page.tsx` | `admin_dashboard_page.dart` |
| `/verifications` | `app/(admin)/verifications/page.tsx` | `admin_verifications_page.dart` |
| `/users` | `app/(admin)/users/page.tsx` | `admin_users_page.dart` |
| `/users/[id]` | `app/(admin)/users/[id]/page.tsx` | `admin_user_detail_page.dart` |
| `/jobs` | `app/(admin)/jobs/page.tsx` | `admin_jobs_page.dart` |
| `/jobs/[id]` | `app/(admin)/jobs/[id]/page.tsx` | `admin_job_detail_page.dart` |
| `/audit` | `app/(admin)/audit/page.tsx` | `admin_audit_page.dart` |
| `/broadcast` | `app/(admin)/broadcast/page.tsx` | `admin_broadcast_page.dart` |
| `/payments` | `app/(admin)/payments/page.tsx` | `admin_payments_page.dart` (placeholder) |

`app/(admin)/layout.tsx` = the AdminShell (sidebar + topbar) + a server-side
session guard.

### Primitives (`components/ui/` — shadcn reskinned) + custom

- shadcn: `button`, `card`, `input`, `label`, `badge`, `dialog`, `dropdown-menu`,
  `select`, `tabs`, `tooltip`, `table`, `skeleton`, `sonner` (toast).
- Custom (`components/admin/`): `Sidebar`, `Topbar`, `Breadcrumbs`, `StatTile`,
  `StatusTag`, `FilterChips`, `Paginator`, `KVRow`, `EmptyState`, `ErrorState`,
  `DocViewer` (Dialog + `react-zoom-pan-pinch`), `AdminBrand`, `RoadmapCard` /
  `PlaceholderStat` / `PlaceholderAction` (for the locked surfaces).

---

## 5. Phase plan

Each phase is one **reviewable vertical slice**, ending green on lint + tests +
axe. Each gets its own implementation plan from `superpowers:writing-plans`.

### P0 — Foundation
- Scaffold `admin-web/` from the marketing-site baseline (configs, ESLint,
  PostCSS, `tsconfig` `@/*`, security headers, Vitest + Playwright/axe harness).
- Port `globals.css` tokens (dark-only) + Archivo/Inter via `next/font`.
- Initialise shadcn/ui; wire its theme variables to Jobdun tokens.
- Build base primitives: `Button` (incl. `danger`), `Card`, `Field`, `StatusTag`,
  `Skeleton`, `EmptyState`, `ErrorState`, `KVRow`, `cn()`.
- **Done when**: app boots, a primitives demo route renders on-brand, axe clean.

### P1 — Auth + SSR gate + app shell
- `@supabase/ssr` server/client/middleware; root `middleware.ts` role gate;
  `lib/auth.ts`.
- `/login`: split-brand layout, email/password (`react-hook-form` + `zod`),
  sign-in Server Action, non-admin sign-out + error (`role="alert"`).
- AdminShell `(admin)/layout.tsx`: collapsible sidebar (240/72, auto-collapse
  <1024px), topbar (title + actions), breadcrumbs, session email, sign-out
  Server Action.
- **Done when**: non-admin/anon bounce to `/login` server-side; admin reaches an
  empty shell; sign-out works; no redirect flash.

### P2 — Dashboard
- `/` Server Component: 4 live stat tiles (total users, pending verifications,
  open jobs, rejected 7d), quick-nav grid, refresh.
- Placeholder "coming soon" stat tiles (ported).
- **Done when**: live stats match the Flutter dashboard for the same data.

### P3 — Verifications (heaviest)
- `/verifications`: chip filters (All / Trade Licence / Builder ABN / White Card /
  Pub Liability), pending (oldest-first) vs reviewed (newest-first, capped 50),
  triage sort; the 3-source projection (`verification_documents` + `user_roles` +
  `verifications`) done server-side.
- Review **Dialog**: zoomable signed-URL doc viewer (`react-zoom-pan-pinch`),
  claim metadata, captured-details card, regulator failure reason, official
  state-register links, confirm fields (number + trade class), notes,
  Approve/Reject + Revoke + raw-payload view — each a Server Action over the
  existing RPCs.
- **Done when**: a doc can be approved/rejected/revoked end-to-end against the
  real backend; audit rows appear.

### P4 — Users
- `/users`: server-paginated list (50/page), role filter (All/Builder/Trade/Admin),
  search; rows.
- `/users/[id]`: header, profile card, role-gated builder/trade subprofile,
  verifications card, moderation card (suspend/ban rendered per current state —
  disabled placeholder, since live moderation is Phase-2 in Flutter).
- **Done when**: list paginates + filters + searches; detail renders all cards.

### P5 — Jobs
- `/jobs`: server-paginated list, status filter (All/Open/Filled/Archived).
- `/jobs/[id]`: facts card + moderation placeholder. Read-only, matching current
  Flutter behaviour: the Hide/Remove controls are disabled placeholders and the
  `admin_set_job_status` RPC stays unwired in this migration.
- **Done when**: list paginates + filters; detail renders.

### P6 — Audit + Broadcast
- `/audit`: server-paginated merged log (`verification_events` +
  `user_role_events`), newest-first, payload preview.
- `/broadcast`: composer (audience selector, title/message with char limits, live
  preview card, confirm Dialog, send → `admin_broadcast` Server Action, success
  toast with recipient count, reset).
- **Done when**: a broadcast sends and returns a recipient count; audit lists.

### P7 — Placeholders + a11y polish
- `/payments` + all locked roadmap surfaces (disabled actions, lock icons,
  phase tags) for full parity.
- Cross-cutting a11y (from `ui-ux-pro-max`): keyboard nav, **skip-to-main** link,
  visible **focus rings**, `prefers-reduced-motion`, status = **icon + text**
  (never colour-alone), **aria-labels** on icon-only buttons, table overflow →
  horizontal scroll wrapper, errors via `role="alert"`/`aria-live`. Loading
  skeletons + empty/error states on every list. Responsive at 768/1024/1440.
- **Done when**: axe = 0 violations across all routes; keyboard-only walkthrough
  passes.

### P8 — Parity check + deploy
- Side-by-side parity review vs the Flutter console (screenshots per screen).
- Green: `eslint`, `vitest`, axe, `next build`.
- Create the standalone repo (`KpG782`) + Vercel project; deploy to
  **`admin.jobdun.com.au`** (env vars `NEXT_PUBLIC_SUPABASE_URL` /
  `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `noindex`, security headers, DNS).
- Optional: retire the Flutter-admin Cloudflare deploy after cutover.
- **Done when**: deployed admin signs in, gates correctly, and matches the
  Flutter console feature-for-feature.

---

## 6. Cross-cutting concerns

- **Accessibility** (WCAG 2.2 AA, non-negotiable per MASTER): 4.5:1 text contrast,
  3:1 UI/borders, focus visible, keyboard-complete, never colour-alone, dark
  `on-action` on orange. Radix gives focus traps + keyboard for free; we verify
  with axe each phase.
- **Testing**: Vitest (unit/component), Playwright + axe (a11y), manual parity
  screenshots. Mirror marketing-site's `__tests__/` + `e2e/` layout.
- **Performance**: Server Components keep client JS small; signed URLs and list
  queries server-side; immutable caching headers for static assets (mirror
  marketing-site `_headers`/`next.config`).
- **Security**: `noindex`; admin gate in middleware; RLS unchanged; never expose
  the service-role key (anon key only, like the Flutter app).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `@supabase/ssr` middleware/token-refresh edge cases (login loops) | Follow the canonical Next.js `@supabase/ssr` middleware pattern; verify via context7/`supabase` skill; test the anon→login→admin→signout cycle in P1. |
| RPCs depend on auth context | Server client carries the admin JWT via cookies — same anon-key + admin-role path the Flutter app already uses; verify each RPC in its phase. |
| shadcn reskin drifts from Jobdun brand | Drive all shadcn theme vars from the single Jobdun `@theme`; run the MASTER pre-delivery checklist + axe per phase. |
| Scope creep (8k LOC) | Strict vertical-slice phases; placeholders are visual-only; no new features beyond parity. |
| Deploy logistics (personal vs org Vercel/GitHub) | Defer the repo-split decision to P8; build phases are host-agnostic. |

---

## 8. Out of scope / deferred

- No changes to the mobile app, Supabase schema, RPCs, or storage.
- No **new** admin capabilities beyond current parity. (Bulk multi-select on
  moderation queues — flagged by `ui-ux-pro-max` — is an **optional future
  enhancement**, explicitly deferred.)
- Cloudflare Zero Trust Access (CF-specific; replaced by the Vercel SSR gate).
- Retiring the Flutter `lib/admin/` source is deferred until after the new
  console is verified in production (P8+).

---

## 9. Resolved decisions (was: open questions)

1. **Repo**: a **standalone Git repo** (like marketing-site, on `KpG782`) — not a
   monorepo folder. Created at P8.
2. **URL**: **`admin.jobdun.com.au`** (its own Vercel project + DNS, set at P8).
