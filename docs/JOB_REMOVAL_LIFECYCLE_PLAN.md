# Job Removal Lifecycle — "Notify + Close" Propagation (Plan)

**Date:** 2026-06-04 · **Branch:** `feat/discovery-trade-search` · **Status:** Approved plan, not yet implemented.

## Context

When a builder "deletes" a job today, the app does a **soft delete only** —
`DeleteJob` → `JobRepository.softDeleteJob` → `UPDATE jobs SET deleted_at = now()`
(`lib/features/jobs/data/datasources/job_remote_datasource.dart:146-152`). The job
just vanishes from feeds (`WHERE deleted_at IS NULL`). **Nothing connected to it is
touched**: applicants' `applications` rows stay `pending`/`shortlisted`, and the
`conversations` that reference the job stay active. Nobody is told. So an applicant
keeps chasing a job that no longer exists, and a chat thread silently points at a
dead job.

The schema's foreign keys (`applications`/`reviews`/`saved_jobs`/`hidden_jobs` =
`ON DELETE CASCADE`, `conversations.job_id` = `ON DELETE SET NULL`) are written for a
**hard** delete that the app never performs, so they never fire.

**Decision (user-approved):** removing a job should **notify + close** — applicants are
told the job was withdrawn, their applications move to a terminal "job closed" state,
and the conversation shows a "this job was closed" banner while the chat itself stays
open. We keep the soft-delete (dispute/audit history) and add server-authoritative
propagation. Intended outcome: no more silent dead-job chasing, and one atomic,
trustworthy removal path.

## Goal / behaviour

A builder removing a job (with or without activity) results in, atomically:

1. Job → `status = 'cancelled'` **and** `deleted_at = now()` (hidden from feeds, retained).
2. Every **non-terminal** application for that job (`pending`, `shortlisted`) →
   terminal `job_closed`.
3. One `notifications` row per affected applicant (`type = 'job_closed'`).
4. Conversations untouched at the data layer; the thread/list UI renders a
   "This job was closed by the builder" banner read from the linked job's state.

Empty jobs (no applicants) flow through the same path — steps 2-3 are simply no-ops.

## Why a server-side RPC (the core architectural choice)

A builder **cannot** update other users' `applications` rows or insert
`notifications` for them under normal RLS. Doing this client-side would need
multiple round-trips, could partially fail, and would fight RLS. So the propagation
lives in **one `SECURITY DEFINER` RPC**, mirroring the established pattern in
`supabase/migrations/20260531000002_review_verification_document_v2.sql` (owner/role
check via `auth.uid()`, validate, update row, insert notification — all in one
transaction). This is the single source of truth and can't be bypassed by the client.

## Design

### 1. New migration — `remove_job` RPC + enum value

New file `supabase/migrations/20260605000001_remove_job.sql`:

