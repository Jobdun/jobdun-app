# Admin Web — Phase 3 (Verifications) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans. Checkbox steps. This is the heaviest phase.

**Goal:** Build the verification review console at `/verifications` — a triage queue (chip filters + pending/reviewed sections) and a review modal (zoomable signed-URL doc viewer, claim metadata, official register links, captured-details card, regulator-failure block, confirm fields, notes) with **approve / reject / revoke** and a raw-payload viewer, all over the existing RPCs.

**Architecture:** `app/(admin)/verifications/page.tsx` is a Server Component that loads the queue via `getVerificationQueue()` (3 RLS-gated reads, projected) and hands it to a client `VerificationQueue` (chip filtering + section split + modal state). The review modal is a shadcn **Dialog**. Mutations (review/revoke) and the signed URL + raw payload are **Server Actions** over the existing RPCs (`review_verification_document`, `revoke_verification`, `admin_view_verification_raw`) — zero backend changes. Actions `revalidatePath('/verifications')`.

**Tech Stack:** Next 16 App Router, `@supabase/ssr` server client, shadcn Dialog (Radix), `react-zoom-pan-pinch` (doc zoom), Phosphor icons, Tailwind v4 (P0 tokens). Working dir `/Users/kuya/Documents/Jobdun/admin-web`.

---

## Ported facts (authoritative — from the Flutter recon)

### Data
**Queue load** (`getVerificationQueue()`), 3 reads then project:
1. `verification_documents`: `.select("*, profiles!verification_documents_trade_id_fkey(display_name)").is("deleted_at", null).order("submitted_at", { ascending: false })`.
2. `user_roles`: `.select("user_id, role").in("user_id", <unique trade_ids>)` → map `user_id → role`.
3. `verifications`: `.select("id, user_id, kind, status, failure_reason, updated_at, abn_entity_name, entity_type, gst_registered, register_source, detail_captured_at, abr_state").in("user_id", <unique trade_ids>).order("updated_at", { ascending: false })` → reduce to the **latest row per `${user_id}::${kind}`**.

**Projection** → `VerificationItem` (see Task 1). `kind` from `doc_type`: `trade_licence→tradeLicence`, `abn_certificate→builderAbn`, `white_card→whiteCard`, `public_liability`/`workers_compensation→publicLiability`, else `other`. The matching `verifications` row uses kind `licence` (tradeLicence) / `abn` (builderAbn), else none.

**Sort** (client): pending first (status `"pending"`) ascending by `submittedAt` (oldest first); then reviewed descending (newest first). Reviewed section caps at **50** with "Showing latest 50 of N".

**Chip filters** (default `all`, each with a live count): `all`, `tradeLicence`, `builderAbn`, `whiteCard`, `publicLiability`, `other` → labels **All / Trade Licence / Builder ABN / White Card / Insurance / Other**. Filter compares `item.kind`.

**Signed URL**: `supabase.storage.from("private-docs").createSignedUrl(filePath, 60)`.

**RPCs**:
- `review_verification_document(p_document_id uuid, p_status text['approved'|'rejected'], p_notes text?, p_confirmed_number text?, p_trade_class text?)` → void. Pass `confirmed_number`/`trade_class` **only on approve**, and only non-empty; `notes` only if non-empty.
- `revoke_verification(p_user_id uuid, p_kind text['abn'|'licence'], p_reason text)` → void.
- `admin_view_verification_raw(p_verification_id uuid)` → jsonb (audited).

**Statuses**: doc `pending|approved|rejected|expired`. `canRevoke = lastVerificationStatus === "verified" && (kind === "tradeLicence" || kind === "builderAbn")`; revoke kind = `tradeLicence→"licence"`, `builderAbn→"abn"`.

### UI (mapped to P0 tokens; pending = amber `warning`, NOT brand orange)
- **Status** → dot + badge colour: `pending`=warning (amber), `approved`=verified (green), `rejected`=urgent (red), `expired`=text3.
- **Kind badge** colours: tradeLicence=`bg-action-bg text-action-tx`, builderAbn=`bg-verified-bg text-verified-tx`, whiteCard=`bg-available-bg text-available-tx`, publicLiability/other=`bg-surface-raised text-text1`. Labels: TRADE LICENCE / BUILDER ABN / WHITE CARD / INSURANCE / OTHER (append ` · {state}` if state set).
- **Queue-age** (pending only, now − submittedAt): `<18h` plain "{n} min/h in queue" (text3); `18–24h` amber chip "{h}h IN QUEUE"; `≥24h` red chip "SLA BREACHED · {h}h IN QUEUE".
- **Doc titles** by docType: `trade_licence`→"Trade Licence", `abn_certificate`→"ABN Certificate", `public_liability`→"Public Liability", `workers_compensation`→"Workers Compensation", `white_card`→"White Card", `photo_id`→"Photo ID", else "Document".
- Exact copy strings are in the component tasks below.

