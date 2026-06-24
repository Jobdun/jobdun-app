# Admin Web — Phase 2 (Dashboard) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans. Checkbox steps.

**Goal:** Replace the temporary primitives showcase at `/` with the real admin dashboard — hero, 4 live stat tiles fetched in a Server Component through the gate, a "coming soon" placeholder strip, and a quick-nav grid.

**Architecture:** `app/(admin)/page.tsx` becomes an async Server Component. It calls `getDashboardStats()` (server, RLS-gated counts via the cookie session — zero backend changes, no RPC, no service-role key) and renders the stats + nav. A small client `RefreshButton` calls `router.refresh()`. `force-dynamic` keeps counts fresh.

**Tech Stack:** Next 16 App Router (Server Components + a client refresh), `@supabase/ssr` server client, Tailwind v4 (P0 tokens), `@phosphor-icons/react`. Working dir: `/Users/kuya/Documents/Jobdun/admin-web`.

---

## Ported facts (authoritative)

**Data — 4 RLS-gated count queries** (`select('*', { count: 'exact', head: true })`), run in parallel, each falling back to `null` on error → rendered as "—":
- **Total Users**: `profiles` (no filter).
- **Pending Verifications**: `verification_documents` `.eq('status','pending').is('deleted_at', null)`.
- **Open Jobs**: `jobs` `.eq('status','open')`.
- **Rejected (7d)**: `verification_documents` `.eq('status','rejected').gte('reviewed_at', <now-7d ISO, UTC>)`.

**UI** (from the Flutter dashboard recon): hero **"WELCOME, ADMIN."** + subhead; 4 stat tiles — `TOTAL USERS` ("Builders + Trades"), `PENDING VERIFICATIONS` (**highlighted** orange, "Awaiting review"), `OPEN JOBS` ("Across all builders"), `REJECTED (7D)` ("Verifications rejected this week"); a **COMING SOON** strip of 4 muted placeholder tiles (VERIFICATION QUEUE DEPTH·PHASE 2, OPEN REPORTS·PHASE 2, SUSPENDED USERS·PHASE 2, ACTIVE SUBSCRIPTIONS·PHASE 3); a quick-nav grid of 4 cards (VERIFICATION QUEUE→/verifications, USERS→/users, JOBS→/jobs, AUDIT LOG→/audit). Tokens only; `.t-*` type; em-dashes kept out of rendered copy.

---

## Files

| File | Responsibility |
|---|---|
| `lib/data/dashboard.ts` | `getDashboardStats()` server fn (the 4 parallel counts). |
| `components/ui/stat-tile.tsx` | **Enhance** P0 StatTile: add optional `sublabel` + `highlight`. |
| `components/admin/placeholder-stat.tsx` | Muted "coming soon" tile (lock + phase + "—"). |
| `components/admin/quick-nav-card.tsx` | Nav card (icon + title + copy + OPEN→). |
| `components/admin/refresh-button.tsx` | Client `router.refresh()` button. |
| `app/(admin)/page.tsx` | **Replace** the showcase with the dashboard Server Component. |

---

## Task 1: `getDashboardStats()` data fn

**File:** Create `lib/data/dashboard.ts`.

```ts
import "server-only";
import { createClient } from "@/lib/supabase/server";

export type DashboardStats = {
  totalUsers: number | null;
  pendingVerifications: number | null;
  openJobs: number | null;
  rejectedLast7Days: number | null;
};

/** The 4 admin dashboard counts, fetched in parallel. RLS-gated (the cookie
 *  session carries the admin JWT). A failed count falls back to null → "—". */
export async function getDashboardStats(): Promise<DashboardStats> {
  const supabase = await createClient();
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const [users, pending, jobs, rejected] = await Promise.all([
    supabase.from("profiles").select("*", { count: "exact", head: true }),
    supabase
      .from("verification_documents")
      .select("*", { count: "exact", head: true })
      .eq("status", "pending")
      .is("deleted_at", null),
    supabase.from("jobs").select("*", { count: "exact", head: true }).eq("status", "open"),
    supabase
      .from("verification_documents")
      .select("*", { count: "exact", head: true })
      .eq("status", "rejected")
      .gte("reviewed_at", sevenDaysAgo),
  ]);

  return {
    totalUsers: users.error ? null : users.count,
    pendingVerifications: pending.error ? null : pending.count,
    openJobs: jobs.error ? null : jobs.count,
    rejectedLast7Days: rejected.error ? null : rejected.count,
  };
}
```

