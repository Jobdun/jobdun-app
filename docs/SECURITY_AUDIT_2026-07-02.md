# Security Audit — 2026-07-02

_Scope: Jobdun Supabase backend (DB/RLS, Postgres functions, Edge Functions, Auth/JWT, Storage, secrets). Graded against **OWASP API Security Top 10 (2023)** + **OWASP Top 10 (2021)**. Produced by the `backend-security-audit` skill (drift-proof discovery scripts + independent baseline recon). **Fixes are drafted, not applied.**_

## Verdict

**HOLD — 2 BLOCKERs, both exploitable today, both fixable with small targeted changes.** The core of the backend is genuinely solid: RLS on all 32 tables, the trust/verified flag is unforgeable, admin is locked down, every `SECURITY DEFINER` function pins `search_path`, secrets are not client-reachable, and the verification pipeline is rate-limited + SSRF-safe. The weaknesses are a cluster of **over-permissive `UPDATE` policies + `GRANT ALL`** (identity/foreign-key columns are mutable) and an **unauthenticated-abusable `push-send`** function. These are access-control/abuse bugs, not data-at-rest leaks — but two are trivial to exploit. Fix the 2 BLOCKERs before the next release; the FAILs are a same-week cleanup.

---

## Remediation status (updated 2026-07-03)

| Item | Status | Where |
|---|---|---|
| B2 / F1 / F2 / F4 (identity-column lock) + F8 (FK index) | **✅ APPLIED to remote 2026-07-03** (confirmed via migration history) | `supabase/migrations/20260703000001_security_lock_identity_cols.sql` (+ rollback) |
| F3 (require login for directory) — *product decision: NOT public* | **✅ APPLIED to remote 2026-07-03** (⚠ verify marketing site) | `supabase/migrations/20260703000002_security_require_login_directory.sql` (+ rollback) |
| F6 (CORS default-deny) | **✅ DEPLOYED 2026-07-03** (all 4 functions) | `supabase/functions/_shared/cors.ts` |
| B1 (push-send caller auth) + F7 | **Awaiting Vault secret** | guide: `docs/security-fixes/2026-07-02/B1-push-send-auth.md` |
| F5 (GRANT ALL to anon), F9 (auth config) | Documented, not staged | this report |

Nothing has been pushed to production — the human runs `supabase db push` / `functions deploy`.

---

## BLOCKERS

### B1 · `push-send` Edge Function has no caller authorization · `API5` (Broken Function-Level Auth) + `API2` + `API6`
- **Plain English:** The function that sends push notifications trusts *whoever calls it*. Since the app's anon key is public (it ships inside the app), **anyone on the internet can call `push-send` and blast any title/body/deep-link to any or every user.** It's a mass-phishing/spam gun pointed at your whole user base, delivered through your own trusted notification UI.
- **Evidence:** `supabase/functions/push-send/index.ts:25-48` reads `{user_ids,title,body,data}` and immediately uses the **service-role** client to look up device tokens + send FCM — no shared secret, no check the caller owns those `user_ids`. The DB fan-out calls it with the anon key (`supabase/schema.sql:864-867`). No `verify_jwt=false` + internal-secret gate in `supabase/config.toml`. Target UUIDs are enumerable via B2/F5.
- **Impact:** Unauthenticated, whole-userbase notification spam/phishing with attacker-controlled deep links. Exploitable today.
- **Drafted fix:** `docs/security-fixes/2026-07-02/B1-push-send-auth.md` — require an `X-Internal-Token` shared secret (Supabase Vault) that the DB fan-out sends and the function verifies; reject anon callers. (Needs the secret provisioned — 15-min task.)

### B2 · Conversation participant can reassign the counterparty (private-thread disclosure) · `API1` (BOLA) + `API3`
- **Plain English:** In a chat between builder A and trade T, A can *rewrite who the other participant is* — swap T out for any stranger. The stranger then reads the entire private message history, and T silently loses access to their own conversation.
- **Evidence:** `supabase/schema.sql:3553` — `conversations_update_participant` `USING`/`WITH CHECK` only require `auth.uid() = builder_id OR auth.uid() = trade_id`, so A stays valid while changing `trade_id`. `GRANT ALL ON conversations TO authenticated` (`schema.sql:4317-4319`); no trigger pins identity columns. Same loose check lets a party flip the other side's `*_archived_at`/`*_muted_at`/`*_unread_count`/`status='blocked'`.
- **Impact:** Disclosure of a private message thread to an arbitrary third user + eviction of the real participant. Exploitable today.
- **Drafted fix:** `docs/security-fixes/2026-07-02/B2-lock-identity-cols.sql` — BEFORE-UPDATE trigger making `builder_id`/`trade_id`/`job_id` immutable from the client (service_role exempt). Same file also covers F1/F2.

---

## FAILs