### Register links (`lib/admin/registers.ts`)
NSW `NSW Fair Trading` https://www.fairtrading.nsw.gov.au/help-centre/online-tools/home-building-licence-check · VIC `Victorian Building Authority` https://www.vba.vic.gov.au/tools/find-practitioner · QLD `QBCC` https://my.qbcc.qld.gov.au/s/qbcc-licensee-register · SA `Consumer & Business Services` https://www.cbs.sa.gov.au/find-a-licence-holder · WA `Building & Energy (DEMIRS)` https://www.commerce.wa.gov.au/building-and-energy/building-and-energy-licence-search · TAS `CBOS (My Licence)` https://www.cbos.tas.gov.au/topics/licensing-and-registration/search-licensed-occupations · ACT `Access Canberra` https://www.accesscanberra.act.gov.au/business-and-work/public-registers · NT `Building Practitioners Board` https://bpb.nt.gov.au

---

## File structure

| File | Responsibility |
|---|---|
| `lib/data/verifications.ts` | Types + `getVerificationQueue()` + helpers (kind/label/canRevoke). |
| `lib/admin/registers.ts` | The 8-state register table + lookup. |
| `lib/actions/verifications.ts` | `"use server"`: `reviewDocument`, `revokeVerification`, `getRawPayload`, `getSignedDocUrl`. |
| `components/ui/dialog.tsx` | shadcn Dialog (added via CLI, lucide→Phosphor). |
| `components/admin/verifications/kind-badge.tsx` · `status-badge.tsx` · `queue-age.tsx` | Small shared presentational bits. |
| `components/admin/verifications/verification-chips.tsx` | Filter chip row (counts). |
| `components/admin/verifications/verification-row.tsx` | One queue row. |
| `components/admin/verifications/verification-queue.tsx` | `"use client"` — filtering + sections + modal state. |
| `components/admin/verifications/review-dialog.tsx` | The review modal (composes the cards). |
| `components/admin/verifications/doc-viewer.tsx` | Thumbnail + fullscreen zoom (`react-zoom-pan-pinch`). |
| `components/admin/verifications/meta-table.tsx` · `captured-details.tsx` · `register-link.tsx` · `failure-block.tsx` · `confirm-fields.tsx` · `revoke-action.tsx` · `raw-payload-dialog.tsx` | Modal sub-sections. |
| `app/(admin)/verifications/page.tsx` | Server Component: load queue → `VerificationQueue`. |

> **Orchestration:** Stage A (sequential) = Tasks 1–4 (data, actions, shadcn Dialog + zoom dep, shared types + badges + the `ReviewDialog` contract stub). Stage B (2 parallel agents) = the **queue** (Task 5) ∥ the **review modal** (Task 6), both against the Stage-A contract. Stage C = integrate + verify (authed Playwright vs real data) + deploy.

---

## Task 1: Data layer + types + helpers

**File:** Create `lib/data/verifications.ts`.