- **Add enum value** to `public.application_status`:
  `ALTER TYPE public.application_status ADD VALUE IF NOT EXISTS 'job_closed';`
  (chosen over reusing `'rejected'` so the applicant sees "Job closed", not "You were
  rejected" — distinct actor, distinct analytics). Note: `ALTER TYPE ... ADD VALUE`
  must be committed before the value is used; keep it as its own top-of-file statement
  ahead of the function definition.

- **`CREATE FUNCTION public.remove_job(p_job_id uuid) RETURNS int`**, `SECURITY DEFINER`,
  `SET search_path = public`:
  1. Guard: `SELECT builder_id ... FROM jobs WHERE id = p_job_id AND deleted_at IS NULL`;
     if not found → `RAISE EXCEPTION 'job_not_found'`; if `builder_id <> auth.uid()` →
     `RAISE EXCEPTION 'not_owner' USING errcode = '42501'`. Idempotent on already-removed.
  2. `UPDATE jobs SET status = 'cancelled', deleted_at = now(), updated_at = now()
     WHERE id = p_job_id`.
  3. `UPDATE applications SET status = 'job_closed', updated_at = now()
     WHERE job_id = p_job_id AND status IN ('pending','shortlisted')`
     `RETURNING trade_id` → collect affected applicants.
  4. `INSERT INTO notifications (user_id, type, title, body, data)` one row per affected
     `trade_id` (`type='job_closed'`, body references job title, `data = jsonb_build_object('job_id', p_job_id)`).
  5. Return affected-applicant count.
  - `GRANT EXECUTE ... TO authenticated;` + a DOWN block (drop function; note enum
    values are not removable — document it).

### 2. App data layer — route delete through the RPC

- `lib/features/jobs/data/datasources/job_remote_datasource.dart` — change
  `softDeleteJob` body from the direct `.update({'deleted_at': ...})` to
  `_client.rpc('remove_job', params: {'p_job_id': id})`. Keep the method name/contract
  (the `DeleteJob` use case and `JobRepository` interface stay unchanged).

### 3. Application status — Dart enum

- `lib/features/applications/domain/entities/job_application.dart` — add
  `ApplicationStatus.jobClosed`; add `'Job closed'` to `label`; map `dbValue` →
  `'job_closed'` (special-case it like `declinedByTrade`, since `name` is `jobClosed`);
  add `'job_closed' => jobClosed` to `fromString`. Treat as terminal wherever
  terminal/active is computed (e.g. the home stats "shortlisted" filter and any
  list filtering in `applications` presentation).

### 4. Notifications — new type

- `lib/features/notifications/domain/entities/app_notification.dart` — add
  `NotificationType.jobClosed` with `toDb`/`fromString` mapping `'job_closed'`, plus an
  icon/route case (tapping → the applicant's applications list) consistent with the
  existing `applicationReceived` handling.

### 5. Conversation "job closed" banner

- Surface the linked job's removed state to the messaging UI. The conversation
  list/thread already `LEFT JOIN public.jobs` (see the `get_conversations`-style RPC in
  the messaging/swipe-actions migrations). **Additively** return `job_status` (and/or a
  `job_removed boolean = j.deleted_at IS NOT NULL`) from that RPC, thread it through
  `ConversationModel`/`Conversation` (`lib/features/messaging/data/models/conversation_model.dart`,
  `domain/entities/conversation.dart`), and render a small banner in
  `message_thread_page.dart` / the conversation row when set. No `messages`-table change
  (it has `sender_id NOT NULL`, no system-message support — a banner avoids a fake
  sender).

## Files to modify

- **New:** `supabase/migrations/20260605000001_remove_job.sql` (enum value + `remove_job` RPC).
- `lib/features/jobs/data/datasources/job_remote_datasource.dart` (`softDeleteJob` → RPC).
- `lib/features/applications/domain/entities/job_application.dart` (`jobClosed` enum + mappings).
- `lib/features/notifications/domain/entities/app_notification.dart` (`jobClosed` type + mapping).
- Messaging: the conversation-list RPC migration (additive `job_status`/`job_removed`),
  `conversation_model.dart`, `domain/entities/conversation.dart`, `message_thread_page.dart`
  (+ thread widgets) for the banner.
- Applications presentation: render the `Job closed` state on the applicant's list
  (label + muted/terminal styling, consistent with `rejected`/`withdrawn`).

## Edge cases / guarantees

- **Idempotent:** re-running `remove_job` on an already-removed job is a no-op (guard on
  `deleted_at IS NULL`, and step 3 only touches non-terminal rows).
- **Authorization:** non-owner → `42501`; enforced in the RPC, not the client.
- **Terminal rows preserved:** `hired`/`rejected`/`withdrawn`/`declined_by_trade`
  applications are left as-is (history intact).
- **Conversations + messages preserved** (no destruction) — only a UI banner changes.
- **No hard delete** anywhere — dispute history retained, matching today's intent.

## Verification

- **Migration / RLS (psql or Supabase SQL editor against a scratch project):**
  seed a job + 2 `pending` applicants + 1 conversation. Call
  `select remove_job('<job_id>')` as the owner → returns `2`; assert job is
  `cancelled` + `deleted_at` set, both applications are `job_closed`, 2 `notifications`
  rows of `type='job_closed'` exist, conversation row unchanged. Call as a **non-owner**
  → expect `42501`. Call again as owner → returns `0`, no new notifications (idempotent).
- **Flutter tests** (`flutter test`): a `mocktail`-backed repo test asserting
  `softDeleteJob` invokes `rpc('remove_job', {'p_job_id': id})`; an `ApplicationStatus`
  round-trip test (`dbValue`/`fromString` for `job_closed`); a `NotificationType`
  mapping test. Follow the existing `test/features/...` patterns.
- **Manual e2e** (`flutter run`): as a builder, delete a job that has an applicant →
  the applicant's Applications list shows "Job closed", they receive a `job_closed`
  notification, and the conversation thread shows the banner while the chat stays usable.
- `bash scripts/validate.sh` (design + size + arch + format + analyze + tests) green.

## Out of scope (note, don't build)

- A separate non-deleting **"Cancel"** gesture (status `cancelled`, kept visible in a
  builder "archived/cancelled" tab). Same RPC could power it later by skipping
  `deleted_at`; not needed for the approved behaviour.
- Reconciling the unrelated phantom-stat findings from
  `docs/BUILDER_PROFILE_HOME_AUDIT.md` and the tradie stat-row deletion discussion —
  tracked separately.
