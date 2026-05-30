# Schema-Drift Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make verification upload, the messaging inbox, job search, **and the auth/profile/onboarding feature** work against the real Postgres schema by adding the ~25 columns the Dart data layer already reads/writes, close the admin self-promotion backdoor, and ship every change as both timestamped migrations and one consolidated idempotent paste-ready SQL block.

**Architecture:** Pre-launch with **no production data** (confirmed by Ken), so reconciliation is done with additive, idempotent `ALTER`/`CREATE` statements replayed by `supabase db reset` — no backfill, no `NOT VALID` FK dance, no data-clean pass. Every statement is re-runnable (`ADD COLUMN IF NOT EXISTS`, `DO … EXCEPTION WHEN duplicate_object`, `CREATE OR REPLACE`, `DROP … IF EXISTS`, `CREATE INDEX IF NOT EXISTS`) so it is safe to `supabase db push` **or** paste wholesale into the Supabase dashboard SQL editor, repeatedly. The Dart model is the canonical contract (deliberate forward design; migrations lagged) — with one deliberate exception: `email` is NOT duplicated onto `profiles` (it is canonical in `auth.users`; the one offending `.select()` is corrected instead). Two timestamped migrations + one consolidated `supabase/reconciliation.sql` + a CI schema-diff guard so drift cannot silently return.

**Dart changes (minimal, one line):** `lib/features/profile/data/datasources/profile_remote_datasource.dart:36` — remove `email` from the `profiles` `.select(...)`. `email` is already merged from auth context in `auth_remote_datasource.dart:108`; `UserProfileModel.fromJson` reads it as nullable so nothing breaks. No other Dart file changes.

**Tech Stack:** Supabase CLI (local Postgres 17 in Docker), SQL migrations, Flutter/Dart data layer (unchanged — only the schema moves to meet it).

**Source of truth for every column below:** the audit (`docs/audit/01_schema.md`, `06_realtime_messaging.md`, `03_performance.md`) cross-checked against the live Dart models. Drift verified directly:
- `verification_documents`: migration `20260511000005_social.sql:27-35` has 7 cols; `verification_document_model.dart:49-61` writes `doc_type/file_path/status/state/issuer/document_number/issued_date/expiry_date` and **never** sends legacy `type`/`url` (both `NOT NULL`).
- `messages`: `20260511000004_messaging.sql` has no `deleted_at`/`edited_at`; `message_model.dart:23-28` reads both.
- `conversations`: same migration lacks `status/builder_unread_count/trade_unread_count/last_message_preview/last_message_sender_id`; `conversation_model.dart:33-37` reads all five plus a `profiles_public` embed.
- `jobs`: `job_remote_datasource.dart:41` calls `textSearch('search_vector', …, websearch)`; no `search_vector` column/index exists.
- `applications`: `application_remote_datasource.dart:106,121` writes `status_changed_at`; column absent.
- `handle_new_user` (`20260512000002…:34`) accepts `'admin'` from client metadata — F-RLS-01.

**Out of scope (deliberately deferred — not runtime-breaking):** `jobs.trade_type_required` FK (F-SCH-07, Phase 1), `notifications.type` enum (F-SCH-04, Phase 1), `proposed_rate_type` enum (F-SCH-05, Phase 2), soft-delete on profiles/applications (F-SCH-03, Phase 1), trust-&-safety tables (Sprint 2). **Builder/trade stat fields** (`hire_count`, `average_rating`, `total_jobs_posted`, `jobs_completed`, etc.) are read via `select()` with `?? 0` defaults — a missing column is silently zero, not an error (same class as F-SCH-08 counters). Left out: cosmetic only, no runtime break; belongs with the denormalised-counter work in Phase 2. The parked social-auth/FTUE WIP needs **no schema work** (verified: client-side UI + external IP API + local analytics only) — it is not in this plan's scope and stays stashed. This plan is Sprint 1 item 1 + auth/profile reconciliation + the S-effort F-RLS-01.

---

## File Structure

