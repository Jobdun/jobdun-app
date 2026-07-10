# Admin Web — Phase 4 (Users) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans. Checkbox steps.

**Goal:** Build `/users` (paginated list with role filter + display-name search) and `/users/[id]` (profile + role-gated builder/trade subprofile + verifications + **live moderation**: reactivate/suspend/ban).

**Architecture:** Both pages are Server Components. The list reads `searchParams` (`role`, `q`, `page`) and calls `getUsersPage()` (URL-driven server pagination, 50/page); a client `UserFilters` pushes URL changes and a `Paginator` does prev/next. The detail calls `getUserDetail()` (5 parallel reads). Moderation = a client card calling the `setUserStatus` Server Action over the live `admin_set_user_status` RPC (`revalidatePath`). Zero backend changes. **Apply the P3 lesson up front:** pure types/constants in a client-safe module (`lib/data/users.ts`), server queries in a `server-only` module (`lib/data/users-queries.ts`).

**Tech Stack:** Next 16 App Router, `@supabase/ssr` server client, Phosphor icons, Tailwind v4 (P0 tokens), P0 primitives (Card/KVRow/Button/Field/Skeleton/EmptyState/ErrorState/StatusTag). Working dir `/Users/kuya/Documents/Jobdun/admin-web`.

---

## Ported facts (data recon is authoritative on columns)

**List** (`getUsersPage({role, q, page})`, 50/page): role filter (when ≠ "all") → query `user_roles.select("user_id").eq("role", role)` for allowed ids → `profiles.in("id", allowedIds)`. Then `profiles.select("id, display_name, avatar_url, created_at")` + (q ? `.ilike("display_name", "%q%")`) + `.order("created_at", desc).range(offset, offset+49)`. Enrich each page: role from `user_roles` (batch), `isVerified` from `trade_profiles.is_verified` (batch). `hasMore = rows.length === 50`. Role values: `builder|trade|admin`. Search is **display_name only**, `ilike`.

**Detail** (`getUserDetail(id)`, 5 parallel reads):
- `profiles`: `id, display_name, avatar_url, phone, phone_verified_at, created_at, updated_at, user_status`
- `user_roles`: `role`
- `builder_profiles` (id = profile id): `company_name, abn, contact_name, contact_phone, about, website, years_in_business, service_suburb, service_state, service_postcode`
- `trade_profiles` (id = profile id): `full_name, primary_trade, is_verified, portfolio_urls, hourly_rate_min, years_experience, about, base_suburb, base_state, base_postcode, licence_url`
- `verifications`: `kind, status, failure_reason, updated_at` ordered desc, **deduped to latest per kind**.
Subprofile is role-gated: builder card iff `role==="builder" && builder`; trade card iff `role==="trade" && trade`.

**Moderation (LIVE)**: `admin_set_user_status(p_user_id, p_status['active'|'suspended'|'banned'], p_reason?)`. Buttons: REACTIVATE (if status≠active) / SUSPEND (if ≠suspended) / BAN (if ≠banned).

**UI**: list role chips `ALL / BUILDERS / TRADES / ADMINS`, search placeholder "Search display name…", empty "No users match." + "Try a different filter or search term.", error "COULDN'T LOAD USERS". Row: 36px avatar + name (+verified tick) + role (uppercase) + created date (right). Detail: back "BACK TO USERS", header (72px avatar, name + verified tick + role pill + `ID: {id}` + `Joined {date}`), cards "PROFILE" / "BUILDER PROFILE" / "TRADE PROFILE" (+ VERIFIED badge) / "VERIFICATIONS" / "MODERATION". (Row-level subscription/reports placeholder tags are omitted — micro-roadmap noise, not screens.) Tokens only; pending=amber etc. as P3.

---

## File structure

