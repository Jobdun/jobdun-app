# Admin Web — Phase 6 (Audit log + Broadcast) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps.

**Goal:** `/audit` (a merged, paginated security-event feed) and `/broadcast` (a composer that sends a push + in-app notification to an audience via the existing RPC).

**Architecture:** Two independent verticals. **Audit** = a Server Component reading `?page=` → `getAuditPage()` (over-fetch both event tables, merge + sort in memory, slice 50/page). **Broadcast** = a Server Component rendering a client `BroadcastComposer` (form + live preview + confirm Dialog) whose SEND calls the `sendBroadcast` Server Action over `admin_broadcast`. Zero backend changes. Server/client split + Phosphor-`/dist/ssr`-in-server-components applied up front (P3/P4 lessons).

**Tech Stack:** Next 16, `@supabase/ssr`, react-hook-form + zod (broadcast), shadcn Dialog (confirm), Phosphor, Tailwind v4 (P0 tokens). Working dir `/Users/kuya/Documents/Jobdun/admin-web`.

> **Orchestration:** the two verticals are fully independent (distinct files, no shared new module). Build them as 2 parallel agents (Task A = audit ∥ Task B = broadcast); then I integrate + verify + deploy. No Stage A needed.

---

## VERTICAL A — Audit log

### Ported facts
Two reads, over-fetched then merged in memory:
- `verification_events`: `.select("id, event_type, actor_id, raw_response, created_at, verifications!inner(user_id)").order("created_at", {ascending:false}).limit(offset + 50)`.
- `user_role_events`: `.select("id, user_id, old_role, new_role, changed_by, reason, created_at").order("created_at", {ascending:false}).limit(offset + 50)`.
Project → `AuditEvent`, concat, sort by `occurredAt` desc, slice `[offset, offset+50]`. `hasMore = slice.length === 50`.
- verification event: `id="v:"+id`, `source="verification"`, `eventType = event_type ?? "verif.event"`, `actorId = actor_id`, `targetUserId = verifications.user_id`, `payloadPreview = cap(JSON.stringify(raw_response) or raw_response string, 120)`.
- role event: `id="r:"+id`, `source="role"`, `eventType = "role.{old_role ?? '?'}→{new_role}"`, `actorId = changed_by`, `targetUserId = user_id`, `payloadPreview = reason`.
Row: source pill (VERIF → `bg-available-bg text-available-tx`, ROLE → `bg-surface-raised text-text2`) + event type uppercase + `actor {8}… · target {8}…` (`—` when null) + payload preview (1 line) + timestamp right (`d MMM yyyy · HH:mm`, **Australia/Sydney**). Empty: shield icon "No audit events yet." / "Security events appear here as they happen."

### Task A1: data
- [ ] **`lib/data/audit.ts`** (client-safe)

```ts
export type AuditSource = "verification" | "role";
export type AuditEvent = {
  id: string; occurredAt: string; source: AuditSource; eventType: string;
  actorId: string | null; targetUserId: string | null; payloadPreview: string | null;
};
export const AUDIT_PAGE_SIZE = 50;
```

- [ ] **`lib/data/audit-queries.ts`** (`server-only`)

```ts
import "server-only";
import { createClient } from "@/lib/supabase/server";
import { AUDIT_PAGE_SIZE, type AuditEvent } from "./audit";

const cap = (s: string) => (s.length > 120 ? `${s.slice(0, 120)}…` : s);

export async function getAuditPage(params: { page: number }): Promise<{ events: AuditEvent[]; hasMore: boolean }> {
  const supabase = await createClient();
  const page = Math.max(1, params.page);
  const offset = (page - 1) * AUDIT_PAGE_SIZE;
  const upper = offset + AUDIT_PAGE_SIZE; // over-fetch from each table

  const [vRes, rRes] = await Promise.all([
    supabase.from("verification_events").select("id, event_type, actor_id, raw_response, created_at, verifications!inner(user_id)").order("created_at", { ascending: false }).limit(upper),
    supabase.from("user_role_events").select("id, user_id, old_role, new_role, changed_by, reason, created_at").order("created_at", { ascending: false }).limit(upper),
  ]);

  const events: AuditEvent[] = [];
  for (const r of (vRes.data ?? []) as Record<string, unknown>[]) {
    const raw = r.raw_response;
    const preview = raw && typeof raw === "object" ? cap(JSON.stringify(raw)) : typeof raw === "string" ? cap(raw) : null;
    const verif = r.verifications as { user_id?: string } | { user_id?: string }[] | null | undefined;
    const userId = Array.isArray(verif) ? verif[0]?.user_id : verif?.user_id;
    events.push({
      id: `v:${r.id}`, occurredAt: String(r.created_at), source: "verification",
      eventType: String(r.event_type ?? "verif.event"),
      actorId: r.actor_id ? String(r.actor_id) : null,
      targetUserId: userId ?? null, payloadPreview: preview,
    });
  }
  for (const r of (rRes.data ?? []) as Record<string, unknown>[]) {
    events.push({
      id: `r:${r.id}`, occurredAt: String(r.created_at), source: "role",
      eventType: `role.${r.old_role ?? "?"}→${r.new_role}`,
      actorId: r.changed_by ? String(r.changed_by) : null,
      targetUserId: r.user_id ? String(r.user_id) : null,
      payloadPreview: r.reason ? cap(String(r.reason)) : null,
    });
  }
  events.sort((a, b) => (a.occurredAt < b.occurredAt ? 1 : -1));
  const slice = events.slice(offset, offset + AUDIT_PAGE_SIZE);
  return { events: slice, hasMore: slice.length === AUDIT_PAGE_SIZE };
}
```

