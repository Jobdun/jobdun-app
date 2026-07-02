# OWASP API Security Top 10 (2023) → Jobdun Supabase checks

Each gate: **Plain English** (for a non-specialist) · **Discover** (what to run/read) · **PASS when** · **FAIL / BLOCKER when** · **Fix** (recipe in `fix-patterns.md`). Walk every gate; cite `file:line`.

---

## API1:2023 — Broken Object Level Authorization (BOLA)

**Plain English:** Can user A read or change user B's rows just by knowing/guessing an ID? In Supabase this is enforced almost entirely by Row Level Security — if RLS is off or a policy is too loose, anyone can pull anyone's data.

**Discover:** `bash scripts/discover.sh --tables --rls --policies`. Compare **TABLES** vs **RLS ENABLED** — any user-data table missing from RLS ENABLED is an instant candidate. Read each policy's `USING` (read scope) and `WITH CHECK` (write scope).

**PASS when:** RLS is **enabled and forced** on every user-data table; every policy scopes rows to `auth.uid()` or an intended relationship (e.g. participant of a conversation, applicant/owner of a job); public views (`trade_profiles_public`, `builder_profiles_public`) expose only intended columns (coords rounded, rates gated).

**FAIL / BLOCKER when:** a user-data table has **no RLS**, or a policy is `USING (true)` / `TO anon,authenticated` on read or write of private data → **BLOCKER**. A relationship policy that's broader than intended (leaks to non-participants) → **FAIL**.

**Fix:** `fix-patterns.md → Enable + force RLS`, `Owner-scoped policy`.

## API2:2023 — Broken Authentication

**Plain English:** Can someone log in as another user, forge a token, or grant themselves the admin role in their JWT?

**Discover:** read `supabase/config.toml` (email-confirm, OTP expiry, session/refresh); find `custom_access_token_hook` in the schema (how `user_role` gets into the JWT); confirm the `forbid_self_admin` migration exists and `user_role`/`role` columns aren't user-writable.

**PASS when:** the role claim is injected **server-side** by the hook and cannot be set by the user; admin is **non-self-assignable** at the DB level; email confirmation on; OTP expiry short; refresh-token rotation on.

**FAIL / BLOCKER when:** a user can set their own `role`/admin flag (→ **BLOCKER**, also API3); email confirmation off in production; OTP valid for an excessive window (→ **FAIL**).

**Fix:** `fix-patterns.md → Column-guard WITH CHECK` (role columns) + config change.

## API3:2023 — Broken Object Property Level Authorization

**Plain English:** Even on a row you're allowed to touch, can you read or write **fields you shouldn't** — e.g. set your own `verified`/trust flag to true, or read someone's phone number? (Merges "mass assignment" + "excessive data exposure".)

**Discover:** `bash scripts/discover.sh --policies` → for every UPDATE policy, check whether its `WITH CHECK` excludes trust/verification/role/rating columns. List columns a client can write via PostgREST and compare against columns that should be system-only.

**PASS when:** every user-writable table has a `WITH CHECK` (or trigger) that **blocks writes to verification/trust/role/rating** columns; PII columns are served only through gated views or column privileges.

**FAIL / BLOCKER when:** a user can `UPDATE` a trust/verification/role column on their own row → **BLOCKER** (privilege/trust escalation). A PII column readable beyond its intended audience → **FAIL**.