| File | Responsibility |
|---|---|
| `lib/data/users.ts` | Pure types + `ROLE_FILTERS` + `USERS_PAGE_SIZE` + `locationLine` (client-safe). |
| `lib/data/users-queries.ts` | `server-only`: `getUsersPage`, `getUserDetail`. |
| `lib/actions/users.ts` | `"use server"`: `setUserStatus`. |
| `components/admin/users/avatar.tsx` | Circular avatar (img or initial). |
| `components/admin/users/user-filters.tsx` · `user-row.tsx` · `paginator.tsx` | List bits. |
| `components/admin/users/user-header.tsx` · `profile-card.tsx` · `builder-card.tsx` · `trade-card.tsx` · `verifications-card.tsx` · `moderation-card.tsx` | Detail cards. |
| `app/(admin)/users/page.tsx` · `app/(admin)/users/[id]/page.tsx` | The two routes. |

> **Orchestration:** Stage A (sequential) = Tasks 1–2 (data types + queries + actions + Avatar). Stage B (2 parallel) = list (Task 3) ∥ detail (Task 4). Stage C = integrate + verify (authed Playwright vs the real 8 users) + deploy.

---

## Task 1: Data — types (client-safe) + server queries

- [ ] **`lib/data/users.ts`**

```ts
export type UserRole = "builder" | "trade" | "admin" | "unknown";
export type RoleFilter = "all" | "builder" | "trade" | "admin";
export type UserStatus = "active" | "suspended" | "banned";

export type UserRow = {
  id: string; displayName: string; role: UserRole;
  isVerified: boolean; createdAt: string; avatarUrl: string | null;
};
export type BuilderProfile = {
  companyName: string | null; abn: string | null; contactName: string | null;
  contactPhone: string | null; about: string | null; website: string | null;
  yearsInBusiness: number | null; serviceSuburb: string | null;
  serviceState: string | null; servicePostcode: string | null;
};
export type TradeProfile = {
  fullName: string | null; primaryTrade: string | null; isVerified: boolean;
  portfolioUrls: string[]; hourlyRate: number | null; yearsExperience: number | null;
  about: string | null; baseSuburb: string | null; baseState: string | null;
  basePostcode: string | null; licenceUrl: string | null;
};
export type VerificationSummary = {
  kind: string; status: string; failureReason: string | null; updatedAt: string | null;
};
export type UserDetail = {
  id: string; displayName: string; role: UserRole; createdAt: string;
  userStatus: UserStatus; avatarUrl: string | null; phone: string | null;
  phoneVerifiedAt: string | null; updatedAt: string | null; deletedAt: string | null;
  licenceUrl: string | null; builder: BuilderProfile | null; trade: TradeProfile | null;
  verifications: VerificationSummary[];
};

export const ROLE_FILTERS: { value: RoleFilter; label: string }[] = [
  { value: "all", label: "ALL" },
  { value: "builder", label: "BUILDERS" },
  { value: "trade", label: "TRADES" },
  { value: "admin", label: "ADMINS" },
];
export const USERS_PAGE_SIZE = 50;

/** Join non-empty location parts with ", " (null if none). */
export function locationLine(parts: (string | null)[]): string | null {
  const xs = parts.filter((p): p is string => !!p && p.trim().length > 0);
  return xs.length ? xs.join(", ") : null;
}
```

- [ ] **`lib/data/users-queries.ts`**