### Task A2: row + paginator + page
- [ ] **`components/admin/audit/audit-row.tsx`** (server): `flex items-start gap-3 rounded-card border border-border bg-surface px-4 py-3.5`: a source pill (`rounded-badge px-2 py-0.5 t-eyebrow`, verification → `bg-available-bg text-available-tx` label "VERIF", role → `bg-surface-raised text-text2` label "ROLE") + a flex-1 column { event type `t-eyebrow text-text1` (uppercased); `actor {actorId?.slice(0,8) ?? "—"}… · target {targetUserId?.slice(0,8) ?? "—"}…` `t-body-sm text-text2`; payloadPreview ? `truncate t-body-sm text-text3` } + timestamp right `shrink-0 t-body-sm text-text2` via `new Intl.DateTimeFormat("en-AU", { timeZone: "Australia/Sydney", day:"numeric", month:"short", year:"numeric", hour:"2-digit", minute:"2-digit", hour12:false })` → "d MMM yyyy · HH:mm" (use the formatted parts joined with " · " between date and time).
- [ ] **`components/admin/audit/paginator.tsx`** (server): prev/next on `?page=` (no other params); prev disabled at page 1, next disabled when `!hasMore`; enabled = P0 `Button variant="secondary" size="sm"` `<Link>`, disabled = styled span; `CaretLeft`/`CaretRight` from `/dist/ssr`; "Page {page}".
- [ ] **`app/(admin)/audit/page.tsx`** (Server Component):

```tsx
import { getAuditPage } from "@/lib/data/audit-queries";
import { AuditRow } from "@/components/admin/audit/audit-row";
import { Paginator } from "@/components/admin/audit/paginator";
import { EmptyState } from "@/components/ui/empty-state";
import { ShieldCheck } from "@phosphor-icons/react/dist/ssr";

export const dynamic = "force-dynamic";

export default async function AuditPage({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  const sp = await searchParams;
  const page = Math.max(1, Number(sp.page) || 1);
  const { events, hasMore } = await getAuditPage({ page });
  return (
    <div className="flex flex-col gap-6">
      {events.length === 0 ? (
        <EmptyState icon={ShieldCheck} headline="No audit events yet." hint="Security events appear here as they happen." />
      ) : (
        <>
          <div className="flex flex-col gap-2">{events.map((e) => <AuditRow key={e.id} event={e} />)}</div>
          <Paginator page={page} hasMore={hasMore} />
        </>
      )}
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/audit" components/admin/audit/{audit-row,paginator}.tsx`. Tokens only; server-component Phosphor from `/dist/ssr`. NO commit, NO build.

---

## VERTICAL B — Broadcast

### Ported facts
RPC `admin_broadcast(p_title text, p_body text, p_audience text, p_data jsonb='{}') → integer` (recipient count). Audience token: `all`/`builders`/`trades`/ or the typed profile UUID (for "single"). Composer: heading is the topbar title; description "Send a push and in-app update to your users. Everyone in the audience receives it instantly."; AUDIENCE (ALL USERS / ALL BUILDERS / ALL TRADES / SINGLE USER); SINGLE USER → a USER ID field (placeholder "profile id (uuid)", required "Enter the recipient profile id."); TITLE (≤80, required "A title is required.", placeholder "e.g. New verification flow is live"); MESSAGE (≤240, 4 rows, required "A message is required.", placeholder "What do you want users to know?"); live PREVIEW card (bell + "NEW FROM JOBDUN" eyebrow + title or "Notification title" + body or "Your message will appear here."); SEND BROADCAST → confirm Dialog ("Send this broadcast?" / "This sends a push and in-app notification to {AUDIENCE_LABEL}. It cannot be unsent." + the quoted title + CANCEL/SEND); success "Sent to N recipient(s)." + reset form.

