# Schema Auditor Audit — Jobdun Backend

**Auditor:** schema-auditor
**Scope:** Every table, view, type, enum, function, trigger, FK, index and naming
convention in the Postgres schema as defined by the 17 SQL migrations in
`supabase/migrations/`, cross-checked against the Dart entity/model layer for
schema↔model drift. Covers normalisation, referential integrity, enum-vs-free-text
status, soft-delete patterns, timestamp/trigger discipline, FK cascade behaviour,
multi-tenancy/role separation, and PK type choice (UUID vs bigserial).
**Date:** 2026-05-15

**Files reviewed:**
- `supabase/migrations/20260511000001_initial_schema.sql`
- `supabase/migrations/20260511000002_jobs.sql`
- `supabase/migrations/20260511000003_applications.sql`
- `supabase/migrations/20260511000004_messaging.sql`
- `supabase/migrations/20260511000005_social.sql`
- `supabase/migrations/20260511000006_rls.sql`
- `supabase/migrations/20260511000007_handle_new_user_trigger.sql`
- `supabase/migrations/20260512000001_legal_acceptances.sql`
- `supabase/migrations/20260512000002_handle_new_user_role_optional.sql`
- `supabase/migrations/20260512000003_trade_categories.sql`
- `supabase/migrations/20260512000005_profile_extended_columns.sql`
- `supabase/migrations/20260514000001_profile_completeness.sql`
- `supabase/migrations/20260514000002_phone_verified_sync.sql`
- `supabase/migrations/20260514000003_portfolio_array_helpers.sql`
- `lib/features/verification/data/models/verification_document_model.dart`
- `lib/features/verification/domain/entities/verification_document.dart`
- `lib/features/applications/domain/entities/job_application.dart`
- `lib/features/messaging/data/models/message_model.dart`
- `lib/features/notifications/domain/entities/app_notification.dart`
- `lib/features/jobs/data/models/job_model.dart`
- `docs/audit/00_SCOPE.md`

## Summary

- **P0:** 2 &nbsp;|&nbsp; **P1:** 5 &nbsp;|&nbsp; **P2:** 6 &nbsp;|&nbsp; **P3:** 2
- **Overall verdict for 25k AU users: AMBER (leaning RED on verification).**

The relational core (identity split, jobs, applications, messaging, reviews,
legal consent) is genuinely well-built: real Postgres enums for the critical
status fields, UUID PKs with `gen_random_uuid()`, consistent `set_updated_at()`
triggers, sensible `UNIQUE` constraints (one-application-per-trade-per-job,
one-review-per-reviewer-per-job), and RLS on every table. That is above-average
for a solo-founder build.

The headline problem is **schema↔model drift on `verification_documents`**: the
Dart data layer reads and writes ~11 columns that do not exist in any migration
(`doc_type`, `file_path`, `submitted_at`, `state`, `issuer`, `document_number`,
`issued_date`, `expiry_date`, `rejection_reason`, `review_notes`, `deleted_at`),
and the `messages` model reads/writes a `deleted_at` that the table never
declares. These are not "future work" — they are **runtime breakage today** the
moment those code paths execute. Verification is also a Privacy Act / trades-
compliance surface (licences, white cards), so a broken verification table is a
P0. Secondary structural gaps: no soft-delete on `profiles`/`applications`/
`messages`/`conversations`, no licence `expires_at` + index for the
"expiring soon" path, free-text `notifications.type`, and no FK on
`jobs.trade_type_required` → `trade_categories.slug`.

## Findings

### F-SCH-01 — `verification_documents` table does not match the Dart model (11 missing columns)
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** Schema `supabase/migrations/20260511000005_social.sql:27-35`
  declares only `id, trade_id, type, url, status, created_at, updated_at`.
  The model `lib/features/verification/data/models/verification_document_model.dart:23-60`
  reads `doc_type` (L25), `file_path` (L26), `submitted_at` (L30),
  `state` (L33), `issuer` (L34), `document_number` (L35), `issued_date` (L36),
  `expiry_date` (L39), `rejection_reason` (L42), `review_notes` (L43),
  `deleted_at` (L44) — and writes `doc_type`, `file_path`, `status`,
  `expiry_date` back. None of these columns exist. There is also no
  `reviewed_by` column anywhere (spec §5).