| File | Responsibility |
|---|---|
| `supabase/migrations/20260516000001_schema_reconciliation.sql` | All additive schema changes bringing the DB up to the Dart contract (verification, messages, conversations, jobs search, applications). |
| `supabase/migrations/20260516000002_forbid_self_admin.sql` | F-RLS-01: strip `'admin'` from `handle_new_user`, add `forbid_self_admin` BEFORE-INSERT trigger on `user_roles`. |
| `lib/features/profile/data/datasources/profile_remote_datasource.dart` | Modify line 36: drop `email` from the `profiles` select (email is canonical in `auth.users`). |
| `supabase/reconciliation.sql` | Consolidated, idempotent, paste-ready concatenation of both migrations — for the dashboard SQL editor. Verified safe to run twice. |
| `supabase/schema.sql` | Committed baseline dump of the public schema — the diff target for the CI guard. |
| `scripts/schema-diff.sh` | CI guard: `db reset` → `db dump` → diff vs `supabase/schema.sql`; non-zero exit on drift. |
| `scripts/validate.sh` | Modified: invoke `schema-diff.sh` in the design-system fast block. |

**Verification convention (defined once, used by every task):**
- **Apply gate:** `supabase db reset` — replays all migrations on the local Docker Postgres; non-zero exit if any migration SQL is invalid.
- **Assertion helper:** Postgres is reachable inside the Supabase Docker container. Define for the session:
  ```bash
  DBC="$(docker ps --filter name=supabase_db --format '{{.Names}}' | head -1)"
  q() { docker exec "$DBC" psql -U postgres -d postgres -tAc "$1"; }
  ```
  `q "<sql>"` prints the scalar result (used for column/enum existence asserts).

---

### Task 0: Preflight — confirm local stack and a green baseline

**Files:** none (environment check)

- [ ] **Step 1: Start the local Supabase stack**

Run: `supabase start`
Expected: prints API URL, DB URL, and `supabase_db_*` container running. If already running, prints existing status.

- [ ] **Step 2: Define the assertion helper and confirm DB reachable**

```bash
DBC="$(docker ps --filter name=supabase_db --format '{{.Names}}' | head -1)"
q() { docker exec "$DBC" psql -U postgres -d postgres -tAc "$1"; }
q "select 1"
```
Expected: prints `1`. If `DBC` is empty, run `supabase start` first.

- [ ] **Step 3: Baseline reset — all 17 existing migrations apply clean**

Run: `supabase db reset`
Expected: ends with `Finished supabase db reset.` and no SQL error. This proves the pre-change baseline is green so any later failure is attributable to the new migrations.

- [ ] **Step 4: Prove the drift exists (red baseline for the contract)**

```bash
q "select count(*) from information_schema.columns where table_name='verification_documents' and column_name='doc_type'"
q "select count(*) from information_schema.columns where table_name='messages' and column_name='deleted_at'"
q "select count(*) from information_schema.columns where table_name='jobs' and column_name='search_vector'"
```
Expected: each prints `0`. This is the failing state the migrations must flip to `1`.

---

### Task 1: `verification_documents` reconciliation

**Files:**
- Create: `supabase/migrations/20260516000001_schema_reconciliation.sql`

- [ ] **Step 1: Write the verification section of the migration**

Create `supabase/migrations/20260516000001_schema_reconciliation.sql` with exactly this content (later tasks append further sections to the same file):

```sql
-- ============================================================
-- Migration: schema reconciliation (Sprint 1 / F-SCH-01,02,13 + perf/realtime)
-- Pre-launch, no data: additive ALTERs, idempotent, safe to replay.
-- Brings the schema up to the canonical Dart data-layer contract.
-- ============================================================

-- ---------- verification_documents (F-SCH-01) ----------

-- doc_type enum — exactly DocType.dbValue in verification_document.dart:16-22
DO $$ BEGIN
  CREATE TYPE public.document_doc_type AS ENUM (
    'trade_licence', 'public_liability', 'workers_compensation',
    'white_card', 'photo_id', 'abn_certificate', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- VerificationStatus has 4 values (verification_document.dart:50); enum has 3.
DO $$ BEGIN
  ALTER TYPE public.document_status ADD VALUE IF NOT EXISTS 'expired';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

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

-- THE GAP the audit's F-SCH-01 SQL missed: legacy type/url are NOT NULL but
-- the app's insert payload (verification_document_model.dart:49-61) never
-- sends them. Without this, every upload still fails a NOT NULL violation
-- after the columns exist. No data → straight DROP NOT NULL, no backfill.
ALTER TABLE public.verification_documents
  ALTER COLUMN type DROP NOT NULL,
  ALTER COLUMN url  DROP NOT NULL;

-- "expiring soon" path (F-SCH-06): partial index on live approved docs.
CREATE INDEX IF NOT EXISTS verification_documents_expiry_idx
  ON public.verification_documents (expiry_date)
  WHERE status = 'approved' AND deleted_at IS NULL AND expiry_date IS NOT NULL;
```