```ts
import "server-only";
import { createClient } from "@/lib/supabase/server";
import {
  USERS_PAGE_SIZE,
  type RoleFilter, type UserRole, type UserRow,
  type UserDetail, type UserStatus,
} from "./users";

export async function getUsersPage(params: {
  role: RoleFilter; q: string; page: number;
}): Promise<{ rows: UserRow[]; hasMore: boolean }> {
  const supabase = await createClient();
  const page = Math.max(1, params.page);
  const offset = (page - 1) * USERS_PAGE_SIZE;

  let allowedIds: string[] | null = null;
  if (params.role !== "all") {
    const { data } = await supabase.from("user_roles").select("user_id").eq("role", params.role);
    allowedIds = (data ?? []).map((r) => r.user_id as string);
    if (allowedIds.length === 0) return { rows: [], hasMore: false };
  }

  let q = supabase.from("profiles").select("id, display_name, avatar_url, created_at");
  if (allowedIds) q = q.in("id", allowedIds);
  if (params.q.trim()) q = q.ilike("display_name", `%${params.q.trim()}%`);
  const { data: profiles, error } = await q
    .order("created_at", { ascending: false })
    .range(offset, offset + USERS_PAGE_SIZE - 1);
  if (error || !profiles) return { rows: [], hasMore: false };

  const ids = profiles.map((p) => p.id as string);
  const [roleRes, tradeRes] = await Promise.all([
    ids.length ? supabase.from("user_roles").select("user_id, role").in("user_id", ids) : Promise.resolve({ data: [] as { user_id: string; role: string }[] }),
    ids.length ? supabase.from("trade_profiles").select("id, is_verified").in("id", ids) : Promise.resolve({ data: [] as { id: string; is_verified: boolean }[] }),
  ]);
  const roleBy = new Map((roleRes.data ?? []).map((r) => [r.user_id as string, r.role as string]));
  const verifiedBy = new Map((tradeRes.data ?? []).map((r) => [r.id as string, !!r.is_verified]));

  const rows: UserRow[] = profiles.map((p) => {
    const id = String(p.id);
    const name = (p.display_name as string | null)?.trim();
    return {
      id,
      displayName: name && name.length > 0 ? name : `${id.slice(0, 8)}…`,
      role: (roleBy.get(id) as UserRole) ?? "unknown",
      isVerified: verifiedBy.get(id) ?? false,
      createdAt: String(p.created_at),
      avatarUrl: (p.avatar_url as string | null) ?? null,
    };
  });
  return { rows, hasMore: profiles.length === USERS_PAGE_SIZE };
}

export async function getUserDetail(userId: string): Promise<UserDetail | null> {
  const supabase = await createClient();
  const s = (v: unknown): string | null => (v == null ? null : String(v));
  const n = (v: unknown): number | null => (v == null ? null : Number(v));

  const [pRes, roleRes, bRes, tRes, vRes] = await Promise.all([
    supabase.from("profiles").select("id, display_name, avatar_url, phone, phone_verified_at, created_at, updated_at, user_status").eq("id", userId).maybeSingle(),
    supabase.from("user_roles").select("role").eq("user_id", userId).maybeSingle(),
    supabase.from("builder_profiles").select("company_name, abn, contact_name, contact_phone, about, website, years_in_business, service_suburb, service_state, service_postcode").eq("id", userId).maybeSingle(),
    supabase.from("trade_profiles").select("full_name, primary_trade, is_verified, portfolio_urls, hourly_rate_min, years_experience, about, base_suburb, base_state, base_postcode, licence_url").eq("id", userId).maybeSingle(),
    supabase.from("verifications").select("kind, status, failure_reason, updated_at").eq("user_id", userId).order("updated_at", { ascending: false }),
  ]);

  const p = pRes.data;
  if (!p) return null;
  const b = bRes.data;
  const t = tRes.data;

  const seen = new Set<string>();
  const verifications = (vRes.data ?? [])
    .filter((v) => { const k = String(v.kind); if (seen.has(k)) return false; seen.add(k); return true; })
    .map((v) => ({ kind: String(v.kind), status: String(v.status), failureReason: s(v.failure_reason), updatedAt: s(v.updated_at) }));

  return {
    id: String(p.id),
    displayName: (p.display_name as string | null)?.trim() || `${String(p.id).slice(0, 8)}…`,
    role: ((roleRes.data?.role as string) ?? "unknown") as UserRole,
    createdAt: String(p.created_at),
    userStatus: ((p.user_status as string) ?? "active") as UserStatus,
    avatarUrl: s(p.avatar_url),
    phone: s(p.phone),
    phoneVerifiedAt: s(p.phone_verified_at),
    updatedAt: s(p.updated_at),
    deletedAt: null,
    licenceUrl: t ? s(t.licence_url) : null,
    builder: b ? {
      companyName: s(b.company_name), abn: s(b.abn), contactName: s(b.contact_name),
      contactPhone: s(b.contact_phone), about: s(b.about), website: s(b.website),
      yearsInBusiness: n(b.years_in_business), serviceSuburb: s(b.service_suburb),
      serviceState: s(b.service_state), servicePostcode: s(b.service_postcode),
    } : null,
    trade: t ? {
      fullName: s(t.full_name), primaryTrade: s(t.primary_trade), isVerified: !!t.is_verified,
      portfolioUrls: (t.portfolio_urls as string[] | null) ?? [], hourlyRate: n(t.hourly_rate_min),
      yearsExperience: n(t.years_experience), about: s(t.about), baseSuburb: s(t.base_suburb),
      baseState: s(t.base_state), basePostcode: s(t.base_postcode), licenceUrl: s(t.licence_url),
    } : null,
    verifications,
  };
}
```

