# Admin Web — Phase 5 (Jobs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans. Checkbox steps.

**Goal:** Build `/jobs` (paginated list + status filter) and `/jobs/[id]` (facts card + **live moderation**: reopen/close/cancel).

**Architecture:** Both Server Components. List reads `searchParams` (`status`, `page`) → `getJobsPage()` (URL-driven server pagination, 50/page); a client `JobFilters` pushes URL changes, a `Paginator` does prev/next. Detail calls `getJobDetail(id)` (a single-job fetch — unlike Flutter which passed the row via routing, we fetch so the URL is deep-linkable). Moderation = a client card calling the `setJobStatus` Server Action over the live `admin_set_job_status` RPC (`revalidatePath`). Zero backend changes. **Server/client split + Phosphor `/dist/ssr` in server components** (the P3/P4 lessons) applied up front.

**Tech Stack:** Next 16, `@supabase/ssr` server client, Phosphor icons, Tailwind v4 (P0 tokens), P0 primitives (Card/KVRow/Button/StatusTag/EmptyState). Working dir `/Users/kuya/Documents/Jobdun/admin-web`.

---

## Ported facts (both recons agree)

**List** (`getJobsPage({status, page})`, 50/page): `jobs.select("id, title, status, application_count, created_at, profiles!jobs_builder_id_fkey(display_name)")` + (status≠"all" ? `.eq("status", status)`) + `.order("created_at", desc).range(offset, offset+49)`. Builder name fallback `"—"`. `hasMore = rows.length === 50`.

**Detail** (`getJobDetail(id)`): same select `.eq("id", id).maybeSingle()` → one `JobRow`. (Flutter's detail didn't fetch; we do, for deep-linkable URLs.)

**Status enum**: `draft|open|filled|closed|cancelled`. Filter chips: `ALL / DRAFT / OPEN / FILLED / CLOSED / CANCELLED`.

**Moderation (LIVE)**: `admin_set_job_status(p_job_id, p_status)`. Button rules (DOWN = {closed, cancelled}): if status ∈ DOWN → **REOPEN** (primary → "open"); if status ∉ DOWN → **CLOSE** (secondary → "closed"); if status ≠ "cancelled" → **CANCEL** (danger → "cancelled").

**UI**: status pill — `open` → `bg-action text-on-action`, else `bg-surface-raised text-text1`, label uppercased. Row: title (`t-title-md`) + `{builder} · {n} applicant(s)` (`t-body-sm text-text2`) + status pill + created date (right). Empty "No jobs match." / "Try a different status filter." Error "COULDN'T LOAD JOBS". Detail: back "BACK TO JOBS", title (`t-headline-sm`), status pill, facts card "JOB" (Builder / Applicants / Lifecycle / Created), moderation card "MODERATION" ("Listing: {STATUS}" tag + the buttons). Row-level placeholder tags omitted (micro-noise). Tokens only; em-dash-free prose.

---

## File structure

| File | Responsibility |
|---|---|
| `lib/data/jobs.ts` | Pure types + `JOB_FILTERS` + `JOBS_PAGE_SIZE` (client-safe). |
| `lib/data/jobs-queries.ts` | `server-only`: `getJobsPage`, `getJobDetail`. |
| `lib/actions/jobs.ts` | `"use server"`: `setJobStatus`. |
| `components/admin/jobs/job-status-pill.tsx` | Status pill (server-safe). |
| `components/admin/jobs/job-filters.tsx` · `job-row.tsx` · `paginator.tsx` | List bits. |
| `components/admin/jobs/job-facts-card.tsx` · `job-moderation-card.tsx` | Detail cards. |
| `app/(admin)/jobs/page.tsx` · `app/(admin)/jobs/[id]/page.tsx` | The two routes. |

> **Orchestration:** Stage A (sequential) = Tasks 1–2 (data + queries + action + status pill). Stage B (2 parallel) = list (Task 3) ∥ detail (Task 4). Stage C = integrate + verify (authed Playwright vs the real jobs) + deploy.

---

## Task 1: Data — types (client-safe) + server queries

- [ ] **`lib/data/jobs.ts`**

```ts
export type JobStatus = "draft" | "open" | "filled" | "closed" | "cancelled";
export type JobStatusFilter = "all" | JobStatus;

export type JobRow = {
  id: string; title: string; status: JobStatus;
  builderDisplayName: string; applicationCount: number; createdAt: string;
};

export const JOB_FILTERS: { value: JobStatusFilter; label: string }[] = [
  { value: "all", label: "ALL" },
  { value: "draft", label: "DRAFT" },
  { value: "open", label: "OPEN" },
  { value: "filled", label: "FILLED" },
  { value: "closed", label: "CLOSED" },
  { value: "cancelled", label: "CANCELLED" },
];
export const JOB_STATUSES: JobStatus[] = ["draft", "open", "filled", "closed", "cancelled"];
export const JOBS_PAGE_SIZE = 50;
```

- [ ] **`lib/data/jobs-queries.ts`**