```ts
import "server-only";
import { createClient } from "@/lib/supabase/server";

export type VerificationKind =
  | "tradeLicence" | "builderAbn" | "whiteCard" | "publicLiability" | "other";
export type KindFilter = "all" | VerificationKind;
export type DocStatus = "pending" | "approved" | "rejected" | "expired";

export type VerificationItem = {
  id: string;
  tradeId: string;
  docType: string;
  kind: VerificationKind;
  status: DocStatus;
  submittedAt: string;
  filePath: string;
  state: string | null;
  issuer: string | null;
  documentNumber: string | null;
  issuedDate: string | null;
  expiryDate: string | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  reviewNotes: string | null;
  userDisplayName: string | null;
  userRole: string | null;
  lastVerificationStatus: string | null;
  lastVerificationFailureReason: string | null;
  verificationId: string | null;
  capturedLegalName: string | null;
  capturedEntityType: string | null;
  gstRegistered: boolean | null;
  registerSource: string | null;
  detailCapturedAt: string | null;
  abrState: string | null;
};

const KIND_BY_DOCTYPE: Record<string, VerificationKind> = {
  trade_licence: "tradeLicence",
  abn_certificate: "builderAbn",
  white_card: "whiteCard",
  public_liability: "publicLiability",
  workers_compensation: "publicLiability",
};
export const kindOf = (docType: string): VerificationKind =>
  KIND_BY_DOCTYPE[docType] ?? "other";

export const KIND_LABEL: Record<VerificationKind, string> = {
  tradeLicence: "TRADE LICENCE",
  builderAbn: "BUILDER ABN",
  whiteCard: "WHITE CARD",
  publicLiability: "INSURANCE",
  other: "OTHER",
};

export const FILTERS: { value: KindFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "tradeLicence", label: "Trade Licence" },
  { value: "builderAbn", label: "Builder ABN" },
  { value: "whiteCard", label: "White Card" },
  { value: "publicLiability", label: "Insurance" },
  { value: "other", label: "Other" },
];

export const DOC_TITLE: Record<string, string> = {
  trade_licence: "Trade Licence",
  abn_certificate: "ABN Certificate",
  public_liability: "Public Liability",
  workers_compensation: "Workers Compensation",
  white_card: "White Card",
  photo_id: "Photo ID",
};
export const docTitle = (docType: string) => DOC_TITLE[docType] ?? "Document";

/** Revoke is allowed only for a currently-verified ABN/licence identity. */
export function revokeKind(item: VerificationItem): "abn" | "licence" | null {
  if (item.lastVerificationStatus !== "verified") return null;
  if (item.kind === "tradeLicence") return "licence";
  if (item.kind === "builderAbn") return "abn";
  return null;
}

type DocRow = Record<string, unknown> & {
  profiles?: { display_name?: string | null } | null;
};

/** The verification queue: 3 RLS-gated reads, projected. Newest-first at fetch;
 *  the client re-sorts pending-oldest-first / reviewed-newest-first. */
export async function getVerificationQueue(): Promise<VerificationItem[]> {
  const supabase = await createClient();

  const { data: docs, error } = await supabase
    .from("verification_documents")
    .select("*, profiles!verification_documents_trade_id_fkey(display_name)")
    .is("deleted_at", null)
    .order("submitted_at", { ascending: false });
  if (error || !docs) return [];

  const userIds = [...new Set(docs.map((d) => d.trade_id as string))];
  if (userIds.length === 0) return [];

  const [{ data: roleRows }, { data: verifRows }] = await Promise.all([
    supabase.from("user_roles").select("user_id, role").in("user_id", userIds),
    supabase
      .from("verifications")
      .select(
        "id, user_id, kind, status, failure_reason, updated_at, abn_entity_name, entity_type, gst_registered, register_source, detail_captured_at, abr_state",
      )
      .in("user_id", userIds)
      .order("updated_at", { ascending: false }),
  ]);

  const roleByUser = new Map<string, string>(
    (roleRows ?? []).map((r) => [r.user_id as string, r.role as string]),
  );
  const latestVerif = new Map<string, Record<string, unknown>>();
  for (const r of verifRows ?? []) {
    const key = `${r.user_id}::${r.kind}`;
    if (!latestVerif.has(key)) latestVerif.set(key, r);
  }

  const s = (v: unknown): string | null => (v == null ? null : String(v));
  return (docs as DocRow[]).map((d) => {
    const kind = kindOf(String(d.doc_type ?? ""));
    const verifKind =
      kind === "tradeLicence" ? "licence" : kind === "builderAbn" ? "abn" : null;
    const v = verifKind ? latestVerif.get(`${d.trade_id}::${verifKind}`) : undefined;
    return {
      id: String(d.id),
      tradeId: String(d.trade_id),
      docType: String(d.doc_type ?? d.type ?? "other"),
      kind,
      status: (d.status as DocStatus) ?? "pending",
      submittedAt: String(d.submitted_at ?? d.created_at),
      filePath: String(d.file_path ?? d.url ?? ""),
      state: s(d.state),
      issuer: s(d.issuer),
      documentNumber: s(d.document_number),
      issuedDate: s(d.issued_date),
      expiryDate: s(d.expiry_date),
      reviewedAt: s(d.reviewed_at),
      reviewedBy: s(d.reviewed_by),
      reviewNotes: s(d.review_notes),
      userDisplayName: d.profiles?.display_name ?? null,
      userRole: roleByUser.get(String(d.trade_id)) ?? null,
      lastVerificationStatus: v ? s(v.status) : null,
      lastVerificationFailureReason: v ? s(v.failure_reason) : null,
      verificationId: v ? s(v.id) : null,
      capturedLegalName: v ? s(v.abn_entity_name) : null,
      capturedEntityType: v ? s(v.entity_type) : null,
      gstRegistered: v ? (v.gst_registered as boolean | null) : null,
      registerSource: v ? s(v.register_source) : null,
      detailCapturedAt: v ? s(v.detail_captured_at) : null,
      abrState: v ? s(v.abr_state) : null,
    };
  });
}
```