### F1 · `messages` can be re-parented via UPDATE (block-bypass / injection) · `API1` + `API3`
- **Plain English:** A user can edit one of their own messages to *move it into a different conversation* — including one they were blocked from — and it renders to those participants. Message injection that side-steps the block rules enforced on insert.
- **Evidence:** `supabase/schema.sql:3634` — `messages_modify_own` checks only `sender_id = auth.uid()`; the strict membership+not-blocked predicate on `messages_insert` (`schema.sql:3620-3630`) isn't mirrored. `GRANT ALL ON messages` (`schema.sql:4359-4361`).
- **Drafted fix:** identity-lock trigger (`B2` file) makes `conversation_id`/`sender_id` immutable; additionally mirror the insert membership check in the UPDATE `WITH CHECK`.

### F2 · `applications` UPDATE has no `WITH CHECK` + `GRANT ALL` · `API3`
- **Plain English:** Either side can tamper with fields they don't own — a trade can mark its *own* application "hired"; a builder can rewrite the trade's proposed rate/cover note; and with no write-check, identity columns can be reassigned.
- **Evidence:** `supabase/schema.sql:3460` — `applications_update USING (auth.uid()=trade_id OR auth.uid()=builder_id)`, no `WITH CHECK`; `GRANT ALL` (`schema.sql:4221-4223`). Only `quote_amount` is trigger-protected.
- **Drafted fix:** identity-lock trigger (`B2` file) pins `job_id`/`trade_id`/`builder_id`; **needs product decision** to split status transitions per role (who may set `shortlisted`/`hired`/`withdrawn`).

### F3 · Anonymous enumeration of the entire trade/builder directory · `API3` (Excessive Data Exposure) + `API1`
- **Plain English:** Anyone (not logged in) can page through *every* tradie/builder — user ID, full name, suburb/postcode, ~1 km location, ratings — even though the app itself hides all browsing behind login. It's a scraping/privacy exposure and the ID list that makes B1 mass-scale.
- **Evidence:** `trade_profiles_public` (`schema.sql:2330-2364`) + `builder_profiles_public` (`schema.sql:1867-1886`) are plain views (not `security_invoker`) → run as owner, bypass RLS; both `GRANT ALL … TO anon` (`schema.sql:4541-4543`, `4305-4307`). `search_trades` also granted to anon (`schema.sql:4185`). Views *do* minimize (no exact address/`place_id`/`licence_url`, rate gated) — so exposure-scope, not raw-PII.
- **Drafted fix (needs product decision):** if the directory isn't meant to be public, revoke these from `anon` (grant `authenticated` only). If a public storefront is intended, drop `full_name`/`id` from the anon projection. **State the intended audience first.**

### F4 · Same permissive-UPDATE pattern on `bookings`, `quote_requests`, `timesheets` · `API3`
- **Plain English:** Lower-stakes version of B2/F2 — a party can reattach their *own* booking/quote/timesheet to a different job/builder. Integrity nuisance, no cross-tenant read.
- **Evidence:** `bookings_trade_update` (`schema.sql:3492`), `quote_requests_trade_update` (`schema.sql:3710`), `timesheets_trade_all` (`schema.sql:3795`) — `WITH CHECK` only re-asserts ownership.
- **Drafted fix:** extend the identity-lock trigger to these tables.

### F5 · Broad `GRANT ALL … TO anon` across many tables · `API8` / `A05` (defense-in-depth)
- **Plain English:** Many tables hand the anonymous role full table privileges. It's not exploitable today (RLS blocks anon), but it means one future table shipped without RLS — or one `USING(true)` slip — becomes an instant public leak. The safety net has only one layer.
- **Evidence:** `applications`, `messages`, `conversations`, `notifications` grants (`schema.sql:4221`, `4359`, `4317`, `4371`, …).
- **Drafted fix:** grant these to `authenticated`/`service_role` only; keep `anon` off anything anon must never touch.

### F6 · Wildcard CORS on all Edge Functions · `API8`
- **Plain English:** The functions accept calls from any website. Low risk here (bearer-token, not cookie, auth), but the sensitive verification endpoints should only answer your own origins.
- **Evidence:** `supabase/functions/_shared/cors.ts:2` — `Access-Control-Allow-Origin: "*"`.
- **Drafted fix:** `docs/security-fixes/2026-07-02/F6-cors-lock.ts` — allowlist `jobdun.com.au` / `admin.jobdun.com.au`.

### F7 · Hardcoded anon JWT inside `notifications_push_fanout()` · `API8` / `A02` (hygiene)
- **Plain English:** A long-lived credential is baked into a database function. It's *only* the public anon key (not a secret), but hardcoding credentials breaks on rotation and is exactly what makes B1 work.
- **Evidence:** `supabase/schema.sql:867`.
- **Drafted fix:** move to Supabase Vault; pair with B1's shared-secret.