### Task B1: data + action
- [ ] **`lib/data/broadcast.ts`** (client-safe)

```ts
export type Audience = "all" | "builders" | "trades" | "single";
export const AUDIENCES: { value: Audience; label: string }[] = [
  { value: "all", label: "ALL USERS" },
  { value: "builders", label: "ALL BUILDERS" },
  { value: "trades", label: "ALL TRADES" },
  { value: "single", label: "SINGLE USER" },
];
export const audienceLabel = (a: Audience) => AUDIENCES.find((x) => x.value === a)?.label ?? "ALL USERS";
```

- [ ] **`lib/actions/broadcast.ts`** (`"use server"`)

```ts
"use server";
import { createClient } from "@/lib/supabase/server";
import type { Audience } from "@/lib/data/broadcast";

export async function sendBroadcast(input: {
  title: string; body: string; audience: Audience; userId?: string;
}): Promise<{ count?: number; error?: string }> {
  const supabase = await createClient();
  // For "single" the RPC audience token IS the typed profile UUID; else the value.
  const p_audience = input.audience === "single" ? (input.userId ?? "").trim() : input.audience;
  const { data, error } = await supabase.rpc("admin_broadcast", {
    p_title: input.title.trim(), p_body: input.body.trim(), p_audience, p_data: {},
  });
  if (error) return { error: error.message.includes("not_admin") ? "You are not authorised." : error.message };
  return { count: Number(data ?? 0) };
}
```

### Task B2: composer + page
- [ ] **`components/admin/broadcast/broadcast-composer.tsx`** (`"use client"`): a `laptop:grid-cols-2` layout — left = the form, right = the live preview. State via `react-hook-form` + `zod` (title: min 1 "A title is required.", max 80; body: min 1 "A message is required.", max 240; userId: when audience==="single", min 1 "Enter the recipient profile id."). Audience = chips (`AUDIENCES`, active `bg-action text-on-action`, idle `bg-surface-raised text-text1`, `rounded-full t-eyebrow`) held in state; when `single`, render the USER ID `<input>` (P0 Field style). TITLE + MESSAGE inputs (Field style; MESSAGE a 4-row `<textarea>`). `watch` title/body for the preview. A description line at top. SEND BROADCAST `Button` (PaperPlaneRight icon) opens a shadcn confirm `Dialog`: title "Send this broadcast?"; body `This sends a push and in-app notification to {audienceLabel(audience)}. It cannot be unsent.`; the quoted title; CANCEL (secondary) + SEND (primary). On SEND → `sendBroadcast(...)` in a `useTransition`; on `{count}` show inline success `Sent to {count} recipient{count===1?"":"s"}.` (`t-body-md text-verified-tx`) + `reset()` the form + audience to "all"; on `{error}` show inline `t-body-sm text-urgent-tx`. **Preview card**: `rounded-card border border-border bg-surface-raised p-4`: a 7×7 `rounded-chip bg-action-bg` square holding a `Bell` (`text-action-ink`), "NEW FROM JOBDUN" (`t-eyebrow text-text2`), then the title (`t-title-md text-text1`, or "Notification title" `text-text3`) and body (`t-body-md text-text2`, or "Your message will appear here." `text-text3`). Phosphor icon values (`PaperPlaneRight`, `Bell`) from `@phosphor-icons/react` (client). Em-dash-free prose.
- [ ] **`app/(admin)/broadcast/page.tsx`** (Server Component):

```tsx
import { BroadcastComposer } from "@/components/admin/broadcast/broadcast-composer";

export const dynamic = "force-dynamic";

export default function BroadcastPage() {
  return (
    <div className="flex flex-col gap-2">
      <p className="max-w-2xl t-body-md text-text2">
        Send a push and in-app update to your users. Everyone in the audience receives it instantly.
      </p>
      <BroadcastComposer />
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/broadcast" components/admin/broadcast/broadcast-composer.tsx`. Tokens only; em-dash-free; client Phosphor from root. NO commit, NO build.

---

## Integration, verify, deploy  *(me)*

- [ ] Commit grouped (audit; broadcast). `npm run test && npm run lint && npm run build` green; `/audit` + `/broadcast` are `ƒ`. Token audit over the new files = none.
- [ ] **Live verify** (authed Playwright): `/audit` (real events feed) + `/broadcast` (the composer) screenshots. **Do NOT click SEND/confirm** on broadcast — it fans a real push to all users. Read screenshots; revert throwaway script.
- [ ] Commit, push, `vercel deploy --prod`. Live gate holds.

## Done-When
- `/audit` shows the merged event feed (source pills, actor/target, payload preview, Sydney timestamps, prev/next); `/broadcast` renders the composer + live preview + confirm dialog (verified, not fired). Build/lint/test green; token-pure; deployed.