- [ ] Create the file. (No unit test — Supabase wrapper; verified by build + live smoke.)

---

## Task 2: Register table + Server Actions

- [ ] **`lib/admin/registers.ts`**

```ts
export type Register = { regulator: string; url: string };
export const REGISTERS: Record<string, Register> = {
  NSW: { regulator: "NSW Fair Trading", url: "https://www.fairtrading.nsw.gov.au/help-centre/online-tools/home-building-licence-check" },
  VIC: { regulator: "Victorian Building Authority", url: "https://www.vba.vic.gov.au/tools/find-practitioner" },
  QLD: { regulator: "QBCC", url: "https://my.qbcc.qld.gov.au/s/qbcc-licensee-register" },
  SA: { regulator: "Consumer & Business Services", url: "https://www.cbs.sa.gov.au/find-a-licence-holder" },
  WA: { regulator: "Building & Energy (DEMIRS)", url: "https://www.commerce.wa.gov.au/building-and-energy/building-and-energy-licence-search" },
  TAS: { regulator: "CBOS (My Licence)", url: "https://www.cbos.tas.gov.au/topics/licensing-and-registration/search-licensed-occupations" },
  ACT: { regulator: "Access Canberra", url: "https://www.accesscanberra.act.gov.au/business-and-work/public-registers" },
  NT: { regulator: "Building Practitioners Board", url: "https://bpb.nt.gov.au" },
};
export const registerFor = (state: string | null) =>
  state ? (REGISTERS[state.trim().toUpperCase()] ?? null) : null;
```

- [ ] **`lib/actions/verifications.ts`**

```ts
"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

const msg = (e: unknown, fallback: string) =>
  e instanceof Error ? humanise(e.message) : fallback;
function humanise(raw: string): string {
  if (raw.includes("not_admin")) return "You are not authorised.";
  if (raw.includes("invalid_status")) return "Status must be approve or reject.";
  if (raw.includes("invalid_kind")) return "Invalid verification kind.";
  if (raw.includes("no_verified_row")) return "No verified record to revoke.";
  return raw;
}

export async function reviewDocument(input: {
  documentId: string;
  status: "approved" | "rejected";
  notes?: string;
  confirmedNumber?: string;
  tradeClass?: string;
}): Promise<{ error?: string }> {
  const supabase = await createClient();
  const approve = input.status === "approved";
  const notes = input.notes?.trim();
  const number = input.confirmedNumber?.trim();
  const tradeClass = input.tradeClass?.trim();
  const { error } = await supabase.rpc("review_verification_document", {
    p_document_id: input.documentId,
    p_status: input.status,
    p_notes: notes ? notes : null,
    p_confirmed_number: approve && number ? number : null,
    p_trade_class: approve && tradeClass ? tradeClass : null,
  });
  if (error) return { error: msg(error, "Review failed.") };
  revalidatePath("/verifications");
  return {};
}

export async function revokeVerification(input: {
  userId: string;
  kind: "abn" | "licence";
  reason: string;
}): Promise<{ error?: string }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_verification", {
    p_user_id: input.userId,
    p_kind: input.kind,
    p_reason: input.reason,
  });
  if (error) return { error: msg(error, "Revoke failed.") };
  revalidatePath("/verifications");
  return {};
}

export async function getRawPayload(
  verificationId: string,
): Promise<{ data?: unknown; error?: string }> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_view_verification_raw", {
    p_verification_id: verificationId,
  });
  if (error) return { error: msg(error, "Could not load payload.") };
  return { data };
}

export async function getSignedDocUrl(
  filePath: string,
): Promise<{ url?: string; error?: string }> {
  const supabase = await createClient();
  const { data, error } = await supabase.storage
    .from("private-docs")
    .createSignedUrl(filePath, 60);
  if (error || !data) return { error: "Could not load the document." };
  return { url: data.signedUrl };
}
```