- [ ] **Step 2: Apply and verify the columns exist**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='verification_documents' and column_name in ('doc_type','file_path','submitted_at','expiry_date','deleted_at','reviewed_by')"
q "select is_nullable from information_schema.columns where table_name='verification_documents' and column_name='type'"
q "select 1 from pg_type where typname='document_doc_type'"
q "select count(*) from pg_enum e join pg_type t on e.enumtypid=t.oid where t.typname='document_status' and e.enumlabel='expired'"
```
Expected, in order: `6` · `YES` · `1` · `1`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): reconcile verification_documents with Dart contract (F-SCH-01)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: `messages` soft-delete + edited_at + thread index

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

- [ ] **Step 1: Append the messages section**

Append to `supabase/migrations/20260516000001_schema_reconciliation.sql`:

```sql

-- ---------- messages (F-SCH-02 + realtime F-RT) ----------
-- message_model.dart:23-28 reads deleted_at AND edited_at; neither exists.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS edited_at  timestamptz;

-- Sender may soft-delete / edit their own message.
DO $$ BEGIN
  CREATE POLICY "messages_modify_own"
    ON public.messages FOR UPDATE
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Realtime thread feed: newest-first within a thread, tombstones excluded.
CREATE INDEX IF NOT EXISTS messages_thread_feed_idx
  ON public.messages (conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='messages' and column_name in ('deleted_at','edited_at')"
q "select 1 from pg_indexes where indexname='messages_thread_feed_idx'"
```
Expected: `2` · `1`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add messages.deleted_at/edited_at + thread index (F-SCH-02)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: `conversations` state columns + status enum + NULL job_id unique fix

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

- [ ] **Step 1: Append the conversations section**

`ConversationStatus` (conversation.dart:4) = `active | archived | blocked`, `dbValue == name`. `conversation_model.dart:33-37` reads `last_message_preview, last_message_sender_id, builder_unread_count, trade_unread_count, status`. Append:

```sql

-- ---------- conversations (F-SCH-13 + realtime F-RT-01) ----------
DO $$ BEGIN
  CREATE TYPE public.conversation_status AS ENUM ('active','archived','blocked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS status                 public.conversation_status NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS builder_unread_count   int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS trade_unread_count     int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_message_preview   text,
  ADD COLUMN IF NOT EXISTS last_message_sender_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- F-SCH-13: NULL job_id makes the UNIQUE(job_id,builder_id,trade_id) constraint
-- non-deduping (NULLs are distinct). Replace with two partial unique indexes.
ALTER TABLE public.conversations
  DROP CONSTRAINT IF EXISTS conversations_job_id_builder_id_trade_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_with_job
  ON public.conversations (job_id, builder_id, trade_id)
  WHERE job_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_no_job
  ON public.conversations (builder_id, trade_id)
  WHERE job_id IS NULL;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='conversations' and column_name in ('status','builder_unread_count','trade_unread_count','last_message_preview','last_message_sender_id')"
q "select count(*) from pg_indexes where indexname in ('conversations_uniq_with_job','conversations_uniq_no_job')"
q "select count(*) from pg_constraint where conname='conversations_job_id_builder_id_trade_id_key'"
```
Expected: `5` · `2` · `0`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add conversations state cols + fix NULL job_id unique (F-SCH-13)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: `profiles_public` view (messaging inbox embed)

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

`conversation_model.dart:22` reads a `profiles_public` PostgREST embed. Without a `profiles_public` relation the inbox query returns no counterparty name/avatar and the inbox is non-functional. Expose **only** non-sensitive display fields — `contact_phone` is deliberately excluded (that exposure is F-RLS-03, a separate Sprint-1 task; this view must not widen it).

- [ ] **Step 1: Append the view section**

```sql

-- ---------- profiles_public (realtime F-RT-01 inbox embed) ----------
-- Minimal counterparty card for the messaging inbox. Display fields only;
-- NO contact_phone / location PII (that scoping is F-RLS-03, separate task).
CREATE OR REPLACE VIEW public.profiles_public
  WITH (security_invoker = on) AS
  SELECT id, display_name, avatar_url
  FROM public.profiles;

GRANT SELECT ON public.profiles_public TO authenticated;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.views where table_name='profiles_public'"
q "select string_agg(column_name,',' order by column_name) from information_schema.columns where table_name='profiles_public'"
```
Expected: `1` · `avatar_url,display_name,id` (confirms no phone/location leaked).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add profiles_public view for messaging inbox embed (F-RT-01)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: `jobs.search_vector` generated tsvector + GIN index

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

`job_remote_datasource.dart:41-44` calls `textSearch('search_vector', q, type: websearch)`. `job_model.fromJson` never reads `search_vector`, so a generated column is safe (write-side only).

- [ ] **Step 1: Append the search section**

```sql

-- ---------- jobs.search_vector (F-PERF-01) ----------
-- websearch_to_tsquery target for job_remote_datasource.dart:41.
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(title,'') || ' ' || coalesce(description,''))
  ) STORED;

