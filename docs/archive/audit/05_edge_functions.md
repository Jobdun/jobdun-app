# Edge Functions Audit — Jobdun Backend

**Auditor:** edge-functions-auditor
**Scope:** Every Supabase Edge Function (`supabase/functions/`); secret handling, input validation, error handling, structured logging, rate limiting, idempotency, timeouts, CORS, service-role usage, webhook signature verification.
**Files reviewed:**
- `supabase/` (directory listing — `functions/` absent, verified via `ls`)
- `supabase/migrations/20260511000001_initial_schema.sql` (profiles, user_roles, builder/trade_profiles)
- `supabase/migrations/20260511000002_jobs.sql` (jobs, enums, counters)
- `supabase/migrations/20260511000004_messaging.sql` (conversations, messages)
- `supabase/migrations/20260511000005_social.sql` (notifications, verification_documents, reviews)
- `supabase/migrations/20260511000006_rls.sql` (RLS / role patterns)
- `supabase/migrations/20260511000008_custom_access_token_hook.sql` (JWT `user_role` claim)
- `supabase/migrations/20260512000001_legal_acceptances.sql` (immutable consent trail; admin-read pattern)
- `lib/` grep for `service_role`/FCM/device-token (0 hits — no client device-token path)
**Date:** 2026-05-16

---

## Summary

| Severity | Count |
|---|---|
| P0 | 2 |
| P1 | 4 |
| P2 | 2 |
| P3 | 1 |

**Overall: 🔴 RED.**

`supabase/functions/` **does not exist** — there are **zero Edge Functions** in the repo (verified: `ls /Users/kuya/Documents/Jobdun/supabase/functions/` → `No such file or directory`). Every privileged server-side operation Jobdun needs is therefore MISSING. The single most serious finding is **F-EDGE-01**: there is no admin-gated path for approving verification documents, suspending users, or moderating content — these are present-tense authorization gaps, not future work, because the JWT `user_role='admin'` claim exists but nothing consumes it server-side. The Privacy Act 1988 access/erasure obligations (APP 12 / APP 13) also have **no implementation** (F-EDGE-04, F-EDGE-05). The remainder are "design & build before Phase 3 scale" gaps for which complete paste-ready Deno/TypeScript skeletons are provided below.

> **Architectural note:** Jobdun's admin surface is a *separate web app* (per `CLAUDE.md`), and the Flutter app deliberately has no admin UI. That makes Edge Functions the **only** legitimate home for the service-role key and the only place admin authorization can be enforced. The absence of these functions means the admin web app today would either (a) not exist, or (b) be talking to Postgres with a service-role key directly — both unacceptable at 25k AU users. Confirm with Ken which (Open Questions).

---

## Findings

### F-EDGE-01 — No admin-gated server path exists for verification approval / suspension / moderation
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** `supabase/functions/` not present in repo. `verification_documents.status` (`supabase/migrations/20260511000005_social.sql:32`) defaults to `'pending'` with no server-side actor able to legitimately move it to `'approved'`. `user_roles` admits `role = 'admin'` (`20260511000001_initial_schema.sql:21`) and the JWT hook injects `user_role` (`20260511000008_custom_access_token_hook.sql:35`), but **no Edge Function reads that claim** — the admin claim is currently unenforced anywhere server-side.
- **Why it matters at 25k AU users:** Trades cannot work until verification is approved; with no admin Edge Function the only ways to approve are (a) a human running SQL in the Supabase dashboard, or (b) an admin web app holding the service-role key — which bypasses RLS entirely and is a catastrophic key-exposure / insider-risk surface. At 25k accounts and a solo engineer, manual SQL approval is operationally impossible and unauditable; service-role-from-web is a P0 data-breach waiting to happen. There is no `moderation_audit_log`, so no defensible record of who approved/suspended whom (Privacy Act accountability, APP 1).
- **Fix (concrete):** Create the three admin Edge Functions below (`admin-approve-verification`, `suspend-user`, `report-content`) plus a backing migration `supabase/migrations/20260516000001_moderation_core.sql` adding `reports`, `user_suspensions`, `moderation_audit_log`, and an `expires_at` column on `verification_documents`. Every admin function MUST: verify the caller's JWT, assert `user_role === 'admin'` from the verified token (never trust a body field), use the service-role client only *after* the admin check, write a `moderation_audit_log` row in the same transaction-equivalent flow, and emit a structured log line. Skeletons in the Cross-cutting section.
- **Effort:** L
- **Phase:** 0 (the admin-gating gap is present-tense; ship before any admin web app is wired)
- **Layman's:** There is no safe, logged way for an admin to approve a tradie's licence or ban a bad actor — today it would require risky manual database access.

---