### F8 · `conversations.job_id` foreign key has no covering index · `API1` (scalability)
- **Plain English:** Deleting a job or joining by job scans the whole conversations table. Minor DoS/perf at scale. (This is the *only* remaining unindexed FK — the 2026-06-11 "15 unindexed FKs" were fixed by migration `20260611000003`.)
- **Evidence:** FK `conversations_job_id_fkey` (`schema.sql:3195`); `conversations` indexes don't cover `job_id`.
- **Drafted fix:** `CREATE INDEX CONCURRENTLY idx_conversations_job_id ON conversations(job_id);` (in `B2` file).

### F9 · Auth hardening in `config.toml` (verify against hosted project) · `API2`
- **Plain English:** Email sign-ups aren't email-verified, the one-time-code lives for an hour, and passwords can be 6 chars. Weakish defaults for a marketplace (partly offset by the phone-gate on verification). **Caveat:** `config.toml` is local CLI config — the live dashboard may differ; confirm there.
- **Evidence:** `supabase/config.toml:219` (`enable_confirmations=false`), `:175` (`minimum_password_length=6`), `:227` (`otp_expiry=3600`).
- **Drafted fix:** enable email confirmation for prod, shorten OTP expiry, raise min password length — **in the hosted dashboard.**

---

## PASS ledger — verified solid, do not re-litigate

- ✅ **API1** — RLS **enabled on all 32 tables**. (FORCE RLS absent but *not needed*: tables owned by `postgres`; `anon`/`authenticated` are non-owners and fully subject to RLS.)
- ✅ **API3 — the old P0 is FIXED.** Trust/verified flag is unforgeable: `verifications` blocks all client writes (`*_no_client_insert/update/delete` = `USING/WITH CHECK false`, `schema.sql:3926-3934`); `trade_profiles.is_verified`/`average_rating`/`rating_count` are **excluded from the per-column GRANTs** (`schema.sql:4389-4477`), written only by the `sync_trade_is_verified` trigger off the locked `verifications` table.
- ✅ **API2** — admin non-self-assignable: `user_roles_insert_own` limits to `builder`/`trade`; `forbid_self_admin` + `forbid_role_mutation` (service-role-only) triggers; `log_role_event` audit; no UPDATE/DELETE policy on `user_roles`.
- ✅ **API5** — every `SECURITY DEFINER` function pins `search_path`; `admin_broadcast`/`admin_set_job_status`/`admin_set_user_status`/`revoke_verification`/`review_verification_document` all gate on `user_roles.role='admin'`. `custom_access_token` hook REVOKEd from PUBLIC.
- ✅ **A03** — no injection: `search_trades` is parameterized (ILIKE on binds), returns the minimized public projection.
- ✅ **API8 (storage)** — `private-docs` (verification docs) `public=false`, owner-path + admin-only; `chat-attachments` `public=false`, participant-scoped, 10 MB + MIME allowlist; `public-media` public-read / owner-write.
- ✅ **API8/A02 (secrets)** — `lib/` uses only the anon key (the two `service_role` hits are comments); bundled `.env` = anon key + Google client IDs + MapTiler + Sentry DSN only; service-role + Twilio live in gitignored, non-bundled `.env.server` / `functions/.env`.
- ✅ **API7/API10** — `verify-abn`/`verify-licence`/`jobs-feed` are JWT-gated; verify-* add 5/hr per-user + 20/hr per-IP limits, a phone-verified precondition, circuit breakers, audit rows; external hosts are constants with `encodeURIComponent`'d params (no SSRF); `verify-licence` auto-verify disabled (manual review).

## Drafted fixes (written to `docs/security-fixes/2026-07-02/`, NONE applied)

| File | Fixes | Risk | Needs product decision? |
|---|---|---|---|
| `B2-lock-identity-cols.sql` (+ rollback inline) | B2, F1, F2 (FK part), F4, F8 | low–med (test app write paths) | no |
| `B1-push-send-auth.md` | B1, F7 | med (provision Vault secret) | no |
| `F6-cors-lock.ts` | F6 | low | no |
| _(report note)_ F3 anon directory | F3, F5 | — | **YES — is the directory public?** |

Apply order: **B2 → B1 → F6 → F3/F5 (after the product decision) → F8 → F9 (dashboard).** Move each `.sql` into `supabase/migrations/` only when reviewed; `supabase db push` is the human's call.

## Method

- **Discovery:** `scripts/discover.sh` (32 tables, all RLS-enabled; 39 DEFINER fns all `search_path`-pinned; 57 FKs vs 76 indexes; buckets) + `scripts/grep-probes.sh` (secrets/CORS/DEFINER).
- **Independent baseline recon:** clean-context subagent, 25 tool-uses, no OWASP/hint priming — findings reconciled into the above (it caught B1/B2 and corrected the RLS-FORCE over-flag).
- **OWASP versions:** API Security Top 10 = 2023; Web Top 10 = 2021.
- **context7:** consult for any Supabase RLS/Edge/Storage API detail before drafting fixes.
- **NOT verifiable from files (flag for confirmation):** live DB↔`schema.sql` parity; `storage.objects` RLS-enabled state; hosted Auth settings (F9); deployed per-function `verify_jwt`; **service-role/Twilio rotation status** after the historical bundling leak.
