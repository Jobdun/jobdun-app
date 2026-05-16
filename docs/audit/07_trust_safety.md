# Trust & Safety Audit — Jobdun Backend

**Auditor:** trust-safety-auditor
**Date:** 2026-05-16

## Scope

Moderation pipeline (keyword scan, report flow, admin review queue); `reports` table
schema + intake; `user_suspensions` + enforcement (session revoke, login block, content
hiding); per-action/per-user rate limits; verification fraud vectors (duplicate licence
number, AI fakes, reused photos); off-platform contact attempts (phone/email/Telegram in
messages & job descriptions); review/rating abuse (self-review, retaliatory,
review-bombing); admin tooling backend support (admin is a separate web app, not in this
repo); audit log of every admin action.

Framing question applied to every finding: *does this hold at 25,000 AU accounts /
5,000 MAU / 500 DAU, one solo engineer, Supabase Pro, under the Privacy Act 1988 + 13
APPs?*

## Files reviewed

- `docs/audit/00_SCOPE.md` (ground truth)
- `supabase/migrations/20260511000003_applications.sql`
- `supabase/migrations/20260511000005_social.sql` (reviews, verification_documents, notifications)
- `supabase/migrations/20260511000006_rls.sql` (all RLS policies + storage buckets)
- `supabase/migrations/20260512000001_legal_acceptances.sql` (the only admin-read policy in the repo)
- `supabase/migrations/20260514000001_profile_completeness.sql` (`trade_profiles.licence_url` shape)
- `lib/features/reviews/data/datasources/review_remote_datasource.dart`
- `grep` sweep of `lib/` and `supabase/migrations/` for `licence_number`, regex/keyword/moderation/blocklist/Telegram/WhatsApp terms (0 trust-safety hits — the only `RegExp` is a numeric-input sanitiser in `job_detail_page.dart:429`)

Confirmed against the migration set: there is **no `reports`, no `user_suspensions`, no
`moderation_audit_log`, no rate-limit table, no keyword scan, no licence-number column,
and no review completion guard.** Every item below is asserted from physical evidence,
not inference.

---

## Summary

| Severity | Count | Findings |
|---|---|---|
| **P0** | 4 | F-TS-01 (no report intake), F-TS-02 (no suspension/enforcement), F-TS-08 (anyone can review anyone), F-TS-10 (no admin audit log) |
| **P1** | 4 | F-TS-03 (no rate limiting), F-TS-06 (no off-platform/keyword scan), F-TS-07 (no duplicate-licence detection), F-TS-09 (no admin moderation backend) |
| **P2** | 2 | F-TS-04 (no content-hiding model), F-TS-05 (verification fraud — AI fakes / reused photos) |
| **P3** | 1 | F-TS-11 (no abuse-signal telemetry) |

**Overall posture: RED.**

There is **zero** trust-&-safety infrastructure. A reported scam, a harassing user, a
fake licence, or a review-bombing campaign currently has **no intake path, no
enforcement lever, and no audit trail**. For an Australian marketplace putting tradies
on strangers' residential properties, this is a present-tense safety and legal exposure,
not deferred tech debt. The relational core is healthy; the safety layer is greenfield.
Build F-TS-01, F-TS-02, F-TS-08, F-TS-10 before any meaningful public launch.

---

## Findings

### F-TS-01 — No report / flag intake exists anywhere

- **Severity:** P0
- **Status:** MISSING
- **Evidence:** No `reports` table in any of the 17 migrations (`supabase/migrations/`). No `report`/`flag` call site in `lib/`. Confirmed by `00_SCOPE.md` §2 ("No `reports` table").
- **Why it matters at 25k AU users:** With 25k accounts and 200k+ messages, scams, harassment, and dangerous-worksite reports are a *when*, not an *if*. There is no way for a user to report a job, message, profile, or review, and no table to receive it. The only operational answer today is "email the solo engineer", which does not scale, leaves no record, and fails any duty-of-care expectation for a platform sending workers to private homes. Under the Privacy Act an unactioned safety complaint is also a reputational/regulatory liability.
- **Fix (concrete):** Add the migration in the *Paste-ready SQL* section below (`20260516000001_reports.sql`). Add a `reports` data source + `ReportRepository` in a new `lib/features/moderation/` feature; expose a "Report" action on job detail, message long-press, profile, and review cards. Intake is a plain authenticated INSERT (RLS-guarded); resolution is admin-only.
- **Effort:** M
- **Phase:** 0
- **Layman's:** Right now nobody can tell Jobdun "this job is a scam" or "this person is abusing me" — there is no report button and nowhere for a report to go.