```ts
import "server-only";
import { createClient } from "@/lib/supabase/server";
import { JOBS_PAGE_SIZE, type JobRow, type JobStatus, type JobStatusFilter } from "./jobs";

const SELECT = "id, title, status, application_count, created_at, profiles!jobs_builder_id_fkey(display_name)";
type Row = Record<string, unknown> & { profiles?: { display_name?: string | null } | null };

function toRow(r: Row): JobRow {
  const name = r.profiles?.display_name?.trim();
  return {
    id: String(r.id),
    title: String(r.title ?? ""),
    status: (r.status as JobStatus) ?? "draft",
    builderDisplayName: name && name.length > 0 ? name : "—",
    applicationCount: Number(r.application_count ?? 0),
    createdAt: String(r.created_at),
  };
}

export async function getJobsPage(params: {
  status: JobStatusFilter; page: number;
}): Promise<{ rows: JobRow[]; hasMore: boolean }> {
  const supabase = await createClient();
  const page = Math.max(1, params.page);
  const offset = (page - 1) * JOBS_PAGE_SIZE;
  let q = supabase.from("jobs").select(SELECT);
  if (params.status !== "all") q = q.eq("status", params.status);
  const { data, error } = await q
    .order("created_at", { ascending: false })
    .range(offset, offset + JOBS_PAGE_SIZE - 1);
  if (error || !data) return { rows: [], hasMore: false };
  return { rows: (data as Row[]).map(toRow), hasMore: data.length === JOBS_PAGE_SIZE };
}

export async function getJobDetail(jobId: string): Promise<JobRow | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("jobs").select(SELECT).eq("id", jobId).maybeSingle();
  if (error || !data) return null;
  return toRow(data as Row);
}
```

- [ ] Create both files.

---

## Task 2: Action + status pill

- [ ] **`lib/actions/jobs.ts`**

```ts
"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { JobStatus } from "@/lib/data/jobs";

export async function setJobStatus(input: {
  jobId: string; status: JobStatus;
}): Promise<{ error?: string }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_job_status", {
    p_job_id: input.jobId,
    p_status: input.status,
  });
  if (error) return { error: error.message.includes("not_admin") ? "You are not authorised." : error.message };
  revalidatePath(`/jobs/${input.jobId}`);
  revalidatePath("/jobs");
  return {};
}
```

- [ ] **`components/admin/jobs/job-status-pill.tsx`** (server-safe — no `"use client"`, no icons)

```tsx
import { cn } from "@/lib/utils";
import type { JobStatus } from "@/lib/data/jobs";

export function JobStatusPill({ status }: { status: JobStatus }) {
  return (
    <span
      className={cn(
        "inline-block rounded-badge px-2 py-0.5 t-eyebrow",
        status === "open" ? "bg-action text-on-action" : "bg-surface-raised text-text1",
      )}
    >
      {status.toUpperCase()}
    </span>
  );
}
```

- [ ] Verify: `npm run build` compiles.

---

## Task 3: The list  *(Stage B — agent #1)*

**Files:** `job-filters.tsx`, `job-row.tsx`, `paginator.tsx`, `app/(admin)/jobs/page.tsx`.

- [ ] **`job-filters.tsx`** (`"use client"`): status chips from `JOB_FILTERS` (active `bg-action text-on-action`, idle `bg-surface-raised text-text1 hover:brightness-110`, `rounded-full px-3.5 py-2 t-eyebrow`). Reads `status` from `useSearchParams`; on chip click `useRouter().push("/jobs?" + new URLSearchParams(status==="all"?{}:{status}))` (drop `page`). No search box (jobs filter by status only).

- [ ] **`job-row.tsx`** (server component — import any icon from `@phosphor-icons/react/dist/ssr`): `<Link href={\`/jobs/${row.id}\`}>` styled `flex items-start justify-between gap-3 rounded-card border border-border bg-surface px-4 py-3.5 transition-jobdun hover:border-border-strong`: left column { title `t-title-md text-text1 truncate`; `{builderDisplayName} · {applicationCount} {applicationCount===1?"applicant":"applicants"}` `t-body-sm text-text2` } + right column (items-end) { `<JobStatusPill status={row.status}/>`; created date `t-body-sm text-text3` (`fmtDate` = "d MMM yyyy") }.

- [ ] **`paginator.tsx`** (jobs-scoped, mirrors the users paginator but for `/jobs` preserving `status`): prev/next; prev disabled at page 1, next disabled when `!hasMore`; enabled = P0 `Button variant="secondary" size="sm"` as a `<Link>`, disabled = a styled span (`buttonVariants` secondary + `opacity-50 cursor-not-allowed`); `CaretLeft`/`CaretRight` from `@phosphor-icons/react/dist/ssr` if this stays a server component (no hooks) — it does. "Page {page}" centered.

- [ ] **`app/(admin)/jobs/page.tsx`** (Server Component):

