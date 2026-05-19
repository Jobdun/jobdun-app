# 00 — Audit Scope & Repo Inventory (Source of Truth)

**Project:** Jobdun — Flutter + Supabase mobile job marketplace, Australian construction trades.
**Surveyed:** 2026-05-15
**Surveyed by:** Lead Backend Auditor (Orchestrator)
**Supabase project ref:** `zethpanvkfyijislxesn` ("Jobdun's Project"), Postgres **17.6**.

> All 8 specialist sub-agents MUST treat this file as ground truth for *what exists*.
> If a sub-agent's scope references a file/feature not listed here, the correct
> finding is **Status: MISSING** — do not hallucinate an implementation.

---

## 1. What physically exists in the repo

### Flutter app — `lib/`
Feature-first Clean Architecture, fully scaffolded (data/domain/presentation per feature):

- `lib/app/` — router, theme, constants
- `lib/core/` — config (`supabase_config.dart`), errors, network, services, validators, widgets
- `lib/features/` — `auth`, `profile`, `jobs`, `applications`, `messaging`, `notifications`,
  `verification`, `reviews`, `legal`, `ftue`, `home`

**Supabase touch points:** 101 `.from()/.rpc()/Supabase.` call sites across **15 Dart files**
(all data-layer datasources + a few presentation providers). Notable RPC usage:
`append_portfolio_url`, `remove_portfolio_url`.

### Supabase backend — `supabase/`
- `supabase/config.toml` — local CLI config (15 KB; see §3 for notable settings)
- `supabase/migrations/` — **17 SQL migrations** (see §2 for the schema inventory)
- `supabase/email-templates/confirm-signup.html`
- `supabase/.temp/` — CLI link state (project ref, pg version)
- **`supabase/functions/` does NOT exist — there are ZERO Edge Functions.**

### Docs — `docs/`
Existing audits/specs (design-focused): `JOBDUN_SCHEMA.md`, `AUTH_ONBOARDING_AUDIT.md`,
`design-system-audit.md`, `JOBDUN_AI_HANDOFF.md`, etc.
**`docs/audit/` created by this run.** No prior backend audit existed.

### CI/CD
`.github/workflows/` (ci.yml, cd.yml per CLAUDE.md), `scripts/validate.sh`, pre-push hook.
No App Store / Play Store deployment automation observed (no Fastlane).

---

## 2. Schema inventory (from `supabase/migrations/`, 17 files)

Migrations are timestamp-prefixed `YYYYMMDDhhmmss_name.sql`, well-commented, idempotent
(`IF NOT EXISTS`, `DO $$ … EXCEPTION WHEN duplicate_object`).

| Migration | Contents |
|---|---|
| `…000001_initial_schema` | `profiles`, `user_roles`, `builder_profiles`, `trade_profiles`; `set_updated_at()` trigger fn + triggers |
| `…000002_jobs` | `jobs` table; enums `job_status`, `job_urgency`, `budget_type`; 3 b-tree indexes; `updated_at` trigger |
| `…000003_applications` | `applications` table; enum `application_status`; `UNIQUE(job_id,trade_id)`; 3 indexes |
| `…000004_messaging` | `conversations`, `messages`; `update_conversation_last_message()` trigger |
| `…000005_social` | `notifications`, `verification_documents` (+ enum `document_status`), `reviews` |
| `…000006_rls` | RLS enabled + policies on ALL tables; storage buckets `public-media` (public), `private-docs` (private) + bucket policies |
| `…000007_handle_new_user_trigger` | `handle_new_user()` SECURITY DEFINER trigger on `auth.users` |
| `…000008_custom_access_token_hook` | `custom_access_token(event)` JWT hook injecting `user_role` |
| `…000009_rls_patch` | Adds fallback INSERT/UPDATE policies on `profiles`, `user_roles` |
| `…000001_legal_acceptances` (0512) | `legal_acceptances` (immutable consent audit trail) + RLS incl. admin-read |
| `…000002_handle_new_user_role_optional` | Reworks trigger so role is optional (SSO users get no role row) |
| `…000003_trade_categories` | `trade_categories` reference table (19 seeded) + `trade_profiles.trade_other` |
| `…000004_token_hook_role_optional` | Reworks JWT hook to omit claim when no role row |
| `…000005_profile_extended_columns` | Adds contact/about/location columns to builder & trade profiles |
| `…000001_profile_completeness` (0514) | `profile_completeness` view (`security_invoker=on`) + `profiles.phone_verified_at`, `trade_profiles.licence_url` |
| `…000002_phone_verified_sync` | Trigger mirroring `auth.users.phone_confirmed_at` → `profiles.phone_verified_at` + backfill |
| `…000003_portfolio_array_helpers` | `append_portfolio_url` / `remove_portfolio_url` SECURITY DEFINER RPCs (auth.uid() guarded) |

### Tables that EXIST
`profiles`, `user_roles`, `builder_profiles`, `trade_profiles`, `jobs`, `applications`,
`conversations`, `messages`, `notifications`, `verification_documents`, `reviews`,
`legal_acceptances`, `trade_categories`.
**View:** `profile_completeness`.