- [ ] Create both files.

---

## Task 3: shadcn Dialog + zoom dep + shared badges + ReviewDialog contract

- [ ] **Add shadcn Dialog + zoom lib.** Run: `npx shadcn@latest add dialog --yes` then `npm install react-zoom-pan-pinch`. In `components/ui/dialog.tsx`, replace the lucide `XIcon` import + usage with Phosphor: `import { X } from "@phosphor-icons/react"` and `<X className="size-4" aria-hidden />` (we are Phosphor-only). Leave the rest.

- [ ] **`components/admin/verifications/status-badge.tsx`**

```tsx
import { cn } from "@/lib/utils";
import type { DocStatus } from "@/lib/data/verifications";

const TONE: Record<DocStatus, { dot: string; text: string }> = {
  pending: { dot: "bg-warning", text: "text-warning-tx" },
  approved: { dot: "bg-verified", text: "text-verified-tx" },
  rejected: { dot: "bg-urgent", text: "text-urgent-tx" },
  expired: { dot: "bg-text3", text: "text-text3" },
};

export function StatusDot({ status }: { status: DocStatus }) {
  return <span className={cn("size-2.5 shrink-0 rounded-full", TONE[status].dot)} aria-hidden />;
}
export function StatusBadge({ status }: { status: DocStatus }) {
  return <span className={cn("t-eyebrow", TONE[status].text)}>{status.toUpperCase()}</span>;
}
```

- [ ] **`components/admin/verifications/kind-badge.tsx`**

```tsx
import { cn } from "@/lib/utils";
import { KIND_LABEL, type VerificationKind } from "@/lib/data/verifications";

const TONE: Record<VerificationKind, string> = {
  tradeLicence: "bg-action-bg text-action-tx",
  builderAbn: "bg-verified-bg text-verified-tx",
  whiteCard: "bg-available-bg text-available-tx",
  publicLiability: "bg-surface-raised text-text1",
  other: "bg-surface-raised text-text1",
};

export function KindBadge({ kind, state }: { kind: VerificationKind; state?: string | null }) {
  return (
    <span className={cn("rounded-badge px-2 py-0.5 t-eyebrow", TONE[kind])}>
      {KIND_LABEL[kind]}
      {state ? ` · ${state}` : ""}
    </span>
  );
}
```

- [ ] **`components/admin/verifications/queue-age.tsx`** (pending only)

```tsx
import { cn } from "@/lib/utils";

export function QueueAge({ submittedAt }: { submittedAt: string }) {
  const ms = Date.now() - new Date(submittedAt).getTime();
  const hours = Math.floor(ms / 3_600_000);
  if (hours < 18) {
    const label = hours < 1 ? `${Math.floor(ms / 60_000)} min in queue` : `${hours} h in queue`;
    return <span className="t-body-sm text-text3">{label}</span>;
  }
  const breached = hours >= 24;
  return (
    <span
      className={cn(
        "inline-block rounded-badge px-2 py-0.5 t-eyebrow",
        breached ? "bg-urgent-bg text-urgent-tx" : "bg-warning-bg text-warning-tx",
      )}
    >
      {breached ? `SLA BREACHED · ${hours}h IN QUEUE` : `${hours}h IN QUEUE`}
    </span>
  );
}
```

- [ ] **`components/admin/verifications/review-dialog.tsx`** — create as a STUB now (Task 6 fills it in; the queue imports it against this exact contract):

```tsx
"use client";
import type { VerificationItem } from "@/lib/data/verifications";

export function ReviewDialog({
  item,
  open,
  onOpenChange,
}: {
  item: VerificationItem | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  // Implemented in Task 6.
  void item;
  void open;
  void onOpenChange;
  return null;
}
```

- [ ] Verify: `npm run build` compiles (the stub + badges).

---

## Task 4: (folded into Task 3 — Stage A is Tasks 1–3.)

---

## Task 5: The queue  *(Stage B — agent #1)*

**Files:** `verification-chips.tsx`, `verification-row.tsx`, `verification-queue.tsx`, `app/(admin)/verifications/page.tsx`.

- [ ] **`verification-chips.tsx`** — pill row, default `all`, each chip shows label + count; selected = `bg-action text-on-action`, else `bg-surface-raised text-text1`; count sub-badge.