CREATE INDEX IF NOT EXISTS jobs_search_vector_idx
  ON public.jobs USING gin (search_vector);
```

- [ ] **Step 2: Apply and verify the column, index, and a real query path**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='jobs' and column_name='search_vector'"
q "select 1 from pg_indexes where indexname='jobs_search_vector_idx'"
q "select 'ok' where to_tsvector('english','leaking tap repair') @@ websearch_to_tsquery('english','tap repair')"
```
Expected: `1` · `1` · `ok`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add jobs.search_vector generated tsvector + GIN (F-PERF-01)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: `applications.status_changed_at`

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

`application_remote_datasource.dart:106,121` writes `status_changed_at` on `updateStatus` and `withdraw`. The app sets it explicitly, so only the column is needed (no trigger).

- [ ] **Step 1: Append the applications section**

```sql

-- ---------- applications.status_changed_at (F-SCH / app contract) ----------
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS status_changed_at timestamptz;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='applications' and column_name='status_changed_at'"
```
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add applications.status_changed_at (app contract)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6A: `profiles` — add `phone` + `bio`

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

`profile_remote_datasource.dart:36` selects `phone` and `bio` from `profiles`; neither exists (only `phone_verified_at` was added by the completeness migration). `UserProfileModel.fromJson:22,27` reads both as nullable.

- [ ] **Step 1: Append the profiles section**

```sql

-- ---------- profiles (auth/profile feature contract) ----------
-- profile_remote_datasource.dart:36 selects phone + bio. The completeness
-- migration comment claims "Number lives on profiles.phone" but the column
-- was never added. (email is intentionally NOT added — canonical in
-- auth.users; the offending .select() is corrected in Task 6C.)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS bio   text;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='profiles' and column_name in ('phone','bio')"
```
Expected: `2`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add profiles.phone/bio for profile feature contract

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6B: `trade_profiles` — add rate/crew/radius columns

**Files:**
- Modify: `supabase/migrations/20260516000001_schema_reconciliation.sql` (append)

`trade_profile_model.dart:60-71` upserts `crew_size, hourly_rate_min, hourly_rate_max, hourly_rate_visible, service_radius_km`. None exist — `profile_remote_datasource.dart:101` upsert PostgREST-400s. Schema has legacy `hourly_rate`/`day_rate` (kept, unused by the model — left nullable, no drop needed).

- [ ] **Step 1: Append the trade_profiles section**

```sql

-- ---------- trade_profiles (profile save contract) ----------
-- trade_profile_model.dart:60-71 upsert payload. Defaults mirror the
-- model's fromJson fallbacks (crew_size ?? 1, service_radius_km ?? 50,
-- hourly_rate_visible ?? true).
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS crew_size           int           NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS hourly_rate_min     numeric(10,2),
  ADD COLUMN IF NOT EXISTS hourly_rate_max     numeric(10,2),
  ADD COLUMN IF NOT EXISTS hourly_rate_visible boolean       NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS service_radius_km   int           NOT NULL DEFAULT 50;
```

- [ ] **Step 2: Apply and verify**

```bash
supabase db reset
q "select count(*) from information_schema.columns where table_name='trade_profiles' and column_name in ('crew_size','hourly_rate_min','hourly_rate_max','hourly_rate_visible','service_radius_km')"
```
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000001_schema_reconciliation.sql
git commit -m "fix(schema): add trade_profiles rate/crew/radius cols (profile save)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6C: Dart — drop `email` from the `profiles` select

