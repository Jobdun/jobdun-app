# Backend Full Audit — Schema, RLS, Scalability & Modularity

**Date:** 2026-06-11
**Method:** Live schema dumped from project `zethpanvkfyijislxesn` (`supabase db dump --linked`, 4 055 lines, 30 tables) and analysed programmatically: RLS/policy census, SECURITY DEFINER hygiene, trigger inventory, FK delete-rule census, FK-index coverage, and Dart-model ↔ live-column drift. Every claim below was verified against the live database **today**, not against docs or memory.
**Predecessors:** `docs/archive/audit/00_EXECUTIVE_SUMMARY.md` (2026-05-16, verdict RED), `docs/SUPABASE_REALTIME_BACKEND_AUDIT.md` (2026-06-03). This audit re-tests their open findings.

---

## Verdict

**AMBER — structurally healthy, two security holes to close before launch.**
The schema is fully migrated (all 72 migrations applied, local = remote in lockstep), every table has RLS, all 33 `SECURITY DEFINER` functions pin `search_path`, the verification source-of-truth is write-locked, realtime is published, and audit-trail tables exist for roles, verifications, and admin actions. What remains is one privilege-escalation hole (self-grantable trust signals), one PII overexposure (blanket profile SELECT), and a set of cheap scalability fixes (15 unindexed FKs).

---

## What was verified SOLID (don't re-litigate)

| Area | Evidence (live, 2026-06-11) |
|---|---|
| Migrations | 72/72 applied; `supabase migration list` local = remote through `20260611000001` |
| RLS coverage | 30/30 tables `ENABLE ROW LEVEL SECURITY`; 83 policies; the 2 zero-policy tables (`regulator_circuit_state`, `verification_rate_limits`) are **intentionally** service-role-only |
| Function hygiene | 33/33 `SECURITY DEFINER` functions set `search_path` — zero exceptions |
| Verification trust chain | `verifications` denies client INSERT/UPDATE/DELETE (`WITH CHECK (false)` / `USING (false)`); written only by edge functions; `verifications_sync_trade_is_verified` syncs the badge |
| Role security | `user_roles_forbid_self_admin` (INSERT) + `trg_forbid_role_mutation` (UPDATE); admin reads gated via `user_roles` lookups |
| Messaging | Relationship-scoped policies; realtime publication fixed `20260603000001` (+ REPLICA IDENTITY FULL); `conversations` carries real `*_last_read_at` / unread counts — **F-RT-02 CLOSED** (no mock left in `message_thread_page.dart`) |
| Storage | `public-media` full CRUD policies; `private-docs` owner select/insert/delete + path-scoped; signed URLs in use for private docs (admin viewer + chat attachments) — **F-PRIV-02 substantially CLOSED** |
| Data hygiene | `updated_at` triggers on all mutable tables; `applications_protect_quote` pins the quote column; `reviews_sync_trade_rating_trg` maintains rating aggregates |
| Account deletion | `delete_my_account` RPC → `DELETE FROM auth.users`; FK census: 41 CASCADE / 7 SET NULL — clean teardown for normal users |
| Job feed ordering | `createJob` stamps `published_at` (the NULL-sort gotcha is fixed in code) |
| Schema guard | `supabase/schema.sql` was **7 tables stale** — re-synced today (this commit); CI drift-guard is meaningful again |

---

## Findings — ranked

### P0 · Self-grantable trust signals (F-RLS-02, narrowed but OPEN)

`trade_profiles_update_own` / `builder_profiles_update_own` are `USING/WITH CHECK (auth.uid() = id)` with **no column restrictions**, and the only BEFORE-UPDATE triggers are `updated_at` touchers. Via PostgREST a signed-in user can therefore set on their own row:

- `trade_profiles.is_verified = true` — the badge flag the app and `search_trades` read. The `verifications` table is locked, but the **synced flag is not** — the sync trigger doesn't prevent manual writes between syncs.
- `trade_profiles.average_rating` / `rating_count` — overwriting the trigger-maintained aggregates (5.0★, 999 reviews).
- `builder_profiles.abn` — and the client treats non-empty ABN as "ABR-verified" for the field-lock (`_isAbnVerified`), so a typed ABN cosplays as a verified one in the edit UI. (The actual badge still comes from `verifications` — locked — so this is a UI-trust issue, not a badge forgery.)

Same class: `verification_documents_update_own` lets a trade UPDATE **any column of their own doc rows**, including `status` / `reviewed_by` — i.e. self-approve an uploaded document.

**Fix (one migration, no app-behaviour change):** BEFORE-UPDATE column-pin triggers —
- `trade_profiles`: reject client changes to `is_verified, average_rating, rating_count` (writes via service role / triggers skip the check with `current_setting('request.jwt.claims', true)` role test or `auth.uid() IS NOT NULL` guard).
- `builder_profiles`: reject client changes to `average_rating, rating_count`; pin `abn` once a verified `verifications` row exists.
- `verification_documents`: restrict owner UPDATE to re-upload fields (`file_url`, `kind`, `submitted_at`), pin `status, reviewed_by, reviewed_at` to the admin RPC path.

### P1 · PII overexposure (F-RLS-03, OPEN — needs one product decision)

`trade_profiles_select_authenticated` / `builder_profiles_select_authenticated` grant **every authenticated account** SELECT on **every column** of every profile row: tradie legal `full_name`, exact `base_latitude/longitude` (home base), builder `contact_phone`, rates, ABN. A $0 throwaway signup can scrape the whole book.

It's a marketplace — discoverability is the product — but *column*-level exposure should match what the UI actually shows publicly. **Fix needs a 10-minute product decision** on the visibility model, then one migration:
- **Option 1 (recommended):** keep the blanket row SELECT but move clients to curated projections (the `search_trades` RPC + a `trade_profiles_public` view pattern, like the existing `trade_public_credentials`), then tighten table SELECT to own-row + relationship-scoped (active application / conversation / hired).
- **Option 2 (lighter):** Postgres column privileges (`REVOKE SELECT (contact_phone, base_latitude, …) ON … FROM authenticated`) — quick but PostgREST `select=*` calls must be projection-audited first or they 403.

### P1 · 15 unindexed foreign keys (scalability)

51 FKs, 54 indexes — but these FK columns have none (seq-scan joins + lock amplification on parent deletes). Hot ones first:

| Hot path | Cold/audit path |
|---|---|
| `saved_jobs.job_id`, `hidden_jobs.job_id` (feed filters) | `manual_verification_requests.{user_id, verification_id, resolved_by}` |
| `bookings.job_id`, `jobs.hired_trade_id` (schedule views) | `verification_events.actor_id`, `verification_funnel_events.user_id` |
| `timesheets.builder_id` (builder timesheet list) | `user_role_events.changed_by`, `verification_documents.reviewed_by` |
| `reviews.reviewer_id` (per-user reviews + uniqueness) | `conversations.last_message_sender_id`, `message_reactions.user_id` |

**Fix:** one migration, ~15 `CREATE INDEX CONCURRENTLY`-style adds. Zero risk.

### P2 · Dart-model ↔ schema drift: 7 phantom columns

Verified by diffing model JSON keys against live columns:
- `trade_profiles` model reads `hire_count`, `jobs_completed`, `total_applications`, `verified_at` — **none exist live** → UI stats render hard-coded zeros.
- `builder_profiles` model reads `active_jobs_count`, `hire_count`, `total_jobs_posted` — same.

Writes are safe since today's patch-based saves only emit real columns (the legacy full-row writer is deleted). **Decide:** (a) add the columns + counter triggers on `applications`/`jobs` (real stats, scalable), or (b) strip them from models/UI until earnings/stats work lands. (a) is ~1 migration + small trigger set.

### P2 · 3 NO-ACTION FKs can block account deletion (admin actors)