### F-EDGE-02 — No FCM/push delivery function and no device-token data model
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent. `grep` of `lib/` and `supabase/migrations/` for `fcm|device_token|push_token|messaging()` → 0 hits. `notifications` table exists (`20260511000005_social.sql:5`) but is in-app only — nothing pushes to a device.
- **Why it matters at 25k AU users:** A job marketplace where a builder shortlists a tradie but the tradie never gets a push notification will bleed engagement, especially on rural-AU 3G where the app is rarely foregrounded. Without a token table and a server-side FCM wrapper, every notification is silent until the user manually opens the app. FCM legacy keys are also being deprecated by Google — a wrapper centralises the HTTP v1 OAuth flow and token-rotation/`UNREGISTERED` cleanup in one auditable place.
- **Fix (concrete):** Add migration `supabase/migrations/20260516000002_device_tokens.sql` (`device_tokens(user_id, token, platform, last_seen_at, created_at)` with RLS so users manage only their own tokens) and the `send-push` Edge Function (skeleton below) using FCM HTTP v1 + a Google service-account JWT minted from `Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")`. On a `404 UNREGISTERED`/`NOT_FOUND` response, delete the dead token row (rotation).
- **Effort:** M
- **Phase:** 2
- **Layman's:** The app can't send phone notifications at all — there's no code or storage for device push tokens.

---

### F-EDGE-03 — No content moderation / keyword-scan function on job post & message send
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent. `jobs` (`20260511000002_jobs.sql`) and `messages` (`20260511000004_messaging.sql`) have no moderation hook, no `flagged`/`hidden` column, no profanity/PII/scam screening. No `reports` table (per `00_SCOPE.md §2`).
- **Why it matters at 25k AU users:** Construction-trade marketplaces are a known target for off-platform payment scams ("pay a deposit to this account"), recruitment fraud, and abusive messages. With 200k+ messages and 10k+ jobs projected and a solo engineer, manual review is impossible; an automated keyword/regex scan that flags-for-review (not hard-blocks) is the minimum viable trust-and-safety control. Australian platforms also carry duties under the Online Safety Act for harmful content takedown timelines.
- **Fix (concrete):** Add `moderation-keyword-scan` Edge Function (skeleton below) invoked by the client immediately after a successful job/message insert (or, preferably Phase 3, by a Postgres `AFTER INSERT` trigger calling `pg_net` → the function). It scores against a keyword/regex set, and on hit inserts a `reports` row with `source='auto'` and (for jobs) sets a `jobs.flagged_at`. Pair with the `reports` table from F-EDGE-01's migration.
- **Effort:** M
- **Phase:** 3
- **Layman's:** Nothing scans new job ads or messages for scams or abuse before a human sees them.

---

### F-EDGE-04 — No APP 12 "export my data" function
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent. No `data_export_requests` table (per `00_SCOPE.md §2`). No export path in `lib/`.
- **Why it matters at 25k AU users:** Australian Privacy Principle 12 gives every individual a right of access to their personal information, and the entity must respond within a reasonable period (OAIC guidance: 30 days). At 25k AU users a manual export by a solo engineer is not scalable and risks non-compliance fines. The data is spread across `profiles`, `builder_profiles`/`trade_profiles`, `jobs`, `applications`, `messages`, `reviews`, `verification_documents`, `legal_acceptances` — only a server function with controlled read scope can assemble a complete, authenticated export safely.
- **Fix (concrete):** `export-my-data` Edge Function (skeleton below): authenticates the caller, reads *only their own* rows across the relevant tables (using the user-scoped client so RLS still applies, plus service-role only for cross-table joins the caller legitimately owns), returns a single JSON document, and writes a `data_export_requests` audit row. Throttle to 1 export / 24h / user via the rate-limit helper.
- **Effort:** M
- **Phase:** 2
- **Layman's:** There's no way for a user to download a copy of all their data, which Australian privacy law requires.

---

### F-EDGE-05 — No APP 13 "delete my account" / anonymisation function
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent. No delete/anonymisation flow (per `00_SCOPE.md §2`). FK cascades exist (`ON DELETE CASCADE` on `profiles.id` → child tables) but a raw `auth.users` delete would also destroy the **immutable** `legal_acceptances` consent trail (`20260512000001_legal_acceptances.sql:6`, `ON DELETE CASCADE`) and any future moderation trail — destroying legal-defensibility evidence.
- **Why it matters at 25k AU users:** APP 13 requires correction/handling of personal information and users expect a "delete my account" button. A naive cascade delete is *destructive of evidence* needed for fraud disputes, chargeback defence, and legal claims, and irrecoverably loses the consent record proving the user agreed to the Terms. The correct pattern is **anonymise PII, preserve the moderation/consent trail**: null/scramble names, emails, avatars, message bodies; keep the `user_id` skeleton + `legal_acceptances` + any `reports`/suspensions. This must be a single server-side transaction-like flow — impossible from the client.
- **Fix (concrete):** `delete-my-account` Edge Function (skeleton below): authenticates caller, requires an `Idempotency-Key` header, anonymises PII across owned tables, redacts message bodies to `'[deleted]'`, sets `profiles.deleted_at`-equivalent (add column in migration `20260516000003_account_deletion.sql` adding `profiles.deleted_at`, `profiles.anonymised_at`), **does not** delete `legal_acceptances`/`reports`/`moderation_audit_log`, then disables the auth user (`auth.admin.updateUserById` ban / sign-out) rather than hard-deleting. Writes a `moderation_audit_log` row `action='account_anonymised'`.
- **Effort:** L
- **Phase:** 1
- **Layman's:** Deleting an account today would either be impossible or would wipe the legal proof that the user agreed to the terms — both bad.