- [ ] Create both files.

---

## Task 2: Actions + Avatar

- [ ] **`lib/actions/users.ts`**

```ts
"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function setUserStatus(input: {
  userId: string;
  status: "active" | "suspended" | "banned";
  reason?: string;
}): Promise<{ error?: string }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_user_status", {
    p_user_id: input.userId,
    p_status: input.status,
    p_reason: input.reason?.trim() ? input.reason.trim() : null,
  });
  if (error) {
    return { error: error.message.includes("not_admin") ? "You are not authorised." : error.message };
  }
  revalidatePath(`/users/${input.userId}`);
  revalidatePath("/users");
  return {};
}
```

- [ ] **`components/admin/users/avatar.tsx`** — circular avatar with initial fallback.

```tsx
import { cn } from "@/lib/utils";

export function Avatar({
  url, name, size = 36,
}: { url: string | null; name: string; size?: number }) {
  const initial = (name.trim()[0] ?? "?").toUpperCase();
  return url ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={url} alt=""
      width={size} height={size}
      className="shrink-0 rounded-full object-cover"
      style={{ width: size, height: size }}
    />
  ) : (
    <span
      className={cn("grid shrink-0 place-items-center rounded-full bg-surface-raised font-display font-bold text-text1")}
      style={{ width: size, height: size, fontSize: size * 0.42 }}
      aria-hidden
    >
      {initial}
    </span>
  );
}
```

- [ ] Verify: `npm run build` compiles (data + actions + avatar).

---

## Task 3: The list  *(Stage B — agent #1)*

**Files:** `user-filters.tsx`, `user-row.tsx`, `paginator.tsx`, `app/(admin)/users/page.tsx`.

- [ ] **`user-filters.tsx`** (`"use client"`): role chips (`ROLE_FILTERS`, active = `bg-action text-on-action`, idle = `bg-surface-raised text-text1`, `.t-eyebrow`) + a search `<input>` (placeholder "Search display name…", styled like P0 Field). Reads current `role`/`q` from `useSearchParams`; on chip click or search submit, `useRouter().push("/users?" + new URLSearchParams({ role, q }))` (omit empty, drop `page` to reset to 1). Debounce not required; submit on Enter + on chip click.

- [ ] **`user-row.tsx`**: a `<Link href={`/users/${row.id}`}>` styled `flex items-center gap-3.5 rounded-card border border-border bg-surface px-4 py-3.5 transition-jobdun hover:border-border-strong`: `<Avatar url={row.avatarUrl} name={row.displayName} size={36}/>` + a flex-1 column { name row: `t-title-md text-text1` + (row.isVerified ? a `SealCheck` `text-action-ink` 14px); role: `t-eyebrow text-text3` uppercase } + right: created date `t-body-sm text-text2` (`fmtDate` = "d MMM yyyy").

- [ ] **`paginator.tsx`**: prev/next. Build hrefs preserving `role`/`q` with `page-1`/`page+1`. Prev disabled when `page<=1`; Next disabled when `!hasMore`. Render as `Button variant="secondary" size="sm"` links (or disabled spans). Show "Page {page}".

- [ ] **`app/(admin)/users/page.tsx`** (Server Component):