```tsx
import { getJobsPage } from "@/lib/data/jobs-queries";
import type { JobStatusFilter } from "@/lib/data/jobs";
import { JOB_STATUSES } from "@/lib/data/jobs";
import { JobFilters } from "@/components/admin/jobs/job-filters";
import { JobRow } from "@/components/admin/jobs/job-row";
import { Paginator } from "@/components/admin/jobs/paginator";
import { EmptyState } from "@/components/ui/empty-state";
import { Briefcase } from "@phosphor-icons/react/dist/ssr";

export const dynamic = "force-dynamic";

export default async function JobsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string }>;
}) {
  const sp = await searchParams;
  const status = ((["all", ...JOB_STATUSES].includes(sp.status ?? "")) ? sp.status : "all") as JobStatusFilter;
  const page = Math.max(1, Number(sp.page) || 1);
  const { rows, hasMore } = await getJobsPage({ status, page });

  return (
    <div className="flex flex-col gap-6">
      <JobFilters status={status} />
      {rows.length === 0 ? (
        <EmptyState icon={Briefcase} headline="No jobs match." hint="Try a different status filter." />
      ) : (
        <>
          <div className="flex flex-col gap-2">
            {rows.map((r) => (
              <JobRow key={r.id} row={r} />
            ))}
          </div>
          <Paginator status={status} page={page} hasMore={hasMore} />
        </>
      )}
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/jobs/page.tsx" components/admin/jobs/{job-filters,job-row,paginator}.tsx`. NO commit, NO build. Tokens only; **server components import Phosphor from `/dist/ssr`**, client (`job-filters`) from the root.

---

## Task 4: The detail  *(Stage B — agent #2)*

**Files:** `job-facts-card.tsx`, `job-moderation-card.tsx`, `app/(admin)/jobs/[id]/page.tsx`.

- [ ] **`job-facts-card.tsx`** (server): P0 `Card` + eyebrow "JOB" (`t-eyebrow text-text3 mb-3`) + `KVRow`s: Builder (`builderDisplayName`), Applicants (`String(applicationCount)`), Lifecycle (`status`), Created (`fmtDate(createdAt)`).

- [ ] **`job-moderation-card.tsx`** (`"use client"`): P0 `Card` + eyebrow "MODERATION" + a status line "Listing:" + `<JobStatusPill status={status}/>`. Buttons in a `useTransition` (DOWN = `["closed","cancelled"]`): `status` ∈ DOWN → REOPEN (`Button` primary → `setJobStatus({jobId, status:"open"})`); `status` ∉ DOWN → CLOSE (`Button variant="secondary"` → "closed"); `status` ≠ "cancelled" → CANCEL (`Button variant="danger"` → "cancelled"). All disabled while pending; error shown `t-body-sm text-urgent-tx`; success refreshes via `revalidatePath`. Phosphor icon values (`ArrowCounterClockwise`, `XCircle`, `Prohibit`) from `@phosphor-icons/react` (client).

- [ ] **`app/(admin)/jobs/[id]/page.tsx`** (Server Component):

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "@phosphor-icons/react/dist/ssr";
import { getJobDetail } from "@/lib/data/jobs-queries";
import { JobStatusPill } from "@/components/admin/jobs/job-status-pill";
import { JobFactsCard } from "@/components/admin/jobs/job-facts-card";
import { JobModerationCard } from "@/components/admin/jobs/job-moderation-card";

export const dynamic = "force-dynamic";

export default async function JobDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const job = await getJobDetail(id);
  if (!job) notFound();

  return (
    <div className="flex flex-col gap-4">
      <Link href="/jobs" className="inline-flex w-fit items-center gap-2 rounded-btn px-2 py-1.5 t-eyebrow text-text2 hover:text-text1">
        <ArrowLeft size={16} aria-hidden /> BACK TO JOBS
      </Link>
      <div className="flex flex-col gap-3">
        <h2 className="t-headline-sm text-text1">{job.title}</h2>
        <div><JobStatusPill status={job.status} /></div>
      </div>
      <JobFactsCard job={job} />
      <JobModerationCard jobId={job.id} status={job.status} />
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/jobs/[id]" components/admin/jobs/job-facts-card.tsx components/admin/jobs/job-moderation-card.tsx`. NO commit, NO build. Tokens only; em-dash-free; reuse P0 `Card`/`KVRow`/`Button` + `JobStatusPill`.

---

## Task 5: Integrate, verify, deploy  *(Stage C)*

- [ ] Commit Stage B grouped (list; detail). `npm run test && npm run lint && npm run build` green; `/jobs` + `/jobs/[id]` are `ƒ`. Token audit over `lib/data/jobs.ts lib/data/jobs-queries.ts lib/actions/jobs.ts components/admin/jobs "app/(admin)/jobs"` = none.
- [ ] **Live verify vs the real jobs** (2 open jobs exist): authed Playwright — log in, screenshot `/jobs`, open the first row → screenshot `/jobs/[id]` (facts + moderation buttons). Read screenshots; do NOT click CLOSE/CANCEL (no prod mutations). Revert any throwaway script.
- [ ] Commit, push, `vercel deploy --prod`. Live gate holds.

---

## Done-When
- `/jobs` lists the real jobs (status chips + 50/page prev-next), each row links to detail; `/jobs/[id]` shows the facts card + a **working** moderation card (reopen/close/cancel via `admin_set_job_status`).
- Build/lint/test green; token-pure; verified vs the real jobs; deployed.