```tsx
"use client";
import { cn } from "@/lib/utils";
import { FILTERS, type KindFilter } from "@/lib/data/verifications";

export function VerificationChips({
  active,
  counts,
  onSelect,
}: {
  active: KindFilter;
  counts: Record<KindFilter, number>;
  onSelect: (f: KindFilter) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2" role="tablist" aria-label="Filter verifications">
      {FILTERS.map((f) => {
        const on = active === f.value;
        return (
          <button
            key={f.value}
            type="button"
            role="tab"
            aria-selected={on}
            onClick={() => onSelect(f.value)}
            className={cn(
              "inline-flex items-center gap-2 rounded-full px-3.5 py-2 t-eyebrow cursor-pointer transition-jobdun",
              on ? "bg-action text-on-action" : "bg-surface-raised text-text1 hover:brightness-110",
            )}
          >
            {f.label.toUpperCase()}
            <span className={cn("rounded-badge px-1.5 py-0.5 nums", on ? "bg-on-action/15" : "bg-background text-text2")}>
              {counts[f.value] ?? 0}
            </span>
          </button>
        );
      })}
    </div>
  );
}
```

- [ ] **`verification-row.tsx`** — a button row. Compose: `StatusDot` + a flex-1 column { line1: `KindBadge` + role tag (`ROLE: {role}` in `bg-background t-eyebrow text-text3` if `userRole`); line2: display name (`t-title-md text-text1`, fallback `{tradeId.slice(0,8)}…`); line3 claim summary (`t-body-sm text-text2`): `#{documentNumber} · expires {fmtDate(expiryDate)}` (omit missing halves, omit line if both null); line4: `submitted {fmtDateTime(submittedAt)}` (`t-body-sm text-text3`); line5 (pending only): `<QueueAge submittedAt={…} />`; line6 (if `lastVerificationFailureReason`): a `bg-urgent-bg` chip "API attempt failed: {reason}" with a `WarningCircle` icon } + right: `StatusBadge` + a `CaretRight` (text3). Container: `flex w-full items-start gap-3 rounded-card border border-border bg-surface px-4 py-3.5 text-left transition-jobdun hover:border-border-strong cursor-pointer`. `onClick` → `onOpen(item)`. Dates via `Intl.DateTimeFormat("en-AU", …)` helpers (`fmtDate` = `d MMM yyyy`; `fmtDateTime` = `d MMM yyyy · HH:mm`).

- [ ] **`verification-queue.tsx`** (`"use client"`) — owns: `active` filter state, `selected` item state. Computes `counts` per filter (all = items.length; each kind = items where kind===value). `filtered` = active==="all" ? items : items.filter(kind===active). Split: `pending` = filtered.filter(status==="pending").sort(asc submittedAt); `reviewed` = filtered.filter(status!=="pending").sort(desc submittedAt); render pending (all) then reviewed.slice(0,50). Sections: header row "PENDING"/"REVIEWED" (`t-title-lg`) + count badge; reviewed pagination note "Showing latest 50 of {reviewed.length}" when >50. Empty states: items.length===0 → EmptyState icon `Tray` "No verification documents yet."; filtered.length===0 → EmptyState "Nothing in this category right now." hint "Try a different filter chip above." Renders `<VerificationChips …/>`, the sections of `<VerificationRow … onOpen={setSelected}/>`, and `<ReviewDialog item={selected} open={!!selected} onOpenChange={(o)=>{ if(!o) setSelected(null); }}/>`.

- [ ] **`app/(admin)/verifications/page.tsx`** (Server Component):

```tsx
import { getVerificationQueue } from "@/lib/data/verifications";
import { VerificationQueue } from "@/components/admin/verifications/verification-queue";

export const dynamic = "force-dynamic";

export default async function VerificationsPage() {
  const items = await getVerificationQueue();
  return <VerificationQueue items={items} />;
}
```

- [ ] Self-check `npx eslint app/\(admin\)/verifications components/admin/verifications/{verification-chips,verification-row,verification-queue}.tsx`. NO commit, NO build (concurrent agent). Tokens only; Phosphor (`CaretRight`, `WarningCircle`, `Tray` from `@phosphor-icons/react` in these client files).

---

## Task 6: The review modal  *(Stage B — agent #2)*

**Files:** replace `review-dialog.tsx`; create `doc-viewer.tsx`, `meta-table.tsx`, `captured-details.tsx`, `register-link.tsx`, `failure-block.tsx`, `confirm-fields.tsx`, `revoke-action.tsx`, `raw-payload-dialog.tsx`.