**Files:**
- Modify: `lib/features/profile/data/datasources/profile_remote_datasource.dart:36`
- Test: `test/features/profile/profile_remote_datasource_test.dart` (create if absent — see Step 1)

`email` is canonical in `auth.users` (merged at `auth_remote_datasource.dart:108`); selecting `profiles.email` is a hard PostgREST 400. Remove it; keep `phone`/`bio` (now real after 6A).

- [ ] **Step 1: Write/extend the failing test**

If `test/features/profile/profile_remote_datasource_test.dart` does not exist, create it with a test asserting the select string contains no `email`. Minimal, dependency-light (string assertion on the source — no Supabase mock needed):

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profiles select does not request email (canonical in auth.users)', () {
    final src = File(
      'lib/features/profile/data/datasources/profile_remote_datasource.dart',
    ).readAsStringSync();
    final selectLine = RegExp(r"\.select\(\s*'([^']*profiles?[^']*|[^']*display_name[^']*)'")
        .firstMatch(src)?.group(1) ?? src;
    expect(
      RegExp(r"\bemail\b").hasMatch(
        RegExp(r"\.from\('profiles'\)[\s\S]*?\.select\(\s*'([^']*)'")
            .firstMatch(src)!.group(1)!,
      ),
      isFalse,
      reason: 'profiles .select() must not request email — it lives in auth.users',
    );
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/features/profile/profile_remote_datasource_test.dart`
Expected: FAIL — current select still contains `email`.

- [ ] **Step 3: Make the edit**

In `lib/features/profile/data/datasources/profile_remote_datasource.dart:36`, change the select string from:

```dart
            'id, display_name, email, phone, phone_verified_at, avatar_url, bio, onboarding_completed_at, created_at, updated_at',
```

to:

```dart
            'id, display_name, phone, phone_verified_at, avatar_url, bio, onboarding_completed_at, created_at, updated_at',
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/features/profile/profile_remote_datasource_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/data/datasources/profile_remote_datasource.dart test/features/profile/profile_remote_datasource_test.dart
git commit -m "fix(profile): drop email from profiles select (canonical in auth.users)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: F-RLS-01 — kill admin self-promotion

**Files:**
- Create: `supabase/migrations/20260516000002_forbid_self_admin.sql`

Current `handle_new_user` (`20260512000002_handle_new_user_role_optional.sql:34`) does `IF v_role IN ('builder','trade','admin')` on attacker-controlled `raw_user_meta_data`. A `curl … /auth/v1/signup` with `"role":"admin"` yields a real `user_role:admin` JWT.

- [ ] **Step 1: Write the migration**

Create `supabase/migrations/20260516000002_forbid_self_admin.sql`. This `CREATE OR REPLACE`s the function with `'admin'` removed (rest of body identical to the 20260512000002 version) and adds a defence-in-depth BEFORE-INSERT trigger:

```sql
-- ============================================================
-- Migration: forbid self-assigned admin (F-RLS-01)
-- Closes the signup-trigger admin backdoor. Defence in depth:
--   1. handle_new_user no longer honours role='admin' from metadata
--   2. forbid_self_admin trigger blocks ANY non-superuser admin INSERT
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name text;
  v_role         text;
BEGIN
  v_display_name := NEW.raw_user_meta_data->>'full_name';
  v_role         := NEW.raw_user_meta_data->>'role';

  INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, v_display_name)
    ON CONFLICT (id) DO NOTHING;

  -- 'admin' intentionally NOT accepted from client metadata (F-RLS-01).
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id)
        VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name) ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Defence in depth: nothing self-serve may write an admin role row.
CREATE OR REPLACE FUNCTION public.forbid_self_admin()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role = 'admin' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_roles_forbid_self_admin ON public.user_roles;
CREATE TRIGGER user_roles_forbid_self_admin
  BEFORE INSERT ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.forbid_self_admin();
```

> Note: admins are provisioned out-of-band (manual SQL / migration as superuser, which bypasses row triggers via `session_replication_role` only if explicitly set — a plain superuser INSERT still fires the trigger, so admin provisioning must use a dedicated seeding path. Flag to Ken: confirm the admin-provisioning mechanism — open question rls Q1. This trigger is correct for blocking *self-serve* escalation regardless.)

- [ ] **Step 2: Apply and verify the trigger blocks admin**