### F-TS-02 — No user_suspensions table and no enforcement mechanism

- **Severity:** P0
- **Status:** MISSING
- **Evidence:** No `user_suspensions` table in any migration. No `is_suspended`/`banned_at` column on `profiles` (`20260511000001_initial_schema.sql` + extension migrations). No session-revoke or login-block path (no Edge Functions exist — `00_SCOPE.md` §1). RLS policies key only on `auth.uid() = owner` with no suspension predicate (`20260511000006_rls.sql`).
- **Why it matters at 25k AU users:** Even if a report is received (it can't be — see F-TS-01), there is **no lever to act on it**. A confirmed scammer or abuser cannot be banned, their session cannot be revoked, and their jobs/messages cannot be hidden. The platform can identify bad actors but is structurally incapable of removing them. At 25k users with one engineer, "manually delete the auth user in the dashboard" is the only option — destructive, irreversible, audit-free, and a Privacy Act problem if it deletes a user mid-dispute.
- **Fix (concrete):** Add `20260516000002_user_suspensions.sql` (below). Enforcement layers: (1) a `public.is_suspended(uuid)` SECURITY DEFINER helper; (2) add `AND NOT public.is_suspended(auth.uid())` to write policies (`jobs_insert_own`, `applications_insert_trade`, `messages_insert`, `reviews_insert_reviewer`); (3) hide suspended users' public content via the F-TS-04 predicate; (4) hard session-kill via a future `suspend-user` Edge Function calling `auth.admin.signOut(user_id)` + a banned-email check in the JWT hook. Migration name: `20260516000002_user_suspensions.sql`.
- **Effort:** L
- **Phase:** 0
- **Layman's:** There is no "ban" button and no way to kick a bad user off — once someone is in, the platform cannot remove or silence them.

### F-TS-03 — No rate limiting on any action

- **Severity:** P1
- **Status:** MISSING
- **Evidence:** No `rate_limit_events` table or KV store in any migration. No throttle in the job/application/message/profile/verification data sources (`lib/features/*/data/datasources/`). Confirmed `00_SCOPE.md` §2 ("No rate-limit table / KV").
- **Why it matters at 25k AU users:** Nothing stops a single account from creating 10,000 spam jobs, blasting 50,000 applications, flooding 200,000 messages, or hammering verification uploads. On Supabase Pro this is both a cost/DoS vector (Postgres connections, storage egress on rural-AU 3G) and a quality-of-platform killer — the jobs feed and inboxes become unusable. Target ceilings from scope: job posts ~10/day, applications 50/day, messages 100/hr, profile edits 20/day, verification uploads 5/day.
- **Fix (concrete):** Add `20260516000003_rate_limits.sql` (below) — `rate_limit_events(user_id, action, created_at)` with index `(user_id, action, created_at DESC)`, plus a `public.check_rate_limit(action text, max_count int, window interval)` SECURITY DEFINER function that raises `EXCEPTION` when exceeded. Call it as the first statement of `jobs_insert`, `applications_insert`, `messages_insert`, profile-update, and verification-upload RPCs (wrap these writes in SECURITY DEFINER RPCs so the limit cannot be bypassed by direct PostgREST inserts). A `pg_cron` weekly purge of rows older than 30 days keeps the table small.
- **Effort:** L
- **Phase:** 1
- **Layman's:** One user (or a bot) can spam unlimited jobs, applications, and messages — there's no speed limit on anything.

### F-TS-04 — No content-hiding model for suspended / removed content

- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `jobs` is the only table with `deleted_at` (`00_SCOPE.md` §2 — "No `deleted_at` on `profiles`, `applications`, `messages`, `conversations`"). No `hidden_at`/`moderation_status` column on `jobs`, `reviews`, or `messages`. RLS `jobs_select_open` filters only on `status` + `deleted_at` (`20260511000006_rls.sql:138-147`).
- **Why it matters at 25k AU users:** Enforcement (F-TS-02) needs a way to take a *specific scam job* or *abusive review* down without nuking the whole account. Today moderation can only hard-delete a job (builder soft-delete) — there is no admin-driven hide that survives an audit, no way to hide an abusive message, and reviews have no removal path at all (no UPDATE/DELETE policy on `reviews` — `20260511000006_rls.sql:336-352`).
- **Fix (concrete):** Add `hidden_at timestamptz` + `hidden_reason text` + `hidden_by uuid` to `jobs`, `reviews`, `messages`. Extend public-read RLS with `AND hidden_at IS NULL`. Grant admins UPDATE-to-hide via a `role = 'admin'` policy mirroring the `legal_acceptances` admin pattern (`20260512000001_legal_acceptances.sql:36-46`). Migration: `20260516000004_content_moderation_columns.sql`.
- **Effort:** M
- **Phase:** 1
- **Layman's:** You can't take down one bad job post or one abusive review — it's all-or-nothing, and reviews can't be removed at all.

### F-TS-05 — Verification fraud vectors: AI fakes & reused photos undetectable

- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `verification_documents` stores `type`, `url`, `status` only — no checksum/hash, no EXIF capture, no `expires_at`, no `licence_number` (`20260511000005_social.sql:27-35`). `trade_profiles.licence_url` is a bare storage path (`20260514000001_profile_completeness.sql:34-35`). Approval is a free `status` flip with no Edge Function (`00_SCOPE.md` §2 — `admin-approve-verification` MISSING).
- **Why it matters at 25k AU users:** Jobdun verifies white cards and trade licences for AU construction — a fake licence is a genuine on-site safety and legal liability. There is no perceptual/file hash to catch the same licence image reused across accounts, no structured licence number to cross-check against a state registry, and no expiry, so an expired licence stays "approved" forever. AI-generated licences are increasingly trivial; the platform has zero technical defence.
- **Fix (concrete):** Add to `verification_documents`: `file_sha256 text`, `expires_at date`, `licence_number text`, `reviewed_by uuid`, `reviewed_at timestamptz`, `rejection_reason text`. Unique-ish detection: a non-unique index on `file_sha256` + a `licence_number` lookup feeding the F-TS-07 cross-account check. Capture SHA-256 client-side before upload in `verification_remote_datasource.dart`. Migration: `20260516000005_verification_fraud_columns.sql`. (Manual human review remains the backstop — but give the reviewer the signals.)
- **Effort:** M
- **Phase:** 2
- **Layman's:** A trade can upload a Photoshopped or AI-faked licence (or the same one on ten accounts) and nothing flags it; expired licences stay "verified" forever.

### F-TS-06 — No off-platform-contact / keyword scanning on jobs or messages

- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `grep -rniE "regex|RegExp|telegram|whatsapp|profanity|moderat|keyword|blocklist"` across `lib/features/messaging`, `lib/features/jobs`, `lib/features/reviews` → only hit is a numeric sanitiser at `lib/features/jobs/presentation/pages/job_detail_page.dart:429` (unrelated). No `moderation-keyword-scan` Edge Function (`00_SCOPE.md` §2). No DB trigger scanning `messages.body` or `jobs.description`.
- **Why it matters at 25k AU users:** Marketplaces lose trust-and-safety leverage (and revenue) when users move "cash job, text me on 04xx / Telegram me" off-platform on first contact, escaping reviews, dispute resolution, and verification. It is also the primary scam delivery channel ("pay a deposit to this account"). At 200k+ messages there is no signal, no soft-warning, and no flag-for-review on phone numbers, emails, or messaging-app handles in either job descriptions or DMs.
- **Fix (concrete):** A `BEFORE INSERT` trigger on `messages` and `jobs` calling a `public.scan_contact_leak(text)` function with conservative AU regexes — mobile `(\+?61|0)4\d{8}`, email `\S+@\S+\.\S+`, and `\b(whatsapp|telegram|wechat|signal|insta(gram)?)\b`. On match: set a `contact_flagged boolean` column + auto-create a `reports` row (`target_type`, system reporter UUID) for the queue rather than hard-blocking (avoid false-positive lockout for legitimate "call me on site" coordination). Migration: `20260516000006_contact_leak_scan.sql`. Defer to a queue/Edge Function only if trigger latency hurts on rural-AU 3G writes.
- **Effort:** M
- **Phase:** 1
- **Layman's:** People can swap phone numbers / "message me on Telegram" in jobs and chats to dodge the platform and run scams — nothing notices.

### F-TS-07 — No duplicate-licence-number detection across accounts

- **Severity:** P1
- **Status:** MISSING
- **Evidence:** There is no `licence_number` column anywhere — `grep -rniE "licence_number|license_number"` across `supabase/migrations/` and `lib/` returns 0 rows. Licence is stored only as an opaque `trade_profiles.licence_url` / `verification_documents.url`. With no structured number, cross-account duplicate detection is impossible by construction.
- **Why it matters at 25k AU users:** A common fraud pattern is one valid licence number shared across many fake trade accounts (or a stolen licence reused). Because the number is never captured as data, two accounts claiming the same QBCC/state licence are indistinguishable to the system. At 25k accounts a single compromised licence could front dozens of unverified workers.
- **Fix (concrete):** Depends on F-TS-05's `verification_documents.licence_number`. Add a `public.duplicate_licence_check()` `BEFORE INSERT/UPDATE` trigger that, when a licence doc is submitted, counts other *distinct* `trade_id`s with the same normalised `licence_number` and auto-creates a `reports` row (`target_type='profile'`, system reporter) for the queue if `count > 0`. Do not hard-block (legitimate edge cases exist — e.g. company licence) — surface to human review. Migration folded into `20260516000005_verification_fraud_columns.sql`.
- **Effort:** S (once F-TS-05 lands)
- **Phase:** 2
- **Layman's:** The same licence number can be used on many accounts and the system can't tell, because it never stores the number — only a photo link.

### F-TS-08 — A builder can review a trade who never accepted/completed their job (and vice-versa)

- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `reviews` has only `UNIQUE (job_id, reviewer_id)` and `rating BETWEEN 1 AND 5` (`20260511000005_social.sql:46-56`). RLS insert policy is solely `WITH CHECK (auth.uid() = reviewer_id)` (`20260511000006_rls.sql:347-352`). The data source does a raw `_client.from('reviews').insert(review.toJson())` with **no precondition** (`lib/features/reviews/data/datasources/review_remote_datasource.dart:20-26`). There is **no check** that (a) the reviewer was a party to the job, (b) the reviewee was the counterparty, (c) the application reached `hired`, or (d) the job reached a completed state. `reviews` has no UPDATE/DELETE policy, so a malicious review is also unremovable (ties to F-TS-04).
- **Why it matters at 25k AU users:** Any authenticated user can post a 1-star review against *any* profile for *any* job UUID they can read (jobs are public to all authenticated users — `20260511000006_rls.sql:138-147`). This enables: retaliatory reviews, competitor review-bombing of a rival tradie, and self-/sock-puppet 5-star inflation. Ratings drive who gets hired for work in people's homes — a poisonable rating system is a core-integrity P0 and an unfair-trading exposure under AU consumer law.
- **Fix (concrete):** Replace the raw insert with a SECURITY DEFINER RPC `public.submit_review(p_job_id, p_reviewee_id, p_rating, p_comment)` that asserts: the job exists; `auth.uid()` is either its `builder_id` or the `hired` trade on that job; `p_reviewee_id` is the *other* party; and the job/application is in a terminal state (`jobs.status = 'completed'` or the relevant application `status = 'hired'`). Revoke direct INSERT on `reviews` from `authenticated` and only allow it via the RPC (`EXECUTE` granted). Add an admin UPDATE-to-hide policy (F-TS-04). Migration: `20260516000007_review_completion_guard.sql` (full SQL below).
- **Effort:** M
- **Phase:** 0
- **Layman's:** Anyone can leave a fake 1-star (or 5-star) review on anyone, for a job they were never part of — and it can't be taken down.

### F-TS-09 — No backend support for the (separate) admin web app's moderation queue

- **Severity:** P1
- **Status:** MISSING
- **Evidence:** Admin is a separate web app, intentionally not in this repo (CLAUDE.md; `00_SCOPE.md` §4). The *only* admin-aware backend artefact in the entire schema is the `legal_acceptances` "Admins read all" policy (`20260512000001_legal_acceptances.sql:36-46`). There is no admin-readable `reports` view, no queue ordering/assignment columns, no resolution write path, and no Edge Functions for privileged moderation actions (`00_SCOPE.md` §2).
- **Why it matters at 25k AU users:** Even once `reports`/`user_suspensions` exist, the separate admin app has nothing to call. The `legal_acceptances` migration proves the *pattern* (`EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin')`) but it is applied to exactly one table. A solo engineer running a 25k-user marketplace needs the queue, status transitions, and enforcement to be DB-backed and RLS-gated so the admin app is a thin client, not a place to re-implement authz.
- **Fix (concrete):** Every moderation migration below ships its admin policies inline using the proven `user_roles` admin pattern: admin SELECT on `reports` (the queue), admin UPDATE on `reports` (resolve), admin INSERT on `user_suspensions`, admin SELECT/UPDATE-to-hide on `jobs`/`reviews`/`messages`. Privileged session-kill stays a future Edge Function. No new migration — this is a cross-cutting requirement satisfied by F-TS-01/02/04/10 SQL.
- **Effort:** S (folded into other findings)
- **Phase:** 1
- **Layman's:** The admin website has nothing to plug into — there's no queue, no resolve button, no ban action on the backend for it to use.

### F-TS-10 — No moderation_audit_log: no record of any admin action

- **Severity:** P0
- **Status:** MISSING
- **Evidence:** No `moderation_audit_log` table in any migration (`00_SCOPE.md` §2). No audit trigger on any prospective moderation table (none exist). `legal_acceptances` is the only immutable-audit artefact and it covers consent, not enforcement.
- **Why it matters at 25k AU users:** Every ban, content takedown, and report resolution must be attributable and immutable — for internal accountability, for user appeals, and for Privacy Act / procedural-fairness defensibility when a user disputes "why was I removed". With a solo engineer holding admin rights, an *un-audited* enforcement system is indistinguishable from arbitrary action and is legally indefensible. This must exist *before* enforcement (F-TS-02) goes live, not after.
- **Fix (concrete):** Add `20260516000008_moderation_audit_log.sql` (below) — append-only `moderation_audit_log(actor_id, action, target_type, target_id, before, after, reason, created_at)`, RLS admin-read-only, **no UPDATE/DELETE policy at all** (immutable like `legal_acceptances`). Write to it from inside every moderation SECURITY DEFINER RPC (resolve report, create suspension, hide content) in the same transaction so an action and its log entry are atomic.
- **Effort:** S
- **Phase:** 0
- **Layman's:** If an admin bans someone or deletes a post, there is no tamper-proof record of who did it, when, or why.

### F-TS-11 — No abuse-signal telemetry / dashboards

- **Severity:** P3
- **Status:** MISSING
- **Evidence:** No analytics/observability package in `pubspec.yaml` (`00_SCOPE.md` §2 — no Sentry/PostHog). No aggregate views over reports/rate-limit events (neither table exists yet).
- **Why it matters at 25k AU users:** Once F-TS-01/03/06 land, the solo engineer needs to *see* trends — report spikes, rate-limit-hit users, contact-leak rates — without hand-querying Postgres. Not launch-blocking, but real operational cost without it.
- **Fix (concrete):** After F-TS-01/03 land, add read-only aggregate views (`v_reports_open_by_age`, `v_rate_limit_offenders_24h`) the admin app charts. Defer until the underlying tables exist.
- **Effort:** S
- **Phase:** 3
- **Layman's:** Even after we add reports and limits, nobody can see at a glance whether abuse is spiking.

---

## Cross-cutting recommendations

1. **Build order is non-negotiable: audit log first.** Ship F-TS-10 (`moderation_audit_log`) in the *same* migration batch as, or before, F-TS-02 enforcement. Never have a ban path without an immutable record.
2. **Funnel every write through SECURITY DEFINER RPCs.** Reviews (F-TS-08), rate-limited actions (F-TS-03), and suspensions (F-TS-02) must not be raw PostgREST inserts. The repo already uses this pattern correctly (`append_portfolio_url` / `remove_portfolio_url`, `20260514000003`) — extend it. RLS alone cannot express "only after job completion" or "max 10/day".
3. **Reuse the proven admin pattern, do not invent one.** `legal_acceptances` already establishes `EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin')`. Every admin policy below copies it verbatim — one consistent, audited authz primitive for the separate admin web app.
4. **Auto-file, don't auto-block.** Keyword/duplicate-licence detection (F-TS-06/07) should create `reports` rows for human review, not hard-block writes — false positives on rural-AU "call me on site" coordination would be worse than the abuse.
5. **A `system` actor UUID.** Several auto-generated reports need a non-user reporter. Seed a fixed UUID (e.g. `00000000-0000-0000-0000-000000000000`) and document it; reference it from triggers.
6. **Phase 0 minimum viable safety = F-TS-01 + F-TS-02 + F-TS-08 + F-TS-10.** Do not launch publicly without these four.

---

## Open questions for Ken

1. **Suspension semantics:** hard session-kill on suspend (requires an Edge Function calling `auth.admin.signOut` — none exist yet) vs. soft (block all writes via RLS, let the current JWT expire naturally, ≤1h)? Soft is shippable today with no Edge Function; hard needs the edge-functions workstream.
2. **Licence-number source of truth:** is the QBCC/state licence number something trades type in (verifiable, enables F-TS-07) or only ever a photo? Cross-account duplicate detection is impossible without the structured field.
3. **Review eligibility rule:** confirm the exact gate — `jobs.status = 'completed'`, or `applications.status = 'hired'`, or both must hold before either party can review? F-TS-08's RPC needs the precise predicate.
4. **System actor UUID:** OK to seed `00000000-0000-0000-0000-000000000000` as the `system` reporter, or do you want a real service profile row?
5. **Admin app authz:** does the separate admin web app authenticate as a Supabase user carrying `user_roles.role = 'admin'` (so the policies below Just Work), or via service-role from a server? This decides whether RLS admin policies are sufficient or an Edge Function tier is mandatory.

---

## Paste-ready migration SQL

> All migrations are idempotent (`IF NOT EXISTS`, `DO $$ … EXCEPTION WHEN duplicate_object`)
> to match the repo's existing convention. Admin policies copy the proven
> `legal_acceptances` pattern verbatim. Apply in filename order.

### `supabase/migrations/20260516000001_reports.sql`

```sql
-- ============================================================
-- Trust & Safety: moderation report intake
-- ============================================================

DO $$ BEGIN
  CREATE TYPE public.report_target_type AS ENUM ('job', 'message', 'profile', 'review');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.report_reason AS ENUM (
    'spam', 'scam_or_fraud', 'harassment_or_abuse', 'off_platform_contact',
    'fake_credentials', 'inappropriate_content', 'safety_concern', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.report_status AS ENUM ('open', 'triaging', 'actioned', 'dismissed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_type   public.report_target_type NOT NULL,
  target_id     uuid NOT NULL,                 -- FK enforced in app/RPC (polymorphic)
  reason        public.report_reason NOT NULL,
  evidence_text text,
  status        public.report_status NOT NULL DEFAULT 'open',
  resolved_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  resolved_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- One open report per reporter per target (prevents report-spam by one user)
CREATE UNIQUE INDEX IF NOT EXISTS reports_one_open_per_reporter_target
  ON public.reports (reporter_id, target_type, target_id)
  WHERE status IN ('open', 'triaging');

CREATE INDEX IF NOT EXISTS reports_status_created_idx
  ON public.reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS reports_target_idx
  ON public.reports (target_type, target_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can file a report as themselves.
DO $$ BEGIN
  CREATE POLICY "reports_insert_own"
    ON public.reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Reporters can see the reports they filed (status visibility).
DO $$ BEGIN
  CREATE POLICY "reports_select_own"
    ON public.reports FOR SELECT
    USING (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admins see the whole queue.
DO $$ BEGIN
  CREATE POLICY "reports_select_admin"
    ON public.reports FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admins resolve reports.
DO $$ BEGIN
  CREATE POLICY "reports_update_admin"
    ON public.reports FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles
                        WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### `supabase/migrations/20260516000002_user_suspensions.sql`

```sql
-- ============================================================
-- Trust & Safety: user suspensions + enforcement helper
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_suspensions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      text NOT NULL,
  report_id   uuid REFERENCES public.reports(id) ON DELETE SET NULL,
  started_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz,                 -- NULL = indefinite ban
  lifted_at   timestamptz,                 -- non-NULL = manually lifted early
  admin_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_suspensions_user_idx
  ON public.user_suspensions (user_id, started_at DESC);

-- Active = started, not lifted, not expired.
CREATE OR REPLACE FUNCTION public.is_suspended(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_suspensions s
    WHERE s.user_id = p_user
      AND s.lifted_at IS NULL
      AND s.started_at <= now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
  );
$$;

ALTER TABLE public.user_suspensions ENABLE ROW LEVEL SECURITY;

-- A user can see their own suspension (so the app can show "you are suspended").
DO $$ BEGIN
  CREATE POLICY "user_suspensions_select_own"
    ON public.user_suspensions FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admins read all + create suspensions.
DO $$ BEGIN
  CREATE POLICY "user_suspensions_select_admin"
    ON public.user_suspensions FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_suspensions_insert_admin"
    ON public.user_suspensions FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles
                        WHERE user_id = auth.uid() AND role = 'admin')
                AND admin_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_suspensions_update_admin"
    ON public.user_suspensions FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Enforcement: block writes by suspended users. Example for messages;