- [ ] **`review-dialog.tsx`** — shadcn `Dialog` (`open`, `onOpenChange`). `DialogContent` `className="max-w-3xl max-h-[85vh] gap-0 overflow-y-auto bg-surface border-border p-6"`. Returns `null` if `!item`. Structure (top→bottom, gap-4):
  - **Header**: `DialogTitle` = `docTitle(item.docType)` (`t-headline-sm`); below it `DialogDescription` line: uploader display name (`t-body-md text-text1`) + role tag + `user {tradeId} · submitted {fmtDateTime(submittedAt)}` (`t-body-sm text-text2`).
  - `<DocViewer filePath={item.filePath} />`
  - `<MetaTable item={item} />`
  - `registerFor(item.state)` && `item.kind==="tradeLicence"` → `<RegisterLink state={item.state!} number={item.documentNumber} />`
  - `item.verificationId` → `<CapturedDetails item={item} />`
  - `item.lastVerificationFailureReason` → `<FailureBlock status={item.lastVerificationStatus} detail={item.lastVerificationFailureReason} />`
  - **Confirm fields + notes** (a client form holding `confirmedNumber`, `tradeClass`, `notes` state): `<ConfirmFields showTradeClass={item.kind==="tradeLicence"} …/>` + a notes `<textarea>` (label "Review notes (optional)").
  - `revokeKind(item)` → `<RevokeAction userId={item.tradeId} kind={revokeKind(item)!} kindLabel={…} onDone={()=>onOpenChange(false)} />`
  - `error` (string|null) shown `t-body-sm text-urgent-tx`.
  - **Footer**: if status!=="pending": left note "Already {status} — changes will overwrite." (`t-body-sm text-text3`). Right: `Button variant="danger"` "REJECT" + `Button` "APPROVE", each disabled while busy, each showing a per-action pending label. On click → `reviewDocument({documentId: item.id, status, notes, confirmedNumber, tradeClass})` in a transition; on `{error}` show it; on success `onOpenChange(false)`.

- [ ] **`doc-viewer.tsx`** (`"use client"`): on mount (or when filePath changes) call `getSignedDocUrl(filePath)` → url. Render a 320px-tall `bg-background rounded-card border border-border` box: loading → `<Skeleton className="h-80 w-full"/>`; error → centred `t-body-sm text-urgent-tx`; else an `<img src={url} className="h-80 w-full object-contain">` with a bottom-right "TAP TO ZOOM" overlay badge (`bg-background/80 border border-border rounded-chip px-2 py-1 t-eyebrow` + `MagnifyingGlassPlus` icon). Clicking opens a fullscreen shadcn `Dialog` (`DialogContent className="max-w-[95vw] max-h-[95vh] bg-background/95 border-0 p-0"`) containing `<TransformWrapper><TransformComponent>` (`react-zoom-pan-pinch`) wrapping the `<img>` (pan/scroll/pinch zoom). Include a `DialogTitle` sr-only "Document".

- [ ] **`meta-table.tsx`**: a `<dl>` of label/value rows (label `w-36 t-eyebrow text-text3`, value `t-body-md text-text1`), each omitted when null: State, Issuer, Document number, Issued (`fmtDate(issuedDate)`), Expires (`fmtDate(expiryDate)`), Last reviewed (`{fmtDateTime(reviewedAt)} by {reviewedBy?.slice(0,8) ?? "unknown"}…`). Reuse the P0 `KVRow` if convenient.

- [ ] **`captured-details.tsx`** (`"use client"`, because of VIEW RAW): a `bg-background border border-border rounded-card p-3` card. Header row: "CAPTURED DETAILS" (`t-eyebrow text-text3`) + a "VIEW RAW" button (opens `<RawPayloadDialog verificationId={item.verificationId!} />`). Body KV rows (omit null): Legal name, Entity type, GST (`gstRegistered ? "Registered" : "Not registered"` when not null), Register (`registerSource`), Business state (`abrState`), Captured (`fmtDateTime(detailCapturedAt)`). If no rows: "No structured details captured yet." (`t-body-sm text-text3`).

- [ ] **`raw-payload-dialog.tsx`** (`"use client"`): a shadcn Dialog triggered by the VIEW RAW button. On open, call `getRawPayload(verificationId)`; render `DialogTitle` "Raw regulator payload" + a `<pre className="max-h-[60vh] overflow-auto rounded-card bg-background p-3 font-mono text-xs text-text2">{JSON.stringify(data, null, 2)}</pre>`; loading skeleton; error `t-body-sm text-urgent-tx`.