---

### F-EDGE-06 — No scheduled licence-expiry notification function (and no `expires_at` data model)
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent. `verification_documents` (`20260511000005_social.sql:27-35`) has **no `expires_at` column** — there is no data to schedule against. No `supabase/config.toml` cron / pg_cron schedule.
- **Why it matters at 25k AU users:** White Cards and trade licences expire; an expired tradie working through Jobdun is a compliance and liability problem for builders and the platform. At scale you cannot manually track 25k users' licence dates. But this is correctly P2 because the *data model itself is missing* — it cannot break today since the feature doesn't exist; it must be designed before Phase 3.
- **Fix (concrete):** Migration `20260516000004_doc_expiry.sql` adds `verification_documents.expires_at timestamptz` + an index `(expires_at) WHERE status='approved'`. Schedule `notify-licence-expiring` via `supabase/config.toml` cron (or pg_cron + `pg_net`) running daily; it selects docs expiring in exactly 30/7/1 days and inserts `notifications` rows (and calls `send-push` once F-EDGE-02 exists). Skeleton below.
- **Effort:** M
- **Phase:** 3
- **Layman's:** No reminder system exists to tell tradies their licence is about to expire (and there's nowhere to even store the expiry date yet).

---

### F-EDGE-07 — No per-user/IP/route rate limiting primitive for any privileged endpoint
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent; no rate-limit table or KV (per `00_SCOPE.md §2`, "No rate-limit table / KV"). Supabase Pro does not bundle an Edge KV; rate limiting must be implemented.
- **Why it matters at 25k AU users:** Without rate limiting, the `report-content`, `export-my-data`, `send-push`, and any future auth-adjacent functions are abusable for spam, data-exfil hammering, and FCM-cost amplification. A single malicious account could trigger thousands of exports or report-floods. At 25k AU users on Supabase Pro (limited Edge invocations & DB connections) this is both a cost and an availability risk.
- **Fix (concrete):** Add migration `20260516000005_rate_limits.sql` (`rate_limit_events(bucket text, subject text, window_start timestamptz, count int, PRIMARY KEY (bucket, subject, window_start))`) and a shared `_shared/rateLimit.ts` helper (fixed-window counter using `INSERT … ON CONFLICT … DO UPDATE SET count = count + 1` then compare). Every state-changing/expensive function calls it first and returns `429` with `Retry-After` on breach. Helper provided below.
- **Effort:** S
- **Phase:** 1
- **Layman's:** Nothing stops a bad actor from hammering the server thousands of times a minute.

---