- **Why it matters at 25k AU users:** Verification is the trust spine of a
  trades marketplace — white cards, public-liability cover, trade licences.
  Every insert from the upload flow will fail with `column "doc_type" does not
  exist` (PostgREST `PGRST204`), and every read returns nulls for fields the
  UI expects. At 25k accounts a non-functional verification table means either
  unverified tradies are presented as verified (legal/safety exposure) or the
  feature is dead. It also kills the licence-expiry notification path because
  there is no `expiry_date` column to query.
- **Fix (concrete):** Rebuild the table to match the model (and the spec's
  `reviewed_by`/`expires_at`). New migration
  `supabase/migrations/20260515000001_verification_documents_align.sql`:

```sql
-- Align verification_documents with the Dart model + add review/expiry fields.
-- Idempotent: additive ADD COLUMN IF NOT EXISTS + enum widening.

-- 1. Widen status enum to include 'expired' (Dart VerificationStatus has 4).
DO $$ BEGIN
  ALTER TYPE public.document_status ADD VALUE IF NOT EXISTS 'expired';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Doc-type enum (model expects 7 stable values, not free text).
DO $$ BEGIN
  CREATE TYPE public.document_doc_type AS ENUM (
    'trade_licence', 'public_liability', 'workers_compensation',
    'white_card', 'photo_id', 'abn_certificate', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Bring columns in line with the model. Keep legacy 'type'/'url' nullable
--    for back-compat, add the model's canonical names.
ALTER TABLE public.verification_documents
  ADD COLUMN IF NOT EXISTS doc_type         public.document_doc_type,
  ADD COLUMN IF NOT EXISTS file_path        text,
  ADD COLUMN IF NOT EXISTS submitted_at     timestamptz,
  ADD COLUMN IF NOT EXISTS state            text,
  ADD COLUMN IF NOT EXISTS issuer           text,
  ADD COLUMN IF NOT EXISTS document_number  text,
  ADD COLUMN IF NOT EXISTS issued_date      date,
  ADD COLUMN IF NOT EXISTS expiry_date      date,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS review_notes     text,
  ADD COLUMN IF NOT EXISTS reviewed_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at      timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at       timestamptz;

-- 4. Backfill new canonical columns from the legacy ones, then make them safe.
UPDATE public.verification_documents
   SET doc_type   = NULLIF(type, '')::public.document_doc_type,
       file_path  = COALESCE(file_path, url),
       submitted_at = COALESCE(submitted_at, created_at)
 WHERE doc_type IS NULL OR file_path IS NULL;

-- 5. Expiry-query index (drives F-SCH-06 'expiring soon' path).
CREATE INDEX IF NOT EXISTS verification_documents_expiry_idx
  ON public.verification_documents (expiry_date)
  WHERE status = 'approved' AND deleted_at IS NULL AND expiry_date IS NOT NULL;
```

- **Effort:** M
- **Phase:** 0
- **Layman's:** The app is trying to file paperwork into a filing cabinet that
  has the wrong drawers — every licence upload hits a wall.

### F-SCH-02 — `messages.deleted_at` is read/written by the model but doesn't exist (no soft-delete on messages)
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `supabase/migrations/20260511000004_messaging.sql:19-26`
  declares `messages` with no `deleted_at`. Model
  `lib/features/messaging/data/models/message_model.dart:23-24` parses
  `json['deleted_at']`. Spec question 4 explicitly requires
  `messages.deleted_at`. RLS migration has no message DELETE policy
  (`grep` of `20260511000006_rls.sql` shows `messages_select`,
  `messages_insert`, `messages_update_read` only).
- **Why it matters at 25k AU users:** With 200k+ messages projected, users will
  retract messages and the Privacy Act (APP 13 — correction) plus basic
  moderation require a tombstone, not a hard `DELETE` (which would cascade-lose
  thread context and break read receipts). Today the model reads a column that
  isn't there: harmless `null` on read, but any "delete message" feature writes
  to a non-existent column and 400s. There is also no RLS path to delete, so
  the only deletion is an admin hard-delete with no audit.
- **Fix (concrete):** `supabase/migrations/20260515000002_messages_soft_delete.sql`:

```sql
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Sender may soft-delete (set deleted_at) their own message via UPDATE.
DO $$ BEGIN
  CREATE POLICY "messages_soft_delete_own"
    ON public.messages FOR UPDATE
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Composite index for the realtime feed: newest-first within a thread,
-- excluding tombstones. Also closes the perf gap noted in 00_SCOPE.md §4.
CREATE INDEX IF NOT EXISTS messages_thread_feed_idx
  ON public.messages (conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;
```
  (Note: existing `messages_update_read` policy already allows recipient
  UPDATE; ensure the two UPDATE policies don't let a sender flip `read_at` —
  hand off to rls-auth-auditor for the column-level review.)
- **Effort:** S
- **Phase:** 0
- **Layman's:** "Delete message" has no bin to put the message in — pressing it
  throws an error.

### F-SCH-03 — No soft-delete on `profiles` / `applications` / `conversations` (only `jobs` has `deleted_at`)
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** Only `jobs.deleted_at` exists
  (`20260511000002_jobs.sql:64`). `profiles`
  (`20260511000001_initial_schema.sql:8-15`), `applications`
  (`20260511000003_applications.sql:20-41`), `conversations`
  (`20260511000004_messaging.sql:5-14`) have none. All FKs to `profiles` are
  `ON DELETE CASCADE`.