```bash
supabase db reset
q "select count(*) from pg_trigger where tgname='user_roles_forbid_self_admin'"
docker exec "$DBC" psql -U postgres -d postgres -c \
  "insert into public.user_roles (user_id, role) values (gen_random_uuid(),'admin')" \
  2>&1 | grep -c "admin role cannot be self-assigned"
q "select 1 from pg_proc p where p.proname='handle_new_user' and pg_get_functiondef(p.oid) not like '%''admin''%'"
```
Expected: `1` (trigger exists) · `1` (insert rejected with our message) · `1` (function body no longer contains `'admin'`).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260516000002_forbid_self_admin.sql
git commit -m "fix(rls): forbid self-assigned admin role (F-RLS-01)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 8: CI schema-diff guard

**Files:**
- Create: `scripts/schema-diff.sh`
- Create: `supabase/schema.sql` (committed baseline)
- Modify: `scripts/validate.sh`

- [ ] **Step 1: Generate the baseline schema dump**

```bash
supabase db reset
supabase db dump --local --schema public -f supabase/schema.sql
```
Expected: `supabase/schema.sql` written, contains `CREATE TABLE … verification_documents` with `doc_type` and `search_vector`.

- [ ] **Step 2: Write the guard script**

Create `scripts/schema-diff.sh`:

```bash
#!/usr/bin/env bash
# Fails if the live migration set no longer matches supabase/schema.sql.
# Catches schema<->Dart drift regressions (root cause of Sprint 1).
set -euo pipefail
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
supabase db reset >/dev/null 2>&1
supabase db dump --local --schema public -f "$TMP" >/dev/null 2>&1
if ! diff -u supabase/schema.sql "$TMP"; then
  echo "ERROR: schema drift — migrations no longer match supabase/schema.sql." >&2
  echo "If intentional: supabase db dump --local --schema public -f supabase/schema.sql" >&2
  exit 1
fi
echo "schema-diff: OK (migrations match committed schema.sql)"
```

- [ ] **Step 3: Make executable and run it (must pass)**

Run: `chmod +x scripts/schema-diff.sh && bash scripts/schema-diff.sh`
Expected: `schema-diff: OK (migrations match committed schema.sql)`, exit 0.

- [ ] **Step 4: Wire into validate.sh**