```tsx
import { getUsersPage } from "@/lib/data/users-queries";
import type { RoleFilter } from "@/lib/data/users";
import { UserFilters } from "@/components/admin/users/user-filters";
import { UserRow } from "@/components/admin/users/user-row";
import { Paginator } from "@/components/admin/users/paginator";
import { EmptyState } from "@/components/ui/empty-state";
import { UsersThree } from "@phosphor-icons/react/dist/ssr";

export const dynamic = "force-dynamic";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ role?: string; q?: string; page?: string }>;
}) {
  const sp = await searchParams;
  const role = (["all", "builder", "trade", "admin"].includes(sp.role ?? "") ? sp.role : "all") as RoleFilter;
  const q = sp.q ?? "";
  const page = Math.max(1, Number(sp.page) || 1);
  const { rows, hasMore } = await getUsersPage({ role, q, page });

  return (
    <div className="flex flex-col gap-6">
      <UserFilters role={role} q={q} />
      {rows.length === 0 ? (
        <EmptyState icon={UsersThree} headline="No users match." hint="Try a different filter or search term." />
      ) : (
        <>
          <div className="flex flex-col gap-2">
            {rows.map((r) => (
              <UserRow key={r.id} row={r} />
            ))}
          </div>
          <Paginator role={role} q={q} page={page} hasMore={hasMore} />
        </>
      )}
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/users/page.tsx" components/admin/users/{user-filters,user-row,paginator}.tsx`. NO commit, NO build (concurrent agent). Tokens only; Phosphor (`SealCheck`, `UsersThree`, `CaretLeft`, `CaretRight`, `MagnifyingGlass`).

---

## Task 4: The detail  *(Stage B — agent #2)*

**Files:** `user-header.tsx`, `profile-card.tsx`, `builder-card.tsx`, `trade-card.tsx`, `verifications-card.tsx`, `moderation-card.tsx`, `app/(admin)/users/[id]/page.tsx`.

All cards: a P0 `Card` with a `CardTitle`-style eyebrow label (`t-eyebrow text-text3` + mb-3), then `KVRow`s (P0) for each present field. Helper `fmtDate` = "d MMM yyyy", `fmtDateTime` = "d MMM yyyy · HH:mm". Each row omitted when the value is null. Card empty fallback text (`t-body-sm text-text3`) where the recon specifies it.

- [ ] **`user-header.tsx`**: `flex items-center gap-4`: `<Avatar size={72} …/>` + column { name row: `t-headline-sm text-text1` + (trade?.isVerified ? `SealCheck text-verified` 18px) + (deletedAt ? a `StatusTag tone="rejected"` "DELETED"); role pill: `inline-block rounded-badge bg-surface-raised px-2 py-0.5 t-eyebrow text-text2` = role.toUpperCase(); `ID: {id}` (`t-eyebrow text-text3`); `Joined {fmtDate(createdAt)}` (`t-eyebrow text-text3`) }.

- [ ] **`profile-card.tsx`** "PROFILE": KVRows (omit null): Phone (value + `SealCheck text-verified` 14px if `phoneVerifiedAt`), Licence URL (an `<a target=_blank>` `text-action-ink underline`), Last updated (`fmtDateTime(updatedAt)`). If phone+licenceUrl+updatedAt all null → "No additional profile data."

- [ ] **`builder-card.tsx`** "BUILDER PROFILE" (only rendered by the page when role builder + builder present): KVRows (omit null): Company (companyName), ABN, Contact Name, Contact Phone, Years in Business (string), Service Area (`locationLine([serviceSuburb, serviceState, servicePostcode])`), Website (link), About.

- [ ] **`trade-card.tsx`** "TRADE PROFILE" + (isVerified ? a `VERIFIED` badge: `SealCheck text-verified` + "VERIFIED" `t-eyebrow text-verified-tx`): KVRows (omit null): Full Name, Primary Trade, Years Experience (string), Hourly Rate (`$${hourlyRate.toFixed(2)}/hr` if not null), Base Location (`locationLine([baseSuburb, baseState, basePostcode])`), Portfolio URLs (`${portfolioUrls.length} item(s)` if non-empty), About.