`manual_verification_requests.resolved_by`, `verification_events.actor_id`, `user_role_events.changed_by` have no ON DELETE rule → deleting an account that ever **acted as an admin/resolver** fails the `delete_my_account` cascade. Fix: `ON DELETE SET NULL` (preserves the audit row, unblocks deletion).

### P3 · Housekeeping

- **`private-docs` has no storage UPDATE policy** (F-PRIV-01). Currently moot — licence uploads INSERT to fresh timestamped paths; only avatar uses `upsert:true` and that's `public-media` (which has UPDATE). Add for completeness or leave documented.
- **`supabase/schema.sql` staleness process:** re-synced in this commit, but the guard only works if `sync-schema.sh` runs after every `db push` — add it to the migration ritual (or CI).
- Supabase CLI 2.95.4 → 2.105.0 available.
- `lib/admin` should be projection-audited if Option 2 (column privileges) is ever chosen.

---

## Long-term scalability & modularity assessment

**Good bones, keep the patterns:**
- Feature-aligned table clusters with audit side-tables (`verification_events`, `user_role_events`, `admin_actions`) — modular and queryable.
- Regulator calls wrapped in rate-limit + circuit-breaker state tables; pg_cron for expiry sweeps — the "scheduled rail" is real.
- Trigger-maintained denormalisations (rating sync, conversation last-message) — right call at this scale **once the P0 pin stops clients overwriting them**.
- Soft-delete (`deleted_at`) on profile tables with `isFilter('deleted_at', null)` read paths.
- Partial-save patch layer (2026-06-11) ended the full-row-write era — additive schema changes no longer risk null-wipes from stale clients.

**Watch as load grows (Sprint-4 class, not now):**
- Feed pagination is `limit/offset` — move hot feeds to keyset (`published_at < cursor`) before tens of thousands of rows.
- `trade_profiles.portfolio_urls` / `unavailable_dates` arrays are fine at current cardinality; revisit if either becomes unbounded.
- `search_trades` is bounding-box + haversine over a btree — fine for thousands of tradies; PostGIS + GiST when it isn't.
- Counter columns (if P2-a chosen) must be trigger-maintained, never client-written.

---

## Recommended fix order

1. ~~**M1 — P0 column pins**~~ — ✅ **APPLIED LIVE 2026-06-11** (`20260611000002_pin_trust_columns.sql`): column-allowlist GRANTs on `trade_profiles`/`builder_profiles` (is_verified, rating aggregates, timestamps, deleted_at now server-only), `verification_documents` client UPDATE narrowed to `deleted_at`, ABN pin-once-verified trigger. Verified on a fresh dump: `is_verified` in zero client grants; rollback in `supabase/rollbacks/`.
2. ~~**M2 — FK indexes + delete rules**~~ — ✅ **APPLIED LIVE 2026-06-11** (`20260611000003_fk_indexes_delete_rules.sql`): 15 FK indexes, 3 audit-actor FKs → ON DELETE SET NULL.
3. **P1 PII visibility model** — 10-minute decision (Option 1 vs 2), then its migration. **← the only remaining security item.**
4. **P2 phantom columns** — decide real-counters vs strip-from-UI.

---

## Sprint-1 ledger (from the 2026-05-16 audit) — final state

| Finding | State today |
|---|---|
| F-RLS-01 admin self-promotion | ✅ closed (trigger pair, verified live) |
| F-RLS-02 self-verification | ⚠️ **OPEN, narrowed** — source table locked; synced flags + doc status still client-writable (→ M1) |
| F-RLS-03 blanket PII SELECT | ❌ **OPEN** (→ decision + migration) |
| F-PRIV-01 storage UPDATE policy | 🟡 moot today (no UPDATE path exists); add for completeness |
| F-PRIV-02 signed URLs for private docs | ✅ closed (signed URLs in admin viewer + chat attachments) |
| F-RT-02 mock thread page | ✅ closed (real columns, realtime published) |

*Generated from a live dump on 2026-06-11. Re-run the dump-and-census after M1/M2 land.*