**Fix:** `fix-patterns.md → Column-guard WITH CHECK`. (Jobdun's known-open self-grantable trust flags belong here as a **BLOCKER**.)

## API4:2023 — Unrestricted Resource Consumption

**Plain English:** Can someone hammer an endpoint to run up your Supabase/Twilio/FCM bill or knock the service over — unlimited OTP sends, unbounded queries, push spam?

**Discover:** check the `jobs-feed` function + feed queries for a capped page size; `search_trades` for a `LIMIT`; `push-send` and OTP paths for any rate limiting; grep for unbounded `select` without limit on large tables.

**PASS when:** list/feed endpoints cap page size (Jobdun convention = 20); `search_trades` bounded; `push-send`/OTP rate-limited per user; no unbounded scans on hot paths.

**FAIL when:** no rate limit on `push-send`/OTP; unbounded feed/search; missing pagination on a growable list.

**Fix:** `fix-patterns.md → Rate-limit / bound` (often an infra/product decision — state it).

## API5:2023 — Broken Function Level Authorization

**Plain English:** Can a normal user call an admin-only database function, or escalate privilege through a `SECURITY DEFINER` function that runs with the owner's rights?

**Discover:** `bash scripts/discover.sh --definers` (lists DEFINER functions + flags those without a nearby `search_path`). For each `admin_*` RPC (`admin_set_user_status`, `admin_set_job_status`, `admin_broadcast`, …) confirm it checks `user_role = 'admin'` before acting.

**PASS when:** every `SECURITY DEFINER` function pins `search_path` (`SET search_path = ''` or `public, pg_temp`); every privileged RPC verifies the caller's admin role; no escalating helper is `EXECUTE`-able by `authenticated`/`anon`.

**FAIL / BLOCKER when:** a DEFINER function has no pinned `search_path` (→ **FAIL**, **BLOCKER** if a mutable-search-path hijack is plausible); an `admin_*` RPC lacks a role check and is callable by ordinary users (→ **BLOCKER**).

**Fix:** `fix-patterns.md → DEFINER search_path pin`; add a role-gate guard clause.

## API6:2023 — Unrestricted Access to Sensitive Business Flows

**Plain English:** Can someone abuse a legitimate flow at scale — mass-post jobs, spam applications, blast broadcasts, or farm verifications?

**Discover:** review INSERT policies + any throttle/duplicate-guard on `jobs`, `job_applications`, broadcasts, and `verification_documents`. Look for per-user/per-time limits.

**PASS when:** sensitive inserts have per-user throttles or duplicate-guards (e.g. one pending verification at a time; application-per-job uniqueness).

**FAIL when:** unlimited job/application/broadcast creation; no duplicate guard on verification submissions.

**Fix:** `fix-patterns.md → Rate-limit / bound` + unique constraints (product decision on thresholds).

## API7:2023 — Server-Side Request Forgery (SSRF)

**Plain English:** Can a user trick your server into calling a URL it shouldn't? Your `verify-abn` / `verify-licence` functions call external government APIs — those endpoints must be hard-coded, never taken from user input.

**Discover:** read `supabase/functions/verify-abn` and `verify-licence`; confirm the external base URL is a constant; trace whether any user-supplied value becomes part of a fetch **target** (host/path), vs. just a query param to a fixed host.

**PASS when:** external hosts are constants (ABR / licence registry); user input only fills fixed query params on a fixed host; egress limited to known hosts.

**FAIL / BLOCKER when:** user input controls the fetch host/URL → **BLOCKER**.

**Fix:** `fix-patterns.md → Constant-URL / host allowlist`.

## API8:2023 — Security Misconfiguration

**Plain English:** The boring-but-deadly stuff — a storage bucket left public, the service-role key shipped in the app, wildcard CORS, RLS not forced.

**Discover:** `bash scripts/grep-probes.sh` (service-role in `lib/`, `.env` bundled, wildcard CORS); `bash scripts/discover.sh --buckets`; check each bucket's public flag + storage policies.

**PASS when:** `verification-documents` and `job-attachments` are **private** with owner/relationship storage policies; the **service-role key is never reachable from client code or bundled assets**; Edge Functions don't use wildcard CORS on authenticated routes; RLS forced.

**FAIL / BLOCKER when:** a private bucket is public, or the service-role key is client-reachable/bundled → **BLOCKER**. Wildcard CORS on an authenticated route → **FAIL**.

**Fix:** `fix-patterns.md → Private bucket + storage policy`, `Edge CORS lock`, `Secret rotation checklist`.

## API9:2023 — Improper Inventory Management

**Plain English:** Do you actually know every table/function/endpoint that exists, and does the schema match what the app expects? Forgotten debug functions and drifted columns are where breaches hide.

**Discover:** compare Dart models against the real schema for **phantom columns** (columns the app reads that don't exist / are always default); grep for debug/test RPCs exposed to `anon`/`authenticated`; check deprecated columns (`budget_min`, legacy pricing) aren't still exposed in a sensitive way.

**PASS when:** no app-read phantom columns masking data; no debug/test functions exposed; deprecated columns removed or safely gated.

**FAIL when:** schema↔model drift causes silent wrong reads; a leftover debug function is callable; a deprecated PII-ish column is still readable.

**Fix:** `fix-patterns.md → Align model/schema; drop/revoke stray function`.

## API10:2023 — Unsafe Consumption of 3rd-party APIs

**Plain English:** Do you blindly trust what ABR / licence registries / Twilio / FCM send back? A compromised or malformed upstream response shouldn't corrupt your data or crash the function.

**Discover:** in `verify-abn`/`verify-licence` (and any Twilio/FCM call), check that responses are validated/typed before use, have timeouts, and aren't written raw to the DB.

**PASS when:** upstream responses are schema-validated/typed, time-bounded, and error-handled; nothing raw is persisted without validation.

**FAIL when:** raw/unchecked upstream data is trusted or stored; no timeout/error handling.

**Fix:** `fix-patterns.md → Validate upstream response`.