### F-EDGE-08 — No shared CORS / structured-logging / error-shape convention
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent — no `_shared/` directory, no logging convention, no CORS config.
- **Why it matters at 25k AU users:** When functions do get built piecemeal by a solo engineer, inconsistent error shapes leak internal state (stack traces, Postgres error text containing column names) to clients, and unstructured logs make incident triage impossible at 500 DAU. Edge Functions are publicly reachable; missing/over-broad CORS either breaks the app or allows hostile origins.
- **Fix (concrete):** Ship a `_shared/` module first (`cors.ts`, `log.ts`, `respond.ts`, `auth.ts`) with: a strict CORS allowlist (the app's origin + Supabase), a `log()` emitting `{request_id,user_id,route,latency_ms,outcome}` JSON to `console.log` (Supabase ships these to Logs), and a `fail()` that returns a sanitised `{ error: { code, message } }` (never the raw exception). All skeletons below import from `_shared/`.
- **Effort:** S
- **Phase:** 1
- **Layman's:** There's no shared "house style" so each function would leak errors and log inconsistently.

---

### F-EDGE-09 — No `verify_jwt`/`config.toml` per-function auth declaration or webhook signature verification plan
- **Severity:** P3
- **Status:** MISSING
- **Evidence:** `supabase/functions/` absent; `supabase/config.toml` has no `[functions.*]` blocks (config is local-dev only per `00_SCOPE.md §3`). No webhook (Stripe/FCM-delivery-receipt) signature verification exists because no functions exist.
- **Why it matters at 25k AU users:** Scheduled functions (`notify-licence-expiring`) and any future inbound webhooks must NOT use the default `verify_jwt = true` (a cron caller has no user JWT) — instead they need a shared-secret header check. Getting this wrong either bricks the cron or opens an unauthenticated trigger. Low severity only because nothing is shipped yet.
- **Fix (concrete):** In `supabase/config.toml`, declare per-function auth, e.g. `[functions.notify-licence-expiring] verify_jwt = false`, and have that function require a `x-cron-secret` header matching `Deno.env.get("CRON_SECRET")`. Any future delivery-receipt webhook must HMAC-verify the provider signature before processing. Pattern shown in `notify-licence-expiring` skeleton.
- **Effort:** XS
- **Phase:** 1
- **Layman's:** When scheduled/automated functions exist they'll need a password-style header, which isn't planned yet.

---

## Cross-cutting recommendations

Build the `_shared/` foundation **first**, then functions in Phase order: admin trio (Phase 0) → delete-account (Phase 1) → export + push (Phase 2) → moderation + licence-expiry (Phase 3). All skeletons below are paste-ready Deno/TypeScript targeting Supabase Edge Runtime (Deno) with `zod` for input validation. They assume:

```
supabase/functions/
  _shared/{cors.ts,log.ts,respond.ts,auth.ts,rateLimit.ts}
  admin-approve-verification/index.ts
  suspend-user/index.ts
  report-content/index.ts
  export-my-data/index.ts
  delete-my-account/index.ts
  notify-licence-expiring/index.ts
  send-push/index.ts
  moderation-keyword-scan/index.ts
```

### Required migrations (write before/with the functions)

```
supabase/migrations/20260516000001_moderation_core.sql       -- reports, user_suspensions, moderation_audit_log, verification_documents.reviewed_by/reviewed_at, jobs.flagged_at
supabase/migrations/20260516000002_device_tokens.sql          -- device_tokens (+ RLS)
supabase/migrations/20260516000003_account_deletion.sql       -- profiles.deleted_at, profiles.anonymised_at
supabase/migrations/20260516000004_doc_expiry.sql             -- verification_documents.expires_at (+ partial index)
supabase/migrations/20260516000005_rate_limits.sql            -- rate_limit_events
supabase/migrations/20260516000006_data_export_requests.sql   -- data_export_requests audit table
```

### `_shared/cors.ts`

```ts
// supabase/functions/_shared/cors.ts
const ALLOWED = new Set<string>([
  "https://admin.jobdun.app",        // admin web app (confirm origin with Ken)
  "app://jobdun",                    // Flutter app custom scheme (if used)
]);

export function corsHeaders(origin: string | null): HeadersInit {
  const allow = origin && ALLOWED.has(origin) ? origin : "null";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, idempotency-key, x-cron-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req.headers.get("origin")) });
  }
  return null;
}
```

### `_shared/log.ts`

```ts
// supabase/functions/_shared/log.ts
export interface LogCtx {
  request_id: string;
  user_id: string | null;
  route: string;
  started: number;
}

export function newCtx(route: string): LogCtx {
  return { request_id: crypto.randomUUID(), user_id: null, route, started: Date.now() };
}

export function log(
  ctx: LogCtx,
  outcome: "ok" | "client_error" | "auth_error" | "rate_limited" | "server_error",
  extra: Record<string, unknown> = {},
) {
  // Supabase forwards console output to Logs Explorer; emit one JSON line.
  console.log(JSON.stringify({
    request_id: ctx.request_id,
    user_id: ctx.user_id,
    route: ctx.route,
    latency_ms: Date.now() - ctx.started,
    outcome,
    ...extra,
  }));
}
```

### `_shared/respond.ts`

```ts
// supabase/functions/_shared/respond.ts
import { corsHeaders } from "./cors.ts";

export function ok(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req.headers.get("origin")), "content-type": "application/json" },
  });
}

// NEVER pass a raw exception/message from Postgres to the client.
export function fail(
  req: Request,
  status: number,
  code: string,
  message: string,
  retryAfter?: number,
): Response {
  const headers: Record<string, string> = {
    ...corsHeaders(req.headers.get("origin")) as Record<string, string>,
    "content-type": "application/json",
  };
  if (retryAfter) headers["Retry-After"] = String(retryAfter);
  return new Response(JSON.stringify({ error: { code, message } }), { status, headers });
}
```

### `_shared/auth.ts`

```ts
// supabase/functions/_shared/auth.ts
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // ONLY ever read here, in Edge

export interface Caller { id: string; role: string; jwt: string; }

/** Verifies the bearer token by asking GoTrue; returns the trusted user + role claim. */
export async function requireUser(req: Request): Promise<Caller> {
  const authz = req.headers.get("authorization") ?? "";
  const jwt = authz.replace(/^Bearer\s+/i, "");
  if (!jwt) throw { status: 401, code: "no_token", message: "Missing bearer token." };

  const userClient = createClient(URL, ANON, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) {
    throw { status: 401, code: "bad_token", message: "Invalid or expired token." };
  }
  // Role comes from the verified JWT claim injected by custom_access_token hook.
  const role = (data.user.app_metadata?.user_role ??
    (data.user as unknown as { user_metadata?: { user_role?: string } })
      .user_metadata?.user_role ?? "trade") as string;
  return { id: data.user.id, role, jwt };
}

export async function requireAdmin(req: Request): Promise<Caller> {
  const c = await requireUser(req);
  if (c.role !== "admin") {
    throw { status: 403, code: "not_admin", message: "Admin role required." };
  }
  return c;
}

/** Service-role client. Edge Functions are the ONLY legitimate place for this key. */
export function serviceClient(): SupabaseClient {
  return createClient(URL, SERVICE, { auth: { persistSession: false } });
}

/** User-scoped client — RLS still applies; use for owned-data reads/writes. */
export function userClient(jwt: string): SupabaseClient {
  return createClient(URL, ANON, { global: { headers: { Authorization: `Bearer ${jwt}` } } });
}
```

### `_shared/rateLimit.ts`

```ts
// supabase/functions/_shared/rateLimit.ts
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/** Fixed-window limiter backed by rate_limit_events (migration 20260516000005). */
export async function enforceRateLimit(
  svc: SupabaseClient,
  bucket: string,        // e.g. "export-my-data"
  subject: string,       // e.g. user id or ip
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const now = Date.now();
  const windowStart = new Date(now - (now % (windowSeconds * 1000))).toISOString();

  const { data, error } = await svc.rpc("increment_rate_limit", {
    p_bucket: bucket, p_subject: subject, p_window_start: windowStart,
  });
  if (error) {
    // Fail-closed for state changes is safer; fail-open here would defeat the limiter.
    throw { status: 503, code: "rate_limit_unavailable", message: "Try again shortly." };
  }
  if ((data as number) > limit) {
    throw { status: 429, code: "rate_limited", message: "Too many requests.", retryAfter: windowSeconds };
  }
}
// Companion SQL (in migration 20260516000005):
//   CREATE FUNCTION increment_rate_limit(p_bucket text, p_subject text, p_window_start timestamptz)
//   RETURNS int LANGUAGE sql AS $$
//     INSERT INTO rate_limit_events (bucket, subject, window_start, count)
//     VALUES (p_bucket, p_subject, p_window_start, 1)
//     ON CONFLICT (bucket, subject, window_start)
//     DO UPDATE SET count = rate_limit_events.count + 1
//     RETURNING count;
//   $$;
```

---

### 1) `admin-approve-verification/index.ts`

```ts
// supabase/functions/admin-approve-verification/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireAdmin, serviceClient } from "../_shared/auth.ts";
import { enforceRateLimit } from "../_shared/rateLimit.ts";

const Body = z.object({
  document_id: z.string().uuid(),
  decision: z.enum(["approved", "rejected"]),
  reason: z.string().max(500).optional(),
});

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("admin-approve-verification");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const admin = await requireAdmin(req);
    ctx.user_id = admin.id;

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Invalid body."); }
    const { document_id, decision, reason } = parsed.data;

    const svc = serviceClient();
    await enforceRateLimit(svc, "admin-approve", admin.id, 120, 60);

    const { data: doc, error: readErr } = await svc
      .from("verification_documents")
      .select("id, trade_id, status, type")
      .eq("id", document_id).single();
    if (readErr || !doc) { log(ctx, "client_error"); return fail(req, 404, "not_found", "Document not found."); }
    if (doc.status !== "pending") {
      log(ctx, "client_error"); return fail(req, 409, "already_decided", "Document is not pending.");
    }

    const { error: updErr } = await svc.from("verification_documents")
      .update({ status: decision, reviewed_by: admin.id, reviewed_at: new Date().toISOString() })
      .eq("id", document_id).eq("status", "pending"); // optimistic guard
    if (updErr) { log(ctx, "server_error"); return fail(req, 500, "update_failed", "Could not update."); }

    // If approved and this completes the trade's required set, you may flip
    // trade_profiles.is_verified — left as an explicit business rule (Open Q).

    await svc.from("moderation_audit_log").insert({
      actor_id: admin.id, action: `verification_${decision}`,
      target_type: "verification_document", target_id: document_id,
      detail: { trade_id: doc.trade_id, type: doc.type, reason: reason ?? null },
    });

    await svc.from("notifications").insert({
      user_id: doc.trade_id,
      type: decision === "approved" ? "verification_approved" : "verification_rejected",
      title: decision === "approved" ? "Verification approved" : "Verification needs attention",
      body: decision === "approved"
        ? "Your document was approved. You can now apply for jobs."
        : `Your document was not approved.${reason ? " Reason: " + reason : ""}`,
      data: { document_id, type: doc.type },
    });

    log(ctx, "ok", { decision });
    return ok(req, { document_id, status: decision });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    log(ctx, err.status === 403 || err.status === 401 ? "auth_error" : "server_error",
        { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.");
  }
});
```

### 2) `suspend-user/index.ts`

```ts
// supabase/functions/suspend-user/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireAdmin, serviceClient } from "../_shared/auth.ts";

const Body = z.object({
  target_user_id: z.string().uuid(),
  action: z.enum(["suspend", "reinstate"]),
  reason: z.string().min(3).max(500),
  until: z.string().datetime().optional(), // omit = indefinite
});

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("suspend-user");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const admin = await requireAdmin(req);
    ctx.user_id = admin.id;

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Invalid body."); }
    const { target_user_id, action, reason, until } = parsed.data;
    if (target_user_id === admin.id) {
      log(ctx, "client_error"); return fail(req, 400, "self_target", "Cannot suspend yourself.");
    }

    const svc = serviceClient();

    if (action === "suspend") {
      await svc.from("user_suspensions").insert({
        user_id: target_user_id, reason, suspended_by: admin.id,
        suspended_until: until ?? null, active: true,
      });
      // Revoke sessions: ban the auth user so existing refresh tokens stop working.
      await svc.auth.admin.updateUserById(target_user_id, {
        ban_duration: until ? undefined : "876000h", // ~100y = effectively indefinite
      });
      await svc.auth.admin.signOut(target_user_id, "global").catch(() => {});
    } else {
      await svc.from("user_suspensions")
        .update({ active: false, reinstated_by: admin.id, reinstated_at: new Date().toISOString() })
        .eq("user_id", target_user_id).eq("active", true);
      await svc.auth.admin.updateUserById(target_user_id, { ban_duration: "none" });
    }

    await svc.from("moderation_audit_log").insert({
      actor_id: admin.id, action: `user_${action}`,
      target_type: "user", target_id: target_user_id,
      detail: { reason, until: until ?? null },
    });

    log(ctx, "ok", { action });
    return ok(req, { target_user_id, action });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    log(ctx, err.status === 403 || err.status === 401 ? "auth_error" : "server_error", { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.");
  }
});
```

### 3) `report-content/index.ts`

```ts
// supabase/functions/report-content/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireUser, serviceClient } from "../_shared/auth.ts";
import { enforceRateLimit } from "../_shared/rateLimit.ts";

const Body = z.object({
  target_type: z.enum(["job", "message", "profile", "review"]),
  target_id: z.string().uuid(),
  reason: z.enum(["scam", "abuse", "spam", "off_platform_payment", "other"]),
  detail: z.string().max(1000).optional(),
});

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("report-content");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const user = await requireUser(req);
    ctx.user_id = user.id;

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Invalid body."); }

    const svc = serviceClient();
    await enforceRateLimit(svc, "report-content", user.id, 20, 3600); // 20/hr/user

    const { target_type, target_id, reason, detail } = parsed.data;
    const { data, error } = await svc.from("reports").insert({
      reporter_id: user.id, target_type, target_id, reason,
      detail: detail ?? null, source: "user", status: "open",
    }).select("id").single();
    if (error) { log(ctx, "server_error"); return fail(req, 500, "insert_failed", "Could not file report."); }

    log(ctx, "ok", { target_type, reason });
    return ok(req, { report_id: data.id, status: "open" }, 201);
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string; retryAfter?: number };
    log(ctx, err.status === 401 ? "auth_error" : err.status === 429 ? "rate_limited" : "server_error",
        { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.",
                err.retryAfter);
  }
});
```

### 4) `export-my-data/index.ts`  (APP 12)

```ts
// supabase/functions/export-my-data/index.ts
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireUser, serviceClient } from "../_shared/auth.ts";
import { enforceRateLimit } from "../_shared/rateLimit.ts";

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("export-my-data");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const user = await requireUser(req);
    ctx.user_id = user.id;

    const svc = serviceClient();
    await enforceRateLimit(svc, "export-my-data", user.id, 1, 86400); // 1 / 24h

    const uid = user.id;
    const [profile, builder, trade, jobs, apps, msgs, reviews, docs, legal] = await Promise.all([
      svc.from("profiles").select("*").eq("id", uid).maybeSingle(),
      svc.from("builder_profiles").select("*").eq("id", uid).maybeSingle(),
      svc.from("trade_profiles").select("*").eq("id", uid).maybeSingle(),
      svc.from("jobs").select("*").eq("builder_id", uid),
      svc.from("applications").select("*").eq("trade_id", uid),
      svc.from("messages").select("*").eq("sender_id", uid),
      svc.from("reviews").select("*").or(`reviewer_id.eq.${uid},reviewee_id.eq.${uid}`),
      svc.from("verification_documents").select("*").eq("trade_id", uid),
      svc.from("legal_acceptances").select("*").eq("user_id", uid),
    ]);

    const bundle = {
      generated_at: new Date().toISOString(),
      user_id: uid,
      profile: profile.data, builder_profile: builder.data, trade_profile: trade.data,
      jobs: jobs.data ?? [], applications: apps.data ?? [], messages: msgs.data ?? [],
      reviews: reviews.data ?? [], verification_documents: docs.data ?? [],
      legal_acceptances: legal.data ?? [],
    };

    await svc.from("data_export_requests").insert({
      user_id: uid, fulfilled_at: new Date().toISOString(), byte_size: JSON.stringify(bundle).length,
    });

    log(ctx, "ok");
    return ok(req, bundle);
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string; retryAfter?: number };
    log(ctx, err.status === 401 ? "auth_error" : err.status === 429 ? "rate_limited" : "server_error",
        { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.",
                err.retryAfter);
  }
});
```

### 5) `delete-my-account/index.ts`  (APP 13 — anonymise, preserve moderation/consent trail)

```ts
// supabase/functions/delete-my-account/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireUser, serviceClient } from "../_shared/auth.ts";

const Body = z.object({ confirm: z.literal("DELETE") });

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("delete-my-account");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const user = await requireUser(req);
    ctx.user_id = user.id;

    const idemKey = req.headers.get("idempotency-key");
    if (!idemKey) return fail(req, 400, "no_idempotency", "Idempotency-Key header required.");

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Must confirm with 'DELETE'."); }

    const svc = serviceClient();
    const uid = user.id;

    // Idempotency: if already anonymised, return success without redoing work.
    const { data: existing } = await svc.from("profiles")
      .select("anonymised_at").eq("id", uid).maybeSingle();
    if (existing?.anonymised_at) { log(ctx, "ok", { idempotent: true }); return ok(req, { status: "already_deleted" }); }

    const stamp = new Date().toISOString();

    // 1. Anonymise PII (do NOT delete — preserves FK skeleton + audit/consent).
    await svc.from("profiles").update({
      display_name: "Deleted user", avatar_url: null,
      deleted_at: stamp, anonymised_at: stamp,
    }).eq("id", uid);
    await svc.from("builder_profiles").update({
      company_name: null, abn: null, logo_url: null, description: null,
    }).eq("id", uid);
    await svc.from("trade_profiles").update({
      full_name: null, bio: null, portfolio_urls: null,
      hourly_rate: null, day_rate: null,
    }).eq("id", uid);

    // 2. Redact message bodies the user sent (keep row for the other party's thread).
    await svc.from("messages").update({ body: "[deleted]" }).eq("sender_id", uid);

    // 3. PRESERVE: legal_acceptances, reports, user_suspensions, moderation_audit_log.

    // 4. Disable the auth user (revoke sessions) — NOT a hard delete.
    await svc.auth.admin.updateUserById(uid, { ban_duration: "876000h" });
    await svc.auth.admin.signOut(uid, "global").catch(() => {});

    // 5. Audit the erasure itself.
    await svc.from("moderation_audit_log").insert({
      actor_id: uid, action: "account_anonymised",
      target_type: "user", target_id: uid,
      detail: { idempotency_key: idemKey, at: stamp },
    });

    log(ctx, "ok");
    return ok(req, { status: "deleted" });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    log(ctx, err.status === 401 ? "auth_error" : err.status && err.status < 500 ? "client_error" : "server_error",
        { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.");
  }
});
```

### 6) `notify-licence-expiring/index.ts`  (scheduled — cron-secret, not JWT)

```ts
// supabase/functions/notify-licence-expiring/index.ts
// supabase/config.toml:  [functions.notify-licence-expiring]  verify_jwt = false
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/auth.ts";

const DAYS = [30, 7, 1];

Deno.serve(async (req) => {
  const ctx = newCtx("notify-licence-expiring");
  // Cron caller has no user JWT — authenticate with a shared secret instead.
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    log(ctx, "auth_error"); return fail(req, 401, "bad_cron_secret", "Unauthorised.");
  }

  try {
    const svc = serviceClient();
    let total = 0;
    for (const d of DAYS) {
      const lo = new Date(); lo.setUTCDate(lo.getUTCDate() + d); lo.setUTCHours(0, 0, 0, 0);
      const hi = new Date(lo); hi.setUTCHours(23, 59, 59, 999);

      const { data: docs } = await svc.from("verification_documents")
        .select("id, trade_id, type")
        .eq("status", "approved")
        .gte("expires_at", lo.toISOString())
        .lte("expires_at", hi.toISOString());

      for (const doc of docs ?? []) {
        await svc.from("notifications").insert({
          user_id: doc.trade_id, type: "licence_expiring",
          title: `Your ${doc.type} expires in ${d} day${d === 1 ? "" : "s"}`,
          body: "Renew and re-upload it to keep applying for jobs.",
          data: { document_id: doc.id, days_left: d },
        });
        total++;
        // Phase 2+: also invoke send-push for doc.trade_id.
      }
    }
    log(ctx, "ok", { notified: total });
    return ok(req, { notified: total });
  } catch (e) {
    log(ctx, "server_error");
    return fail(req, 500, "internal", "Unexpected error.");
  }
});
```

### 7) `send-push/index.ts`  (FCM HTTP v1 wrapper + token rotation)

```ts
// supabase/functions/send-push/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireAdmin, serviceClient } from "../_shared/auth.ts";

// Internal/admin-only invoker (or call from other Edge Functions with service auth).
const Body = z.object({
  user_id: z.string().uuid(),
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(400),
  data: z.record(z.string()).optional(),
});

async function fcmAccessToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!); // never hardcoded
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  };
  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claim)}`;
  const keyData = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8", Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...sig))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  return (await res.json()).access_token;
}

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("send-push");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const admin = await requireAdmin(req); // or service-to-service caller
    ctx.user_id = admin.id;

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Invalid body."); }
    const { user_id, title, body, data } = parsed.data;

    const svc = serviceClient();
    const { data: tokens } = await svc.from("device_tokens")
      .select("token").eq("user_id", user_id);
    if (!tokens?.length) { log(ctx, "ok", { sent: 0 }); return ok(req, { sent: 0 }); }

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!);
    const accessToken = await fcmAccessToken();
    let sent = 0;

    for (const { token } of tokens) {
      const r = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
          method: "POST",
          headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
          body: JSON.stringify({ message: { token, notification: { title, body }, data } }),
        });
      if (r.ok) { sent++; }
      else if (r.status === 404 || r.status === 400) {
        // UNREGISTERED / invalid → rotate the dead token out.
        await svc.from("device_tokens").delete().eq("token", token);
      }
    }
    log(ctx, "ok", { sent });
    return ok(req, { sent });
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    log(ctx, err.status === 401 || err.status === 403 ? "auth_error" : "server_error", { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.");
  }
});
```

### 8) `moderation-keyword-scan/index.ts`  (on job post & message send)

```ts
// supabase/functions/moderation-keyword-scan/index.ts
import { z } from "https://esm.sh/zod@3";
import { preflight } from "../_shared/cors.ts";
import { newCtx, log } from "../_shared/log.ts";
import { ok, fail } from "../_shared/respond.ts";
import { requireUser, serviceClient } from "../_shared/auth.ts";