-- replicate the predicate on jobs_insert_own / applications_insert_trade /
-- reviews submit RPC / profile-update.
DO $$ BEGIN
  CREATE POLICY "messages_insert_not_suspended"
    ON public.messages FOR INSERT
    WITH CHECK (
      auth.uid() = sender_id
      AND NOT public.is_suspended(auth.uid())
      AND EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- NOTE: drop the old "messages_insert" policy after verifying parity, else
-- both policies OR together and the suspension check is bypassed.
```

### `supabase/migrations/20260516000003_rate_limits.sql`

```sql
-- ============================================================
-- Trust & Safety: per-action rate limiting
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rate_limit_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action     text NOT NULL,   -- 'job_post' | 'application' | 'message'
                               -- | 'profile_edit' | 'verification_upload'
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rate_limit_events_lookup_idx
  ON public.rate_limit_events (user_id, action, created_at DESC);

-- Raises an exception when the caller has exceeded max_count in the window.
-- Call as the FIRST statement of each write RPC, then record the event.
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_action    text,
  p_max_count int,
  p_window    interval
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.rate_limit_events
  WHERE user_id = auth.uid()
    AND action  = p_action
    AND created_at > now() - p_window;

  IF v_count >= p_max_count THEN
    RAISE EXCEPTION 'rate_limit_exceeded: % (max % per %)',
      p_action, p_max_count, p_window
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.rate_limit_events (user_id, action)
  VALUES (auth.uid(), p_action);
END;
$$;

-- Suggested ceilings (scope): job_post 10/1 day, application 50/1 day,
-- message 100/1 hour, profile_edit 20/1 day, verification_upload 5/1 day.
-- Example wrapper RPC (replicate per action):
CREATE OR REPLACE FUNCTION public.rl_message_guard()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT public.check_rate_limit('message', 100, interval '1 hour');
$$;

ALTER TABLE public.rate_limit_events ENABLE ROW LEVEL SECURITY;
-- No user-facing policies: only SECURITY DEFINER functions touch this table.
-- Admins may read for the offender dashboard.
DO $$ BEGIN
  CREATE POLICY "rate_limit_events_select_admin"
    ON public.rate_limit_events FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Housekeeping: purge events older than 30 days (run via pg_cron weekly).
-- SELECT cron.schedule('rate_limit_purge','0 3 * * 0',
--   $$DELETE FROM public.rate_limit_events WHERE created_at < now() - interval '30 days'$$);
```

### `supabase/migrations/20260516000007_review_completion_guard.sql`

```sql
-- ============================================================
-- Trust & Safety: only a job party may review the counterparty,
-- and only after the job/application reaches a terminal state.
-- Replaces the unguarded raw INSERT used today.
-- (Confirm the exact terminal-state rule with Ken — see Open Q #3.)
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_review(
  p_job_id      uuid,
  p_reviewee_id uuid,
  p_rating      smallint,
  p_comment     text
) RETURNS public.reviews
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job     public.jobs%ROWTYPE;
  v_hired   uuid;     -- trade_id of the hired application on this job
  v_row     public.reviews%ROWTYPE;
BEGIN
  IF public.is_suspended(auth.uid()) THEN
    RAISE EXCEPTION 'suspended_users_cannot_review' USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO v_job FROM public.jobs WHERE id = p_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job_not_found' USING ERRCODE = 'no_data_found';
  END IF;

  SELECT trade_id INTO v_hired
  FROM public.applications
  WHERE job_id = p_job_id AND status = 'hired'
  LIMIT 1;

  -- Caller must be a party to this job.
  IF auth.uid() NOT IN (v_job.builder_id, v_hired) THEN
    RAISE EXCEPTION 'not_a_party_to_this_job' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Reviewee must be the OTHER party.
  IF NOT (
       (auth.uid() = v_job.builder_id AND p_reviewee_id = v_hired)
    OR (auth.uid() = v_hired          AND p_reviewee_id = v_job.builder_id)
  ) THEN
    RAISE EXCEPTION 'reviewee_must_be_counterparty' USING ERRCODE = 'check_violation';
  END IF;

  -- Job must be in a terminal state. Adjust per Open Q #3.
  IF v_job.status <> 'completed' THEN
    RAISE EXCEPTION 'job_not_completed' USING ERRCODE = 'check_violation';
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'rating_out_of_range' USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.reviews (job_id, reviewer_id, reviewee_id, rating, comment)
  VALUES (p_job_id, auth.uid(), p_reviewee_id, p_rating, p_comment)
  RETURNING * INTO v_row;   -- UNIQUE(job_id,reviewer_id) still blocks dupes

  RETURN v_row;
END;
$$;

REVOKE ALL    ON FUNCTION public.submit_review(uuid,uuid,smallint,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_review(uuid,uuid,smallint,text) TO authenticated;

-- Lock down the direct path so the guard cannot be bypassed via PostgREST.
DROP POLICY IF EXISTS "reviews_insert_reviewer" ON public.reviews;

-- Admin: hide an abusive review (no hard delete — auditable).
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS hidden_at     timestamptz;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS hidden_by     uuid;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS hidden_reason text;

DROP POLICY IF EXISTS "reviews_select_authenticated" ON public.reviews;
DO $$ BEGIN
  CREATE POLICY "reviews_select_authenticated"
    ON public.reviews FOR SELECT
    USING (auth.role() = 'authenticated' AND hidden_at IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reviews_update_admin"
    ON public.reviews FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### `supabase/migrations/20260516000008_moderation_audit_log.sql`

```sql
-- ============================================================
-- Trust & Safety: immutable audit of every admin moderation action.
-- Mirrors the legal_acceptances immutability pattern: admin-read,
-- NO update/delete policy at all.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.moderation_audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  action      text NOT NULL,   -- 'resolve_report' | 'suspend_user'
                                -- | 'lift_suspension' | 'hide_job'
                                -- | 'hide_review' | 'hide_message'
  target_type text NOT NULL,
  target_id   uuid NOT NULL,
  before      jsonb,
  after       jsonb,
  reason      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS moderation_audit_log_target_idx
  ON public.moderation_audit_log (target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS moderation_audit_log_actor_idx
  ON public.moderation_audit_log (actor_id, created_at DESC);

ALTER TABLE public.moderation_audit_log ENABLE ROW LEVEL SECURITY;

-- Admins read only. Writes happen exclusively inside SECURITY DEFINER
-- moderation RPCs (same txn as the action). NO update/delete policy —
-- the log is append-only and tamper-evident by construction.
DO $$ BEGIN
  CREATE POLICY "moderation_audit_log_select_admin"
    ON public.moderation_audit_log FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.user_roles
                   WHERE user_id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```