- [ ] **`verifications-card.tsx`** "VERIFICATIONS": if empty → "No verifications on record." Else per verification: a row with kind.toUpperCase() (`t-label text-text1`) + a status pill — reuse P0 `StatusTag` mapping `verified→verified`, `failed→rejected`, `pending→pending`, else `neutral` (StatusTag tones are `verified|rejected|pending|info|neutral`); below, failureReason (`t-body-sm text-urgent-tx`) if present, and `Updated {fmtDate(updatedAt)}` (`t-eyebrow text-text3`) if present.

- [ ] **`moderation-card.tsx`** (`"use client"`) "MODERATION": a status tag `Account: {userStatus.toUpperCase()}` (`StatusTag` tone: active→verified, suspended→pending, banned→rejected). Buttons (in a `useTransition`): REACTIVATE (`Button` primary, if status≠"active"), SUSPEND (`Button variant="secondary"`, if ≠"suspended"), BAN (`Button variant="danger"`, if ≠"banned") — each calls `setUserStatus({ userId, status })`; on `{error}` show it (`t-body-sm text-urgent-tx`); on success the `revalidatePath` refreshes the page. Disable all while pending.

- [ ] **`app/(admin)/users/[id]/page.tsx`** (Server Component):

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "@phosphor-icons/react/dist/ssr";
import { getUserDetail } from "@/lib/data/users-queries";
import { UserHeader } from "@/components/admin/users/user-header";
import { ProfileCard } from "@/components/admin/users/profile-card";
import { BuilderCard } from "@/components/admin/users/builder-card";
import { TradeCard } from "@/components/admin/users/trade-card";
import { VerificationsCard } from "@/components/admin/users/verifications-card";
import { ModerationCard } from "@/components/admin/users/moderation-card";

export const dynamic = "force-dynamic";

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const detail = await getUserDetail(id);
  if (!detail) notFound();

  return (
    <div className="flex flex-col gap-4">
      <Link href="/users" className="inline-flex w-fit items-center gap-2 rounded-btn px-2 py-1.5 t-eyebrow text-text2 hover:text-text1">
        <ArrowLeft size={16} aria-hidden /> BACK TO USERS
      </Link>
      <UserHeader detail={detail} />
      <ProfileCard detail={detail} />
      {detail.role === "builder" && detail.builder ? <BuilderCard builder={detail.builder} /> : null}
      {detail.role === "trade" && detail.trade ? <TradeCard trade={detail.trade} /> : null}
      <VerificationsCard verifications={detail.verifications} />
      <ModerationCard userId={detail.id} status={detail.userStatus} />
    </div>
  );
}
```

- [ ] Self-check `npx eslint "app/(admin)/users/[id]" components/admin/users/{user-header,profile-card,builder-card,trade-card,verifications-card,moderation-card}.tsx`. NO commit, NO build. Tokens only; em-dash-free prose; Phosphor (`ArrowLeft`, `SealCheck`). Reuse P0 `Card`/`KVRow`/`Button`/`StatusTag`.

---

## Task 5: Integrate, verify, deploy  *(Stage C)*

- [ ] Commit Stage B grouped (list; detail). `npm run test && npm run lint && npm run build` green; `/users` + `/users/[id]` are `ƒ`. Token audit over `lib/data/users.ts lib/data/users-queries.ts lib/actions/users.ts components/admin/users "app/(admin)/users"` = none.
- [ ] **Live verify vs the real 8 users** (authed Playwright): log in, screenshot `/users` (the list of real users), click the first row → screenshot `/users/[id]` (real profile + cards + moderation). Read screenshots; do NOT click SUSPEND/BAN (no prod mutations). Revert any throwaway script.
- [ ] Commit, push, `vercel deploy --prod`. Live gate holds.

---

## Done-When
- `/users` lists the real users (role chips filter, display-name search, 50/page prev-next), each row links to detail; `/users/[id]` shows header + profile + role-gated subprofile + verifications + a **working** moderation card (reactivate/suspend/ban via `admin_set_user_status`).
- Build/lint/test green; token-pure; verified against the real 8 users; deployed.