- [ ] Create the file exactly as above. (No unit test — it's a thin Supabase wrapper; verified by build + the live smoke.)

---

## Task 2: Enhance `StatTile` (sublabel + highlight)

**File:** Replace `components/ui/stat-tile.tsx`.

```tsx
import type { Icon } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

/** Dashboard metric tile. `highlight` = orange label + orange-tinted border
 *  (the one the backlog wants at zero). Value uses tabular figures. */
export function StatTile({
  label,
  value,
  sublabel,
  highlight = false,
  icon: IconCmp,
}: {
  label: string;
  value: string | number;
  sublabel?: string;
  highlight?: boolean;
  icon?: Icon;
}) {
  return (
    <div
      className={cn(
        "flex flex-col gap-2 rounded-card border bg-surface p-5",
        highlight ? "border-action/40" : "border-border",
      )}
    >
      <div className="flex items-center justify-between">
        <span className={cn("t-eyebrow", highlight ? "text-action-ink" : "text-text2")}>
          {label}
        </span>
        {IconCmp ? (
          <IconCmp size={18} weight="bold" aria-hidden className="text-text3" />
        ) : null}
      </div>
      <span className="nums t-display-md text-text1">{value}</span>
      {sublabel ? <span className="t-body-sm text-text3">{sublabel}</span> : null}
    </div>
  );
}
```

- [ ] Replace the file. The existing `__tests__/states.test.tsx` (StatTile label+value) still passes — `sublabel`/`highlight` are optional.

---

## Task 3: `PlaceholderStat`

**File:** Create `components/admin/placeholder-stat.tsx`.

```tsx
import { Lock } from "@phosphor-icons/react/dist/ssr";

/** A muted "coming soon" tile — transparent fill, lock, em-dash value. */
export function PlaceholderStat({ label, phase }: { label: string; phase: string }) {
  return (
    <div className="flex flex-col gap-2 rounded-card border border-border bg-transparent p-5">
      <div className="flex items-center justify-between">
        <span className="t-eyebrow text-text3">{label}</span>
        <Lock size={14} aria-hidden className="text-text3" />
      </div>
      <span className="nums t-display-md text-text3">—</span>
      <span className="t-eyebrow text-text3">{phase}</span>
    </div>
  );
}
```

- [ ] Create the file.

---

## Task 4: `QuickNavCard`

**File:** Create `components/admin/quick-nav-card.tsx`.

```tsx
import Link from "next/link";
import { CaretRight } from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";

export function QuickNavCard({
  icon: IconCmp,
  title,
  copy,
  href,
}: {
  icon: Icon;
  title: string;
  copy: string;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="flex flex-col gap-3 rounded-card border border-border bg-surface p-6 transition-jobdun hover:border-border-strong"
    >
      <div className="flex items-center gap-2.5">
        <IconCmp size={20} weight="bold" aria-hidden className="text-text2" />
        <span className="t-label text-text1">{title}</span>
        <span className="ml-auto inline-flex items-center gap-1 t-eyebrow text-action-ink">
          OPEN
          <CaretRight size={12} weight="bold" aria-hidden />
        </span>
      </div>
      <p className="t-body-sm text-text2">{copy}</p>
    </Link>
  );
}
```

- [ ] Create the file.

---

## Task 5: `RefreshButton` (client)

**File:** Create `components/admin/refresh-button.tsx`.

```tsx
"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowClockwise } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

/** Re-runs the dashboard Server Component (re-fetches the stats). */
export function RefreshButton() {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <button
      type="button"
      onClick={() => start(() => router.refresh())}
      disabled={pending}
      className="inline-flex h-11 items-center gap-2 rounded-btn bg-surface-raised px-4 t-label text-text1 hover:brightness-110 cursor-pointer disabled:opacity-50"
    >
      <ArrowClockwise size={16} weight="bold" aria-hidden className={cn(pending && "animate-spin")} />
      REFRESH
    </button>
  );
}
```

- [ ] Create the file.

---

## Task 6: The dashboard page

**File:** Replace `app/(admin)/page.tsx`.

```tsx
import { Users, SealCheck, Briefcase, Shield, Lock } from "@phosphor-icons/react/dist/ssr";
import { getDashboardStats } from "@/lib/data/dashboard";
import { StatTile } from "@/components/ui/stat-tile";
import { PlaceholderStat } from "@/components/admin/placeholder-stat";
import { QuickNavCard } from "@/components/admin/quick-nav-card";
import { RefreshButton } from "@/components/admin/refresh-button";

// Always fetch fresh counts (the page is dynamic via the gate's cookies anyway).
export const dynamic = "force-dynamic";

const fmt = (v: number | null) => (v === null ? "—" : v.toLocaleString("en-AU"));

const QUICK_NAV = [
  { icon: SealCheck, title: "VERIFICATION QUEUE", copy: "Review pending documents from trades and builders. Approve, reject, or revoke.", href: "/verifications" },
  { icon: Users, title: "USERS", copy: "Search profiles, inspect role history, and open user detail.", href: "/users" },
  { icon: Briefcase, title: "JOBS", copy: "Moderate reported jobs and inspect lifecycle transitions.", href: "/jobs" },
  { icon: Shield, title: "AUDIT LOG", copy: "Role changes, sign-in attempts, and other security events.", href: "/audit" },
];

const COMING_SOON = [
  { label: "VERIFICATION QUEUE DEPTH", phase: "PHASE 2" },
  { label: "OPEN REPORTS", phase: "PHASE 2" },
  { label: "SUSPENDED USERS", phase: "PHASE 2" },
  { label: "ACTIVE SUBSCRIPTIONS", phase: "PHASE 3" },
];

export default async function DashboardPage() {
  const stats = await getDashboardStats();
  return (
    <div className="flex flex-col gap-10">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="t-display-md text-text1">WELCOME, ADMIN.</h2>
          <p className="mt-2 max-w-2xl t-body-md text-text2">
            Platform health at a glance. Jump into a queue below. The verification
            backlog is the one to keep at zero.
          </p>
        </div>
        <RefreshButton />
      </header>

      <section aria-label="Platform stats" className="grid gap-4 tablet:grid-cols-2 laptop:grid-cols-4">
        <StatTile label="TOTAL USERS" value={fmt(stats.totalUsers)} sublabel="Builders + Trades" icon={Users} />
        <StatTile label="PENDING VERIFICATIONS" value={fmt(stats.pendingVerifications)} sublabel="Awaiting review" highlight icon={SealCheck} />
        <StatTile label="OPEN JOBS" value={fmt(stats.openJobs)} sublabel="Across all builders" icon={Briefcase} />
        <StatTile label="REJECTED (7D)" value={fmt(stats.rejectedLast7Days)} sublabel="Verifications rejected this week" icon={Shield} />
      </section>

      <section aria-label="Coming soon" className="flex flex-col gap-3">
        <div className="flex items-center gap-1.5">
          <Lock size={12} aria-hidden className="text-text3" />
          <span className="t-eyebrow text-text3">COMING SOON</span>
        </div>
        <div className="grid gap-4 tablet:grid-cols-2 laptop:grid-cols-4">
          {COMING_SOON.map((c) => (
            <PlaceholderStat key={c.label} label={c.label} phase={c.phase} />
          ))}
        </div>
      </section>

      <section aria-label="Quick navigation" className="grid gap-4 laptop:grid-cols-2">
        {QUICK_NAV.map((n) => (
          <QuickNavCard key={n.title} icon={n.icon} title={n.title} copy={n.copy} href={n.href} />
        ))}
      </section>
    </div>
  );
}
```

- [ ] Replace the file (this deletes the temporary showcase). The shell layout already provides `<main>` + padding, so this returns a plain `<div>`.

---

## Task 7: Verify + deploy

- [ ] `npm run test && npm run lint && npm run build` — all green; `/` stays `ƒ` (dynamic). Token audit (`grep` for hex / generic-palette / arbitrary-color in `lib/data components/admin components/ui/stat-tile.tsx app/(admin)`) = none.
- [ ] Layout check: temporary preview (same harness pattern — a throwaway unguarded route rendering the page + a middleware bypass, REVERTED before commit) screenshot at 375 + 1280; unauth RLS returns null counts so tiles show "—", which confirms layout/styling. (Real numbers need an admin login — the user verifies.)
- [ ] Commit, push, `vercel deploy --prod`. Live: `/login` 200, anon `/`→307→`/login` still holds.

---

## Done-When
- `/` renders the dashboard (hero + 4 tiles with PENDING highlighted + COMING SOON strip + quick-nav), counts fetched server-side through the gate.
- Refresh re-runs the server fetch. Build/lint/test green; token-pure; deployed.
- A signed-in admin sees real counts; the temporary showcase is gone.