const Body = z.object({
  target_type: z.enum(["job", "message"]),
  target_id: z.string().uuid(),
  text: z.string().min(1).max(8000),
});

// Tune for AU trades scams. Flag-for-review, never hard-block (false positives).
const PATTERNS: { label: string; re: RegExp }[] = [
  { label: "off_platform_payment", re: /\b(bsb|paypal|venmo|western union|crypto|bitcoin|gift card)\b/i },
  { label: "contact_leak", re: /\b(\+?61|0)4\d{2}\s?\d{3}\s?\d{3}\b|\b[\w.+-]+@[\w-]+\.[\w.-]+\b/ },
  { label: "scam", re: /\b(advance fee|processing fee|deposit first|pay to apply)\b/i },
  { label: "abuse", re: /\b(racial-slur-list-here)\b/i },
];

Deno.serve(async (req) => {
  const pf = preflight(req); if (pf) return pf;
  const ctx = newCtx("moderation-keyword-scan");
  if (req.method !== "POST") return fail(req, 405, "method", "POST only.");

  try {
    const user = await requireUser(req);
    ctx.user_id = user.id;

    const parsed = Body.safeParse(await req.json().catch(() => null));
    if (!parsed.success) { log(ctx, "client_error"); return fail(req, 400, "bad_input", "Invalid body."); }
    const { target_type, target_id, text } = parsed.data;

    const hits = PATTERNS.filter((p) => p.re.test(text)).map((p) => p.label);
    if (hits.length === 0) { log(ctx, "ok", { flagged: false }); return ok(req, { flagged: false }); }

    const svc = serviceClient();
    await svc.from("reports").insert({
      reporter_id: null, source: "auto", status: "open",
      target_type, target_id, reason: hits[0],
      detail: { matched: hits, by_user: user.id },
    });
    if (target_type === "job") {
      await svc.from("jobs").update({ flagged_at: new Date().toISOString() }).eq("id", target_id);
    }

    log(ctx, "ok", { flagged: true, hits });
    return ok(req, { flagged: true, categories: hits }); // soft signal; do not block UX
  } catch (e) {
    const err = e as { status?: number; code?: string; message?: string };
    log(ctx, err.status === 401 ? "auth_error" : "server_error", { code: err.code });
    return fail(req, err.status ?? 500, err.code ?? "internal",
                err.status && err.status < 500 ? (err.message ?? "Error") : "Unexpected error.");
  }
});
```

### Operational guidance

- **Secrets:** set `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT_JSON`, `CRON_SECRET` via `supabase secrets set` — never commit, never read in `lib/` (the audit confirmed 0 service-role hits in the Flutter app; keep it that way).
- **Timeouts / graceful degradation:** Edge Functions hard-cap ~150s on Supabase; keep each function single-purpose. `send-push` and `export-my-data` are the slowest — cap result sets, paginate large exports if a user has >10k rows, and never let one dead FCM token abort the loop (the skeleton continues).
- **Idempotency:** `delete-my-account` requires `Idempotency-Key` and short-circuits if `anonymised_at` is set. Apply the same pattern to any future payment/state-change function.
- **Deploy order:** `_shared/` + migrations → admin trio → delete-account → export/push → moderation/licence cron. Add `[functions.notify-licence-expiring] verify_jwt = false` and any future webhook function to `supabase/config.toml`.

---

## Open questions for Ken

1. **Admin web app reality check (blocks F-EDGE-01 severity):** Does an admin web app exist today, and if so, how does it currently approve verifications / suspend users — Supabase dashboard SQL, or a service-role key in the web app? This determines whether F-EDGE-01 is "no path" or "actively unsafe path".
2. **CORS origin:** What is the exact production origin of the admin web app (and does the Flutter app ever call Edge Functions directly, or only via the SDK)? Needed to lock `_shared/cors.ts`.
3. **`trade_profiles.is_verified` semantics:** When `admin-approve-verification` approves a document, should `is_verified` flip automatically, or only when a *required set* of document types is all approved? (No rule encoded anywhere today.)
4. **Account-deletion policy:** Confirm "anonymise + preserve consent/moderation trail, ban auth user" is acceptable for APP 13, vs. a hard delete after a retention window. What retention window for the anonymised skeleton + `legal_acceptances`?
5. **FCM project:** Is there a Firebase project + service account for Jobdun yet? `send-push` is non-functional until `FCM_SERVICE_ACCOUNT_JSON` and a `device_tokens` registration flow in the Flutter app exist (currently zero device-token code in `lib/`).
6. **Moderation keyword list:** The `moderation-keyword-scan` patterns are placeholders — needs a real AU-trades scam/abuse lexicon and a decision on flag-for-review vs. auto-hide thresholds (NEEDS HUMAN INPUT).
7. **Scheduling mechanism:** Use Supabase scheduled functions (config.toml cron) or `pg_cron` + `pg_net` for `notify-licence-expiring`? Pro plan supports both; pick one for the runbook.