In `scripts/validate.sh`, locate the design-system fast-check block and add, immediately after it (only if `supabase` is on PATH so contributors without the CLI aren't blocked):

```bash
if command -v supabase >/dev/null 2>&1; then
  bash scripts/schema-diff.sh
else
  echo "schema-diff: SKIPPED (supabase CLI not installed)"
fi
```

- [ ] **Step 5: Prove the guard catches drift (negative test)**

```bash
echo "-- drift probe" >> supabase/migrations/20260516000001_schema_reconciliation.sql
echo "ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS _drift_probe int;" >> supabase/migrations/20260516000001_schema_reconciliation.sql
bash scripts/schema-diff.sh; echo "exit=$?"
git checkout -- supabase/migrations/20260516000001_schema_reconciliation.sql
```
Expected: prints the diff, `ERROR: schema drift …`, `exit=1`. Then the `git checkout` reverts the probe.

- [ ] **Step 6: Re-confirm clean and commit**

```bash
bash scripts/schema-diff.sh
git add scripts/schema-diff.sh supabase/schema.sql scripts/validate.sh
git commit -m "ci: schema-diff guard to prevent schema<->Dart drift regressions

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
Expected: `schema-diff: OK …` before the commit.

---

### Task 8A: Consolidated idempotent paste-ready SQL

**Files:**
- Create: `supabase/reconciliation.sql`

A single file Ken can paste wholesale into the Supabase dashboard SQL editor (or apply via `psql`) instead of `supabase db push`. Must be safe to run **twice** with no error.

- [ ] **Step 1: Build the consolidated file**

```bash
{
  echo "-- ============================================================"
  echo "-- Jobdun schema reconciliation — CONSOLIDATED, IDEMPOTENT"
  echo "-- Generated $(date +%F) from migrations 20260516000001 + 20260516000002."
  echo "-- Safe to run via supabase db push OR pasted into the SQL editor,"
  echo "-- repeatedly. Pre-launch, no data: additive only."
  echo "-- ============================================================"
  echo
  echo "BEGIN;"
  echo
  cat supabase/migrations/20260516000001_schema_reconciliation.sql
  echo
  cat supabase/migrations/20260516000002_forbid_self_admin.sql
  echo
  echo "COMMIT;"
} > supabase/reconciliation.sql
```

> Note: `ALTER TYPE … ADD VALUE` cannot run inside a transaction block in Postgres. The `document_status … ADD VALUE 'expired'` statement is wrapped in its own `DO $$ … EXCEPTION$$` in migration 1, which **is** allowed inside `BEGIN/COMMIT`. Verify Step 3 catches any violation; if `db reset`-equivalent apply of the consolidated file errors on the enum add, split that one statement out above the `BEGIN;` (it is already idempotent on its own).

- [ ] **Step 2: Apply the consolidated file to a fresh DB**

```bash
supabase db reset --no-seed 2>/dev/null || supabase db reset
docker exec -i "$DBC" psql -U postgres -d postgres < supabase/reconciliation.sql
```
Expected: `COMMIT` (or per-statement notices), no `ERROR`.

- [ ] **Step 3: Prove idempotency — run it a SECOND time**

```bash
docker exec -i "$DBC" psql -U postgres -d postgres < supabase/reconciliation.sql 2>&1 | grep -i "^ERROR" && echo "NOT IDEMPOTENT" || echo "IDEMPOTENT-OK"
```
Expected: `IDEMPOTENT-OK` (zero `ERROR` lines on the second apply).

- [ ] **Step 4: Confirm the full contract still holds after double-apply**

```bash
q "select
  (select count(*) from information_schema.columns where table_name='profiles' and column_name in ('phone','bio'))
  || '/' ||
  (select count(*) from information_schema.columns where table_name='trade_profiles' and column_name in ('crew_size','hourly_rate_min','hourly_rate_max','hourly_rate_visible','service_radius_km'))
  || '/' ||
  (select count(*) from pg_trigger where tgname='user_roles_forbid_self_admin')"
```
Expected: `2/5/1`.

- [ ] **Step 5: Commit**

```bash
git add supabase/reconciliation.sql
git commit -m "chore(db): consolidated idempotent reconciliation.sql (SQL-editor paste path)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 9: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Clean apply of the entire migration set**

Run: `supabase db reset`
Expected: `Finished supabase db reset.`, no errors.

- [ ] **Step 2: Full contract assertion (every drifted column at once)**

```bash
q "select
  (select count(*) from information_schema.columns where table_name='verification_documents' and column_name in ('doc_type','file_path','submitted_at','state','issuer','document_number','issued_date','expiry_date','rejection_reason','review_notes','reviewed_by','reviewed_at','deleted_at'))
  || '/' ||
  (select count(*) from information_schema.columns where table_name='messages' and column_name in ('deleted_at','edited_at'))
  || '/' ||
  (select count(*) from information_schema.columns where table_name='conversations' and column_name in ('status','builder_unread_count','trade_unread_count','last_message_preview','last_message_sender_id'))
  || '/' ||
  (select count(*) from information_schema.columns where table_name='jobs' and column_name='search_vector')
  || '/' ||
  (select count(*) from information_schema.columns where table_name='applications' and column_name='status_changed_at')
  || '/' ||
  (select count(*) from information_schema.columns where table_name='profiles' and column_name in ('phone','bio'))
  || '/' ||
  (select count(*) from information_schema.columns where table_name='trade_profiles' and column_name in ('crew_size','hourly_rate_min','hourly_rate_max','hourly_rate_visible','service_radius_km'))"
```
Expected: `13/2/5/1/1/2/5`.

- [ ] **Step 3: Dart suite + lint + format unchanged and green**

Run: `bash scripts/validate.sh`
Expected: design-system checks pass, `schema-diff: OK`, `dart format` clean, `flutter analyze` no new issues, `flutter test` all pass — including the new `profile_remote_datasource_test.dart` from Task 6C. (The only Dart change is the one-line select edit in Task 6C; any unrelated test failure is environmental — investigate, do not paper over.)

- [ ] **Step 4: Update the drift-warning comments now that the DB enforces the contract**

Per F-SCH-14, two comments now tell the truth and need no change, but `verification_document.dart:3` says `// Matches schema enum doc_type exactly` — verify it is now accurate (the `document_doc_type` enum exists). No code edit required; this step is a confirmation read. If `notifications.type` is referenced as an enum anywhere, leave it (out of scope — F-SCH-04, Phase 1).

Run: `grep -n "Matches schema enum" lib/features/verification/domain/entities/verification_document.dart`
Expected: comment present; `document_doc_type` enum confirmed in Step 2 of Task 1 — comment is now accurate, no action.

---

### Task 10: Open the PR

**Files:** none

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin fix/schema-drift-reconciliation
gh pr create --base main --title "fix: schema-drift reconciliation + admin-backdoor lockdown (Sprint 1)" --body "$(cat <<'EOF'
## Summary
Closes the Sprint 1 launch-blockers from the backend audit (docs/audit/00_EXECUTIVE_SUMMARY.md):
- Reconciles ~25 missing columns so **verification upload, messaging inbox, job search, and the auth/profile feature** work against the real schema (F-SCH-01/02/13, F-RT-01, F-PERF-01).
- Drops the legacy `verification_documents.type/url` NOT NULL — gap in the audit's own proposed SQL; without it uploads still fail.
- Adds `profiles.phone/bio` + `trade_profiles` rate/crew/radius cols (profile load + save were hard-400ing). `email` deliberately NOT duplicated onto `profiles` (canonical in `auth.users`) — the one offending `.select()` is corrected instead (1 line).
- Closes the **admin self-promotion backdoor** (F-RLS-01): `handle_new_user` no longer honours `role:admin`, plus a `forbid_self_admin` trigger.
- Ships a consolidated idempotent `supabase/reconciliation.sql` (SQL-editor paste path) + a **CI schema-diff guard** so this drift class cannot silently return.

Pre-launch, no production data (confirmed) → additive idempotent statements, no backfill, safe to re-run.

## Out of scope (tracked, deferred)
trade_type FK (F-SCH-07), notification enum (F-SCH-04), trust-&-safety tables (Sprint 2), profile-PII RLS scoping (F-RLS-03), builder/trade stat counters (Phase 2), parked social-auth/FTUE WIP (no schema impact) — follow-up branches.

## Test plan
- `supabase db reset` clean; full-contract assertion `13/2/5/1/1/2/5` (Task 9 Step 2)
- `reconciliation.sql` applied twice → `IDEMPOTENT-OK` (Task 8A Step 3)
- `forbid_self_admin` rejects a direct admin INSERT
- `bash scripts/validate.sh` green incl. `schema-diff: OK` and the new profile datasource test

## Migration notes
Two additive migrations (`20260516000001`, `20260516000002`) + consolidated `reconciliation.sql`. One 1-line Dart change (drop `email` from a select). No data migration. Reversible by dropping the added columns/enums/trigger.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Expected: PR URL printed.

---

## Self-Review

**Spec coverage** (Sprint 1 item 1 + auth/profile reconciliation + F-RLS-01):
- verification drift → Task 1 ✓ · messages drift → Task 2 ✓ · conversations drift + F-SCH-13 → Task 3 ✓ · `profiles_public` inbox embed → Task 4 ✓ · `jobs.search_vector` → Task 5 ✓ · `applications.status_changed_at` → Task 6 ✓ · `profiles.phone/bio` → Task 6A ✓ · `trade_profiles` rate/crew → Task 6B ✓ · drop `email` from select → Task 6C ✓ · F-RLS-01 → Task 7 ✓ · CI schema-diff guard → Task 8 ✓ · consolidated idempotent paste SQL → Task 8A ✓ · regression-safe verification → Task 9 ✓.
- The audit's F-SCH-01 NOT NULL gap is explicitly closed (Task 1 Step 1).
- `email` PII-duplication anti-pattern explicitly avoided (Task 6C, not a new column).
- Idempotency is proven, not assumed (Task 8A Step 3 double-apply).
- Deferred items (incl. parked WIP — no schema impact) listed in header + PR body, not silently dropped.

**Placeholder scan:** every SQL block is literal; every assertion has an exact expected scalar; no "TBD"/"handle errors"/"similar to".

**Type consistency:** enum names (`document_doc_type`, `conversation_status`), helper `q()`/`DBC`, file path `20260516000001_schema_reconciliation.sql`, and column names are identical across all tasks. Migration filenames sort after the latest existing (`20260514000003`).

**Known follow-ups to flag to Ken (do not block this plan):** admin-provisioning mechanism (rls Q1) — Task 7 note; `profiles_public` RLS scoping is display-only here, full F-RLS-03 counterparty-scoping is a separate Sprint-1 task.
</content>
</invoke>