- **Why it matters at 25k AU users:** A user requesting account deletion
  (APP 13) currently triggers a `CASCADE` storm: deleting a `profiles` row
  wipes their jobs, applications, conversations, messages, reviews and
  verification docs irrecoverably — destroying the other party's evidence in a
  dispute (a builder's hiring history vanishes when one applicant deletes).
  Without `deleted_at` there is no anonymise-don't-delete option, which is the
  defensible APP 13 pattern. At 25k users, deletion requests are routine, and
  hard-cascade is both a data-loss and a legal-defensibility hole.
- **Fix (concrete):** `supabase/migrations/20260515000003_soft_delete_columns.sql`:

```sql
ALTER TABLE public.profiles      ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.applications  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Partial indexes so "live rows only" stays cheap at scale.
CREATE INDEX IF NOT EXISTS profiles_live_idx
  ON public.profiles (id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS applications_live_job_idx
  ON public.applications (job_id) WHERE deleted_at IS NULL;
```
  Follow-up (own migration, coordinate with rls-auth-auditor): add
  `AND deleted_at IS NULL` to every SELECT policy, and a documented
  anonymisation function so account-delete sets `deleted_at` + scrubs PII
  instead of cascading.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Deleting one account is like pulling one card and the whole
  house collapses, with no way to keep the records the law says you must.

### F-SCH-04 — `notifications.type` is free-text (spec rule: "any free-text status anywhere = finding")
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `supabase/migrations/20260511000005_social.sql:8`
  — `type text NOT NULL` with only a comment listing values. The Dart enum
  `lib/features/notifications/domain/entities/app_notification.dart:4-37`
  claims `// Matches schema enum notification_type exactly` but **no such enum
  exists** — there are 12 well-defined values in code, zero DB enforcement.
- **Why it matters at 25k AU users:** With 200k+ messages and matching
  notification volume, a single typo in any client or future Edge Function
  (`'new_messsage'`) silently writes a row no consumer matches — notifications
  vanish with no error. The code comment lying about an enum that doesn't exist
  guarantees this drift goes unnoticed. Free-text status is exactly the
  category §2 flags as a finding.
- **Fix (concrete):** `supabase/migrations/20260515000004_notification_type_enum.sql`:

```sql
DO $$ BEGIN
  CREATE TYPE public.notification_type AS ENUM (
    'application_received', 'application_status_changed', 'new_message',
    'hire_confirmed', 'hire_declined', 'verification_approved',
    'verification_rejected', 'document_expiring', 'document_expired',
    'review_received', 'job_filled', 'system_announcement'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Cast existing rows; unknown values map to system_announcement to avoid loss.
ALTER TABLE public.notifications
  ALTER COLUMN type TYPE public.notification_type
  USING (CASE WHEN type = ANY (enum_range(NULL::public.notification_type)::text[])
              THEN type::public.notification_type
              ELSE 'system_announcement'::public.notification_type END);
```
- **Effort:** S
- **Phase:** 1
- **Layman's:** Notification categories are spelled by hand each time — one
  typo and that alert just disappears.

### F-SCH-05 — `applications.proposed_rate_type` is free-text where `budget_type` enum already exists
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `supabase/migrations/20260511000003_applications.sql:30`
  — `proposed_rate_type text,  -- 'hourly' | 'daily' | 'fixed'`. The enum
  `public.budget_type AS ENUM ('hourly','daily','fixed','negotiable')`
  already exists (`20260511000002_jobs.sql:19`) and is used on
  `jobs.budget_type`.
- **Why it matters at 25k AU users:** A trade's proposed rate type and a job's
  budget type are the same domain concept; storing one as an enforced enum and
  the other as free text means rate comparisons/filters can't be trusted at
  50k+ applications, and the spec's "free-text status = finding" rule applies.
- **Fix (concrete):** `supabase/migrations/20260515000005_application_rate_type_enum.sql`:

```sql
ALTER TABLE public.applications
  ALTER COLUMN proposed_rate_type TYPE public.budget_type
  USING NULLIF(proposed_rate_type, '')::public.budget_type;
```
  (Confirm the app never sends `'negotiable'` for a proposed rate; if it must
  be restricted to 3 values, create a dedicated `rate_type` enum instead.)
- **Effort:** XS
- **Phase:** 2
- **Layman's:** Two boxes that hold the same kind of thing — one is a labelled
  dropdown, the other a blank line anyone can scribble on.

### F-SCH-06 — No licence `expires_at` + index for the "expiring soon" path
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `verification_documents` has no expiry column
  (`20260511000005_social.sql:27-35`); confirmed by `00_SCOPE.md:94`. The Dart
  entity `lib/features/verification/domain/entities/verification_document.dart:95-101`
  has `expiryDate` + `isExpired`, and `NotificationType.documentExpiring`
  (`app_notification.dart`) implies a reminder feature with no data model.
- **Why it matters at 25k AU users:** White cards and trade licences expire;
  AU compliance means a tradie with a lapsed licence must not appear verified.
  With 25k accounts there is no way to run "find docs expiring in 30 days" — no
  column, no index. Any such scan would be a full table seq-scan even once the
  column exists. (Largely fixed by F-SCH-01's migration; called out separately
  because it's a distinct compliance failure mode and a distinct index.)
- **Fix (concrete):** Covered by `verification_documents_expiry_idx` in the
  F-SCH-01 migration. The notification job (Edge Function, out of schema scope —
  defer to edge-functions-auditor) queries:

```sql
SELECT id, trade_id, doc_type, expiry_date
FROM public.verification_documents
WHERE status = 'approved' AND deleted_at IS NULL
  AND expiry_date BETWEEN now()::date AND (now() + interval '30 days')::date;
```
- **Effort:** S (schema part; XS once F-SCH-01 lands)
- **Phase:** 1
- **Layman's:** No way to know whose white card is about to expire, so the app
  can't warn anyone before they're working illegally.

### F-SCH-07 — `jobs.trade_type_required` is free-text with no FK to `trade_categories`
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `jobs.trade_type_required text NOT NULL DEFAULT ''`
  (`20260511000002_jobs.sql:30`). A canonical `trade_categories(slug)`
  reference table exists (`20260512000003_trade_categories.sql:11-20`, 19
  seeded slugs). No FK links them. `jobs.required_certifications text[]` is
  similarly unconstrained.
- **Why it matters at 25k AU users:** The whole marketplace match is
  trade↔job on trade type. With 10k+ active jobs, a builder typing
  `"electrican"` or the app sending a display name instead of the slug means
  that job never matches any electrician's feed — silent demand/supply
  fragmentation that's invisible until conversion tanks. A reference table
  exists but isn't enforced, which is the worst of both worlds.
- **Fix (concrete):** `supabase/migrations/20260515000006_jobs_trade_fk.sql`:

```sql
-- Normalise any non-canonical values first (manual review may be needed;
-- this maps obvious display-name drift). Then enforce the FK.
UPDATE public.jobs j
   SET trade_type_required = tc.slug
  FROM public.trade_categories tc
 WHERE lower(j.trade_type_required) = lower(tc.display_name)
   AND j.trade_type_required <> tc.slug;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_trade_type_fk
  FOREIGN KEY (trade_type_required)
  REFERENCES public.trade_categories(slug)
  ON UPDATE CASCADE ON DELETE RESTRICT
  NOT VALID;            -- NOT VALID first to avoid locking 10k rows on deploy

ALTER TABLE public.jobs VALIDATE CONSTRAINT jobs_trade_type_fk;

CREATE INDEX IF NOT EXISTS jobs_open_trade_idx
  ON public.jobs (trade_type_required, created_at DESC)
  WHERE status = 'open' AND deleted_at IS NULL;
```
  (Rows with values not in `trade_categories` will block `VALIDATE` — needs a
  one-time data clean. Flag as NEEDS HUMAN INPUT if prod data exists.)
- **Effort:** M
- **Phase:** 1
- **Layman's:** Jobs say what trade they need by free-typing it, so a typo
  means electricians never see that job.

### F-SCH-08 — `jobs.application_count` / `view_count` are denormalised counters with no maintaining trigger
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `20260511000002_jobs.sql:58-59` — `application_count int NOT
  NULL DEFAULT 0`, comment says "maintained by triggers / edge functions" but
  there is no such trigger in any migration, and `00_SCOPE.md:33` confirms
  zero Edge Functions.
- **Why it matters at 25k AU users:** Builders sort/triage by applicant count;
  a counter that never increments is permanently `0` (misleading UX) or, if a
  client tries to `+1` it client-side, drifts and double-counts under the
  concurrent applies expected at 50k+ applications. Denormalised counters with
  no single writer are a classic scale-time correctness bug.
- **Fix (concrete):** `supabase/migrations/20260515000007_application_count_trigger.sql`:

```sql
CREATE OR REPLACE FUNCTION public.sync_job_application_count()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.jobs SET application_count = application_count + 1
      WHERE id = NEW.job_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.jobs SET application_count = GREATEST(application_count - 1, 0)
      WHERE id = OLD.job_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS applications_count_sync ON public.applications;
CREATE TRIGGER applications_count_sync
  AFTER INSERT OR DELETE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.sync_job_application_count();

-- Backfill to correct any existing drift.
UPDATE public.jobs j
   SET application_count = (
     SELECT count(*) FROM public.applications a WHERE a.job_id = j.id
   );
```
  (`view_count` should be incremented by a dedicated RPC, not a trigger —
  defer the view-tracking design to performance-auditor.)
- **Effort:** S
- **Phase:** 2
- **Layman's:** The "applicants" number on a job is hand-written and never
  updated, so it's wrong.

### F-SCH-09 — No `reports` table (moderation intake) — spec question 6
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** Not present in repo; confirmed `00_SCOPE.md:78`. No migration
  defines `reports`.
- **Why it matters at 25k AU users:** A two-sided marketplace with messaging
  and 200k+ messages will get scam jobs, abusive messages and fake profiles
  from day one of scale. With no intake table there is no record of complaints,
  no triage queue, and no evidence trail — a solo on-call engineer has nothing
  to action and the platform has no defence if a harmed user escalates.
- **Fix (concrete):** `supabase/migrations/20260515000008_reports.sql`:

```sql
DO $$ BEGIN
  CREATE TYPE public.report_target_type AS ENUM
    ('job','message','profile','review','application');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.report_status AS ENUM
    ('open','triaged','actioned','dismissed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.reports (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type  public.report_target_type NOT NULL,
  target_id    uuid NOT NULL,
  reporter_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason       text NOT NULL,
  detail       text,
  status       public.report_status NOT NULL DEFAULT 'open',
  resolved_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (target_type, target_id, reporter_id)   -- one report per user per target
);

CREATE INDEX IF NOT EXISTS reports_open_idx
  ON public.reports (created_at DESC) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS reports_target_idx
  ON public.reports (target_type, target_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP TRIGGER IF EXISTS reports_updated_at ON public.reports;
CREATE TRIGGER reports_updated_at BEFORE UPDATE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
-- RLS policies (reporter insert/read own; admin read/update all) — hand to
-- rls-auth-auditor / trust-safety-auditor for the policy bodies.
```
- **Effort:** M
- **Phase:** 1
- **Layman's:** There is no "report this" inbox — complaints go nowhere.

### F-SCH-10 — No `user_suspensions` table (enforcement) — spec question 7
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** Not present in repo; confirmed `00_SCOPE.md:79`.
- **Why it matters at 25k AU users:** Reports (F-SCH-09) are useless without an
  enforcement primitive. A scammer or abusive user cannot be timed-out or
  banned; the only lever is hard-deleting their account (data-loss + cascade).
  At 25k users, repeat-offender management is routine ops; with no suspensions
  table the platform cannot enforce its own ToS, which is also a duty-of-care
  exposure.
- **Fix (concrete):** `supabase/migrations/20260515000009_user_suspensions.sql`:

```sql
CREATE TABLE IF NOT EXISTS public.user_suspensions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      text NOT NULL,
  started_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz,                 -- NULL = indefinite
  lifted_at   timestamptz,                 -- set when an admin lifts early
  created_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Fast "is this user currently suspended?" check.
CREATE INDEX IF NOT EXISTS user_suspensions_active_idx
  ON public.user_suspensions (user_id)
  WHERE lifted_at IS NULL;

ALTER TABLE public.user_suspensions ENABLE ROW LEVEL SECURITY;
-- Suspended user may read their own active suspension; only admin writes.
-- Policy bodies + enforcement at RLS/JWT level → rls-auth-auditor.
```
- **Effort:** M
- **Phase:** 1
- **Layman's:** There is no way to put a bad actor in the penalty box —
  it's all-or-nothing account deletion.

### F-SCH-11 — `reviews` has no "only after job completion" guard and no `updated_at`
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `20260511000005_social.sql:46-58` — `reviews` has
  `UNIQUE(job_id, reviewer_id)` but no constraint tying a review to a
  `jobs.status = 'filled'`/completed state, no FK ensuring reviewer was party
  to the job, and no `updated_at`/trigger.
- **Why it matters at 25k AU users:** Reputation is the marketplace's currency.
  Without a completion guard, a builder can leave a 1-star review on a job a
  trade never worked, or a competitor can review-bomb. There is no DB-level
  defence; RLS alone can't easily express "job must be completed and you were
  the hired trade". At review volume this is a trust-integrity hole.
- **Fix (concrete):** Add a `CHECK` via a trigger (cross-row rule can't be a
  table CHECK) — `supabase/migrations/20260515000010_reviews_completion_guard.sql`:

```sql
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
DROP TRIGGER IF EXISTS reviews_updated_at ON public.reviews;
CREATE TRIGGER reviews_updated_at BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.assert_review_allowed()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.jobs j
    WHERE j.id = NEW.job_id
      AND j.status IN ('filled','closed')
      AND (j.builder_id = NEW.reviewer_id OR j.hired_trade_id = NEW.reviewer_id)
      AND (NEW.reviewee_id = j.builder_id OR NEW.reviewee_id = j.hired_trade_id)
  ) INTO v_ok;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'review not permitted: job not completed or not a party'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reviews_completion_guard ON public.reviews;
CREATE TRIGGER reviews_completion_guard
  BEFORE INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.assert_review_allowed();
```
  (Detailed trust rules → trust-safety-auditor; this is the schema-level guard.)
- **Effort:** S
- **Phase:** 2
- **Layman's:** Anyone can leave a star rating on any job even if no work
  happened — reviews can't be trusted.

### F-SCH-12 — `legal_acceptances` is mutable: no trigger blocking UPDATE/DELETE despite "immutable by design" claim
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `20260512000001_legal_acceptances.sql:1-2` states "Immutable by
  design — no UPDATE or DELETE for users". RLS has only SELECT/INSERT policies,
  so PostgREST users can't update/delete — **but** the table has
  `ON DELETE CASCADE` to `auth.users` (L6), and any future SECURITY DEFINER
  function or service-role path can silently mutate/erase consent rows. There
  is no `BEFORE UPDATE/DELETE` trigger enforcing the documented invariant at
  the table level.
- **Why it matters at 25k AU users:** This is the Privacy Act consent audit
  trail. "Immutable by RLS-omission" breaks the moment an admin tool, an Edge
  Function, or a migration touches it. For legal defensibility the immutability
  must be enforced by the table, not by the absence of a policy.
- **Fix (concrete):** `supabase/migrations/20260515000011_legal_acceptances_immutable.sql`:

```sql
CREATE OR REPLACE FUNCTION public.block_legal_acceptance_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'legal_acceptances is append-only (consent audit trail)'
    USING ERRCODE = '0A000';
END;
$$;

DROP TRIGGER IF EXISTS legal_acceptances_no_update ON public.legal_acceptances;
CREATE TRIGGER legal_acceptances_no_update
  BEFORE UPDATE ON public.legal_acceptances
  FOR EACH ROW EXECUTE FUNCTION public.block_legal_acceptance_mutation();

DROP TRIGGER IF EXISTS legal_acceptances_no_delete ON public.legal_acceptances;
CREATE TRIGGER legal_acceptances_no_delete
  BEFORE DELETE ON public.legal_acceptances
  FOR EACH ROW EXECUTE FUNCTION public.block_legal_acceptance_mutation();
```
  (Account-deletion must then anonymise the linked user, not cascade-erase the
  consent row — coordinate with storage-privacy-auditor on the APP 13 flow;
  consider changing the FK to `ON DELETE SET NULL` + a denormalised
  `user_email_hash` so the audit row survives account deletion.)
- **Effort:** S
- **Phase:** 2
- **Layman's:** The "they agreed to the terms" logbook is only locked because
  no one's been given a pen — it's not actually glued shut.

### F-SCH-13 — `conversations` UNIQUE on `(job_id, builder_id, trade_id)` mishandles NULL job_id
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `20260511000004_messaging.sql:7,13` — `job_id` is nullable
  (`ON DELETE SET NULL`) and the table has `UNIQUE (job_id, builder_id,
  trade_id)`. In Postgres, `NULL` is distinct in a UNIQUE constraint, so two
  conversations with `job_id IS NULL` between the same builder/trade are both
  allowed.
- **Why it matters at 25k AU users:** When a job is deleted, `job_id` is set
  NULL — and the dedupe guarantee evaporates. A builder/trade pair whose job
  was removed can accumulate duplicate conversation rows, splitting message
  history across threads (confusing UX, broken unread counts) at messaging
  scale.
- **Fix (concrete):** `supabase/migrations/20260515000012_conversations_unique_fix.sql`:

```sql
ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_job_id_builder_id_trade_id_key;

-- Two partial unique indexes: one for job-scoped, one for the job-less pair.
CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_with_job
  ON public.conversations (job_id, builder_id, trade_id)
  WHERE job_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_no_job
  ON public.conversations (builder_id, trade_id)
  WHERE job_id IS NULL;
```
- **Effort:** XS
- **Phase:** 2
- **Layman's:** Once a job is deleted, the same two people can end up with two
  separate chat threads and lose track of each other.

### F-SCH-14 — Misleading "Matches schema enum ... exactly" comments where no enum exists
- **Severity:** P3
- **Status:** RISKY
- **Evidence:** `lib/features/notifications/domain/entities/app_notification.dart:3`
  `// Matches schema enum notification_type exactly` (no such enum — F-SCH-04);
  `lib/features/verification/domain/entities/verification_document.dart:3`
  `// Matches schema enum doc_type exactly` and `:49`
  `// Matches schema enum verification_status` (no `doc_type` enum;
  `document_status` has 3 values, code has 4 — F-SCH-01).
- **Why it matters at 25k AU users:** These comments actively mislead the solo
  engineer into believing the DB enforces values it doesn't, so drift (F-SCH-01,
  F-SCH-04) ships unnoticed. Documentation that asserts a guarantee that
  doesn't exist is worse than no comment.
- **Fix (concrete):** Once F-SCH-01/F-SCH-04 land, the comments become true. If
  those are deferred, change the comments to
  `// NOTE: NOT enforced in DB (type is free text) — keep in sync manually`.
- **Effort:** XS
- **Phase:** 1
- **Layman's:** The code's notes promise the database is checking things it
  isn't checking.

### F-SCH-15 — UUID-everywhere PKs: justified, but `notifications`/`messages` will be high-churn — note only
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** All tables use `uuid PRIMARY KEY DEFAULT gen_random_uuid()`
  (e.g. `20260511000002_jobs.sql:24`, `…000004_messaging.sql:20`,
  `…000005_social.sql:6`).
- **Why it matters at 25k AU users:** UUID v4 PKs are the correct choice here:
  client-generatable (offline-first on rural 3G), non-enumerable (no IDOR by
  guessing), and Supabase-idiomatic. The only note: random UUID v4 PKs cause
  index-write amplification on the highest-insert tables (`messages` 200k+,
  `notifications`). This is acceptable at 25k users on Supabase Pro and **not a
  finding** — but if `messages` insert latency degrades, consider `uuid v7`
  (time-ordered) via `gen_random_uuid()` replacement, not bigserial (keep the
  non-enumerable property). No action required now.
- **Fix (concrete):** None. Documented for the performance-auditor's awareness.
- **Effort:** XS
- **Phase:** 3
- **Layman's:** The way every record gets its ID is the right call; just keep
  an eye on the chat table as it grows huge.

## Cross-cutting recommendations

1. **Schema↔model contract is not enforced anywhere.** F-SCH-01/-02/-14 all
   stem from the data layer and migrations drifting independently. Add a CI
   check that diffs the live schema (or a generated `schema.sql` from
   `supabase db dump`) against expected, and/or generate Dart models from the
   schema. For a solo engineer this is the single highest-leverage fix.
2. **Soft-delete is half-done.** Only `jobs` has `deleted_at`. Adopt it
   uniformly (F-SCH-03/-02) and make every SELECT RLS policy `... AND
   deleted_at IS NULL`. Pair with an explicit anonymise-on-account-delete
   function so APP 13 doesn't mean cascade data-loss.
3. **Free-text status audit.** §2 rule violated in three places
   (`notifications.type` F-SCH-04, `applications.proposed_rate_type` F-SCH-05,
   `verification_documents.type` F-SCH-01). Real Postgres enums everywhere a
   status/type exists; the project already does this well for the core enums,
   so this is consistency, not new pattern.
4. **Moderation/enforcement schema is entirely absent** (F-SCH-09/-10). These
   are P1 because at 25k users with messaging they're not optional. Land the
   tables in Phase 1 even before the admin web app consumes them, so the data
   trail starts accumulating.
5. **Denormalised counters need a single writer** (F-SCH-08). The pattern of
   "maintained by triggers / edge functions" with neither existing will silently
   break under concurrency. Triggers (DB-local, atomic) are the right writer
   here, not client code or Edge Functions.
6. **Referential integrity gaps** beyond F-SCH-07: `notifications.data jsonb`
   holds untyped `job_id`/`application_id` references with no FK (acceptable
   for a payload blob, noted); `verification_documents.reviewed_by` (after
   F-SCH-01) and `reports/user_suspensions` admin actor columns should all
   `ON DELETE SET NULL` so deleting an admin doesn't erase the audit trail.

## Open questions for Ken

1. **NEEDS HUMAN INPUT — verification_documents truth source.** Is the Dart
   `verification_document_model.dart` the intended schema (rich: issuer,
   document_number, expiry, review_notes) or is the thin migration the truth
   and the model aspirational? F-SCH-01's migration assumes the model is
   correct. Confirm before applying.
2. **NEEDS HUMAN INPUT — prod data for FK enforcement.** F-SCH-07
   (`jobs.trade_type_required` → `trade_categories`) and F-SCH-05 enum casts
   will fail `VALIDATE`/`ALTER` if existing rows hold non-canonical values. Is
   there production data in `zethpanvkfyijislxesn` yet, or is this still
   pre-launch (clean apply)?
3. Should account deletion (APP 13) **anonymise** (recommended — preserves
   other parties' job/dispute history) or **hard-cascade** (current behaviour)?
   This decides whether F-SCH-03 + F-SCH-12 FK changes are P1 or P0.
4. Is the **admin web app** expected to write `reports`/`user_suspensions`
   directly via service-role, or through Edge Functions? Affects whether RLS
   admin-write policies are needed on the F-SCH-09/-10 tables (hand-off to
   rls-auth-auditor / edge-functions-auditor).