- [ ] **`register-link.tsx`**: external `<a href={registerFor(state)!.url} target="_blank" rel="noreferrer">` styled `bg-action-bg/40 border border-action/35 rounded-card p-3 flex items-center gap-2.5 hover:brightness-110`: `ArrowSquareOut` icon (`text-action-ink`) + column { title `CHECK ON {regulator.toUpperCase()}` (`t-label text-action-ink`); subtitle `{state} official register` (`t-body-sm text-text3`) + (number ? ` · ${number}` : "") }.

- [ ] **`failure-block.tsx`**: `bg-urgent-bg border border-urgent/30 rounded-card p-3`: header `WarningCircle` (text-urgent-tx) + "WHAT THE REGULATOR SAID" (`t-eyebrow text-urgent-tx`) + (status ? ` · ${status.toUpperCase()}` text-text3); detail (`t-body-md text-text1`); helper (`t-body-sm italic text-text3`): "The user fell back to manual upload after this regulator response. Approve only if the document independently confirms the claim."

- [ ] **`confirm-fields.tsx`** (`"use client"`, controlled): label "CONFIRM WHAT YOU SAW ON THE DOCUMENT" (`t-eyebrow text-text3`); a "Confirmed number" `<input>` (helper "Edit if it differs from what the user typed.") bound to a value+onChange; and when `showTradeClass`, a "Confirmed trade class" input (helper "e.g. Carpentry, Electrical — as shown on the licence."). Reuse the P0 `Field` look (`h-11 rounded-input border border-border bg-surface px-4 t-body-md`).

- [ ] **`revoke-action.tsx`** (`"use client"`): a `Button variant="danger"` "REVOKE VERIFICATION" (`Prohibit` icon) + help text "User currently holds a verified {kindLabel} row. Revoking undoes it across the app." (`t-body-sm text-text3`). Click → a shadcn confirm Dialog: title "Revoke verification?"; body "This clears the user's verified status for this identity. They will appear unverified across the app until they re-verify. Enter a reason — it is recorded in the audit log."; a "Reason for revoking" `<textarea>` (autofocus); buttons CANCEL (secondary) + REVOKE (danger, disabled until reason non-empty). On REVOKE → `revokeVerification({userId, kind, reason})` in a transition; on success close both dialogs + `onDone()`; on `{error}` show it.

- [ ] Self-check `npx eslint components/admin/verifications/{review-dialog,doc-viewer,meta-table,captured-details,register-link,failure-block,confirm-fields,revoke-action,raw-payload-dialog}.tsx`. NO commit, NO build. Tokens only; Phosphor client icons (`MagnifyingGlassPlus`, `ArrowSquareOut`, `WarningCircle`, `Prohibit`, `X`). Em-dashes are fine in these internal admin strings? Keep rendered copy em-dash-free where the recon used them: write "—" only where it's a literal placeholder value; in prose use periods/commas (e.g. "Enter a reason. It is recorded in the audit log.", "as shown on the licence.").

---

## Task 7: Integrate, verify, deploy  *(Stage C)*

- [ ] Commit Stage B files grouped (queue; review modal). Then `npm run test && npm run lint && npm run build` — all green; `/verifications` is `ƒ`. Token audit (grep hex/generic-palette/arbitrary-color over `lib/data/verifications.ts lib/admin/registers.ts lib/actions/verifications.ts components/admin/verifications app/(admin)/verifications`) = none (the shadcn Dialog `bg-black/50` overlay scrim is the sanctioned exception).
- [ ] **Live verify against REAL data** (we have admin creds): extend the smoke pattern — `node --env-file=.env.local` a Playwright script that logs in, navigates to `/verifications`, screenshots the queue, opens the first row's review modal, screenshots it (this exercises the signed-URL doc viewer + the cards with real data). Read the screenshots; revert any throwaway script. Do NOT auto-approve/reject in the smoke (no mutations against prod).
- [ ] Commit, push, `vercel deploy --prod`. Live gate holds.

---

## Done-When
- `/verifications` shows the real queue (chip filters + counts, pending-oldest / reviewed-newest, SLA age, status), opens the review modal with the zoomable signed-URL doc, metadata, register link, captured details, failure block, confirm fields, notes; **approve / reject / revoke** call the RPCs and refresh; VIEW RAW shows the audited payload.
- Build/lint/test green; token-pure; verified against real prod data via the authed Playwright session; deployed.