### Tables/features the spec asks about that do NOT exist (→ MISSING)
- **No `reports` table** (moderation intake).
- **No `user_suspensions` table** (enforcement / bans).
- **No `moderation_audit_log`** (admin action audit).
- **No rate-limit table / KV** (`rate_limit_events` or equivalent).
- **No `data_export_requests` table** / APP 12 export path.
- **No delete-account / anonymisation flow** (APP 13 beyond cascade).
- **No retention policy** documented anywhere.
- **No PostGIS** — `jobs` stores `latitude`/`longitude` as `double precision`, no
  `geography` column, no GiST index, no `ST_DWithin` path.
- **No full-text / `pg_trgm` / GIN index** on `jobs.title|description`.
- **No `deleted_at`** on `profiles`, `applications`, `messages`, `conversations`
  (only `jobs` has soft-delete).
- **No Edge Functions at all** (`admin-approve-verification`, `report-content`,
  `suspend-user`, `export-my-data`, `delete-my-account`, `notify-licence-expiring`,
  `send-push`, `moderation-keyword-scan` — all MISSING).
- **No `expires_at`** on `verification_documents` (licence-expiry notification path
  has no data model).
- **No observability**: no `sentry`/`posthog`/`crashlytics`/`logging` package in
  `pubspec.yaml`; no `docs/runbooks/`; no status page; no restore test doc.

---

## 3. Notable config / security facts (pre-verified by Orchestrator)

- **Service-role key:** `grep` of `lib/` for `service_role|SERVICE_ROLE|serviceRole`
  → **0 hits.** Good — no service-role exposure in the mobile app. (Sub-agents should
  still spot-check their own scope.)
- **Secrets hygiene:** `.env` and the three `client_secret_*.json` /
  `client_*.plist` Google OAuth files sit in the **repo root, unencrypted**, but are
  **git-ignored and NOT tracked** (`git ls-files` shows none; `git check-ignore`
  passes). Risk is local-disk / accidental-share, not git history. Flag at auditor
  discretion (storage-privacy / observability-ops).
- **`supabase/config.toml`:** local CLI dev config only — `site_url =
  http://127.0.0.1:3000`, `auth.email.enable_confirmations = false`,
  `auth.sms.enable_confirmations = false`, `storage.file_size_limit = "50MiB"`,
  Postgres major 17. These are *local* values; production auth/storage settings live
  in the Supabase dashboard and are **not determinable from the repo**.
- **Supabase region / data residency: UNKNOWN from repo.** No region recorded in
  `linked-project.json` or `config.toml`. The **storage-privacy-auditor** must flag
  APP 8 (cross-border disclosure) as **NEEDS HUMAN INPUT: confirm the project is in
  `ap-southeast-2` (Sydney).**
- **Auth providers wired:** `supabase_flutter ^2.12.4`, `google_sign_in ^7.2.0`,
  `sign_in_with_apple ^8.0.0`. Role is delivered via JWT custom claim
  (`user_role`) sourced from `public.user_roles`, not a `profiles.role` column.
- **Image handling pkgs present:** `flutter_image_compress ^2.3.0`,
  `image_cropper ^8.0.2` (storage-privacy-auditor: verify they're actually used
  on the upload path; presence ≠ wired).

---

## 4. Per-agent ground-truth pointers

| Agent | Key facts |
|---|---|
| schema-auditor | 13 tables + 1 view exist; status fields are real enums/CHECK (good); soft-delete only on `jobs`; UUID v4 (`gen_random_uuid()`) PKs; no `reports`/`user_suspensions`/expiry columns |
| rls-auth-auditor | RLS enabled on every app table; role via JWT claim from `user_roles`; self-escalation blocked (`role IN ('builder','trade')`); no service-role in `lib/`; **no admin gating exists because there are no Edge Functions** |
| performance-auditor | Only b-tree indexes; **no PostGIS, no FTS/trgm, no keyset pagination primitives**; review the 101 query sites in 15 datasource files |
| storage-privacy-auditor | 2 buckets (`public-media` public, `private-docs` private); `legal_acceptances` exists; **region unknown → APP 8 NEEDS HUMAN INPUT**; no retention/export/delete flow; signed-URL TTL not determinable from migrations alone — check Dart datasources |
| edge-functions-auditor | **`supabase/functions/` does not exist — every function in the spec is MISSING.** Provide full TS skeletons. |
| realtime-messaging-auditor | `messages`/`conversations` exist; `messages` has NO `deleted_at`; `messages_conversation_id_idx` present but no `(conversation_id, created_at DESC)` composite; inspect `message_remote_datasource.dart` + `messaging_provider.dart` for subscription scope & pagination |
| trust-safety-auditor | **No moderation pipeline at all**: no `reports`, `user_suspensions`, `moderation_audit_log`, rate-limit table, keyword scan. `reviews` has `UNIQUE(job_id,reviewer_id)` but no "only after completion" guard. No admin surface in app (by design — admin is separate web app, not in this repo). |
| observability-ops-auditor | **No Sentry/PostHog/Crashlytics package; no runbooks; no status page; no documented restore.** Effectively greenfield observability. |

---

## 5. Verdict shape going in

This is **not** an empty repo — the relational core (identity, jobs, applications,
messaging, reviews, verification docs, legal consent) is implemented with RLS and
sensible enums. The gaps are concentrated in **operational maturity**: zero Edge
Functions, zero observability, zero trust-&-safety/moderation infrastructure, no
geo/search indexing strategy, and undetermined data residency. Sub-agents should
frame these as **"design & build before Phase 3 scale"**, not "broken today",
except where RLS/privacy/secrets create present-tense exposure.
