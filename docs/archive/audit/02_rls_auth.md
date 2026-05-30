# RLS & Authorization Audit — Jobdun Backend

**Auditor:** rls-auth-auditor
**Scope:** Row Level Security on every table; per-role/per-operation policy correctness; `auth.uid()`/`auth.jwt()` usage; role determination (JWT claim ← `user_roles` + `custom_access_token` hook); service-role key exposure; privileged/admin operations (no Edge Functions exist); storage bucket policies; session management.
**Files reviewed:**
- `supabase/migrations/20260511000001_initial_schema.sql`
- `supabase/migrations/20260511000002_jobs.sql`
- `supabase/migrations/20260511000003_applications.sql`
- `supabase/migrations/20260511000004_messaging.sql`
- `supabase/migrations/20260511000005_social.sql`
- `supabase/migrations/20260511000006_rls.sql`
- `supabase/migrations/20260511000007_handle_new_user_trigger.sql`
- `supabase/migrations/20260511000008_custom_access_token_hook.sql`
- `supabase/migrations/20260511000009_rls_patch.sql`
- `supabase/migrations/20260512000001_legal_acceptances.sql`
- `supabase/migrations/20260512000002_handle_new_user_role_optional.sql`
- `supabase/migrations/20260512000003_trade_categories.sql`
- `supabase/migrations/20260512000004_token_hook_role_optional.sql`
- `supabase/migrations/20260512000005_profile_extended_columns.sql`
- `supabase/migrations/20260514000001_profile_completeness.sql`
- `supabase/migrations/20260514000002_phone_verified_sync.sql`
- `supabase/migrations/20260514000003_portfolio_array_helpers.sql`
- `lib/core/config/supabase_config.dart`
- `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- `lib/features/auth/data/models/user_model.dart`
- `lib/features/auth/domain/entities/user_role.dart`
- `lib/features/auth/presentation/providers/auth_provider.dart`
- `lib/features/profile/data/datasources/profile_remote_datasource.dart`
- `grep -rniE "service_role|SERVICE_ROLE|serviceRole" lib/` (1 hit, comment-only)

**Date:** 2026-05-15

---

## Summary

| Severity | Count |
|---|---|
| **P0** | 4 |
| **P1** | 4 |
| **P2** | 4 |
| **P3** | 2 |

**Overall posture: RED.**

The relational core has RLS enabled on every application table and the ownership model for the *happy path* is sound (`auth.uid() = id`). But there are **four present-tense P0 holes**: (1) any user can self-promote to **admin** through the sign-up metadata path that the `handle_new_user` trigger still trusts; (2) a trade can mark **their own verification documents `approved`** and their **`trade_profiles.is_verified = true`** — there is no admin gate anywhere because there are zero Edge Functions; (3) **every authenticated user can read every other user's full builder/trade profile including `contact_phone`** — a 25k-row PII directory exposed to any account, an APP 6/APP 11 problem under the Privacy Act 1988; (4) `UPDATE` policies on `applications`, `messages`, `jobs`-adjacent rows lack `WITH CHECK`, letting the row be mutated into a state the writer should not control (e.g. a trade rewriting `builder_id`, status, or `rejection_reason`). The good news: no service-role key in the app, PKCE flow, self-direct-write escalation on `user_roles` is correctly blocked at the policy level, and the `legal_acceptances` immutability + admin-read model is correct.

The headline answers to the scope questions are in **Direct Answers** below; each maps to a finding.

---

## Direct Answers to Scope Questions

1. **RLS ENABLED on every user-accessible table?** Yes for all 13 tables and `storage.objects`. `trade_categories` is RLS-enabled with an authenticated read policy. The `profile_completeness` **view** has no RLS of its own but is `security_invoker = on` and self-scoped via `WHERE p.id = auth.uid()` — acceptable (see F-RLS-11, PASS-WITH-NOTE). **No table is missing RLS.**
2. **Can a Trade read another Trade's private profile data?** **Yes — P0.** `trade_profiles_select_authenticated` is `USING (auth.role() = 'authenticated')`. Any logged-in user reads every `trade_profiles` row including `contact_phone`, `base_suburb`, `about`, rates. → **F-RLS-03**.
3. **Can a Builder read Applications to jobs they didn't post?** **No.** `applications_select` is `auth.uid() = trade_id OR auth.uid() = builder_id`, and `applications.builder_id` is a stored column FK'd to the job's builder. Correct *for reads* — but see F-RLS-05 (the trade sets `builder_id` on INSERT, and a malicious value there poisons the model, not cross-job reads).
4. **Can a Trade modify a Job they didn't create?** **No.** `jobs_update_own` / `jobs_insert_own` / `jobs_delete_own` all gate on `auth.uid() = builder_id` with matching `WITH CHECK`. PASS. → noted in F-RLS-09.
5. **Can a user modify their own role column (self-promote to admin)?** **Via the `user_roles` table: No** — `user_roles_insert_own`/`user_roles_update_own` both enforce `role IN ('builder','trade')`. **Via the sign-up trigger: YES — P0.** `handle_new_user` still does `IF v_role IN ('builder','trade','admin')` on client-supplied `raw_user_meta_data->>'role'`. → **F-RLS-01**.
6. **Are admin actions gated behind an Edge Function or non-self-assignable claim?** **No — P0.** Zero Edge Functions exist. The only admin-gated policy in the entire schema is `legal_acceptances` "Admins read all acceptances". There is **no policy** that lets an admin approve verification docs, change document status, suspend users, or moderate — and worse, the *owner* can do the approval themselves (F-RLS-02). The `admin` claim itself is non-self-assignable *through `user_roles` RLS* but **is** self-assignable through the trigger (F-RLS-01).
7. **Can a Builder enumerate all Trades' contact details (PII leak)?** **Yes — P0.** Same broad SELECT as Q2; `contact_phone` was added to both `builder_profiles` and `trade_profiles` in `20260512000005`. Any of the 25k accounts can scrape the full contact directory. → **F-RLS-03**.
8. **Are `deleted_at` rows filtered in policies or only queries?** **Only `jobs` has `deleted_at`**, and it is filtered *in the policy* (`jobs_select_open` requires `deleted_at IS NULL`) — good. **But** `jobs_select_own` returns soft-deleted rows to the owner with no filter (acceptable for owner), and there is **no `deleted_at` on profiles/applications/messages/conversations** so soft-delete is not a cross-table concern yet. → F-RLS-10 (PASS-WITH-NOTE).
9. **Does `messages` SELECT correctly prevent third-party read?** **Yes.** `messages_select` requires an `EXISTS` on `conversations` where the caller is `builder_id` or `trade_id`. A third party cannot read. PASS. The gap is `messages_update_read` has no `WITH CHECK` (F-RLS-06).

---

## Findings

### F-RLS-01 — Sign-up trigger trusts client-supplied `role`, allowing self-promotion to `admin`
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `supabase/migrations/20260512000002_handle_new_user_role_optional.sql:31` — `IF v_role IN ('builder', 'trade', 'admin') THEN INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, v_role)`. `v_role` is read at line 23 from `NEW.raw_user_meta_data->>'role'`, which is fully attacker-controlled (`supabase.auth.signUp(data: {...})`). The original trigger `20260511000007_handle_new_user_trigger.sql:23` has the same `'admin'` acceptance. The Flutter `register()` only sends `full_name` (`auth_remote_datasource.dart:55`), but the trigger has no way to know that — any client (curl against `/auth/v1/signup`) can send `"data":{"role":"admin"}`.
- **Why it matters at 25k AU users:** This is a full privilege-escalation vector: a brand-new anonymous sign-up becomes an `admin` whose JWT carries `user_role: admin`, which then satisfies the `legal_acceptances` admin-read policy and **every future admin policy** (verification approval, moderation, the separate admin web app). One engineer on call, 25k accounts, Australian PII — a single crafted sign-up reads the entire legal-consent audit trail and any admin-gated data. The `user_roles` RLS correctly blocks this for direct writes, but the SECURITY DEFINER trigger bypasses RLS, so the front door is wide open.
- **Fix (concrete):** New migration `supabase/migrations/20260516000001_trigger_reject_admin.sql`:
```sql
-- handle_new_user must NEVER honour a client-supplied 'admin' role.
-- Admin is provisioned out-of-band (manual SQL by Ken or the admin web app
-- using the service role), never via self-service sign-up metadata.
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

  -- Only self-selectable roles are honoured from sign-up metadata.
  -- 'admin' is explicitly excluded — if a client sends it, treat as no role
  -- (SSO/role-selection sheet path) rather than granting it.
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id) VALUES (NEW.id)
        ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name) ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Defence in depth: forbid 'admin' from ever entering user_roles via the
-- self-service paths. Keep the CHECK enum (it still allows 'admin' for
-- service-role/manual provisioning) but add a trigger guard that blocks the
-- 'authenticated' role from inserting/updating an admin row.
CREATE OR REPLACE FUNCTION public.forbid_self_admin()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role = 'admin'
     AND current_setting('request.jwt.claim.role', true) = 'authenticated' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_roles_forbid_self_admin ON public.user_roles;
CREATE TRIGGER user_roles_forbid_self_admin
  BEFORE INSERT OR UPDATE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.forbid_self_admin();
```
Also remove `admin` from the client `UserRole` enum's self-selectable surface, or at minimum assert it is never passed to the `user_roles` upsert in `auth_provider.dart:571,873`.
- **Effort:** S
- **Phase:** 0
- **Layman's:** Right now anyone signing up can secretly tick a hidden "make me an admin" box, and the database believes them.

---

### F-RLS-02 — A trade can self-approve their own verification documents and set `is_verified = true`
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:**
  - `supabase/migrations/20260511000006_rls.sql:325-331` — `verification_documents_update_own ... USING (auth.uid() = trade_id) WITH CHECK (auth.uid() = trade_id)`. Nothing pins `status`; the owner can `UPDATE verification_documents SET status='approved' WHERE trade_id = auth.uid()`.
  - `supabase/migrations/20260511000006_rls.sql:124-130` — `trade_profiles_update_own ... USING (auth.uid() = id) WITH CHECK (auth.uid() = id)`. `trade_profiles.is_verified` (`20260511000001_initial_schema.sql:45`) is a plain column with no column-level restriction, so the owner can flip themselves to `is_verified = true`.
  - No Edge Functions exist (`supabase/functions/` absent per `00_SCOPE.md:33`), so no privileged approval path exists at all.
- **Why it matters at 25k AU users:** Verification ("White Card", public liability, trade licence) is the platform's core trust signal — builders hire based on it, and `jobs.requires_verified` defaults `true`. If trades can self-stamp `approved`/`is_verified`, the entire verification system is cosmetic: an unlicensed worker appears licensed on a construction site. That is a safety and liability exposure in the Australian trades context, and the solo engineer has no audit trail to detect it (no `moderation_audit_log`).
- **Fix (concrete):** Restrict the owner to *inserting* and *replacing the file*, never to changing `status`; make `status` and `is_verified` writable only by `admin`. New migration `supabase/migrations/20260516000002_verification_status_lockdown.sql`:
```sql
-- Owner may insert and may update only the document URL/type, never status.
DROP POLICY IF EXISTS "verification_documents_update_own"
  ON public.verification_documents;

CREATE POLICY "verification_documents_update_own_no_status"
  ON public.verification_documents FOR UPDATE
  USING (auth.uid() = trade_id)
  -- WITH CHECK can't reference OLD; enforce status immutability via trigger.
  WITH CHECK (auth.uid() = trade_id);

CREATE OR REPLACE FUNCTION public.lock_verification_status()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Only an admin JWT may change status. Everyone else keeps OLD.status.
  IF NEW.status IS DISTINCT FROM OLD.status
     AND COALESCE(
           (auth.jwt() -> 'user_role')::text, '"none"') <> '"admin"' THEN
    RAISE EXCEPTION 'only an admin may change verification status'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS verification_documents_lock_status
  ON public.verification_documents;
CREATE TRIGGER verification_documents_lock_status
  BEFORE UPDATE ON public.verification_documents
  FOR EACH ROW EXECUTE FUNCTION public.lock_verification_status();

-- Admin may UPDATE any verification document (the approval action).
CREATE POLICY "verification_documents_admin_update"
  ON public.verification_documents FOR UPDATE
  USING ( (auth.jwt() ->> 'user_role') = 'admin' )
  WITH CHECK ( (auth.jwt() ->> 'user_role') = 'admin' );

CREATE POLICY "verification_documents_admin_select"
  ON public.verification_documents FOR SELECT
  USING ( (auth.jwt() ->> 'user_role') = 'admin' );

-- is_verified is a derived trust flag — owner must not set it.
CREATE OR REPLACE FUNCTION public.lock_is_verified()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified
     AND COALESCE(
           (auth.jwt() -> 'user_role')::text, '"none"') <> '"admin"' THEN
    RAISE EXCEPTION 'is_verified is admin-controlled'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trade_profiles_lock_is_verified
  ON public.trade_profiles;
CREATE TRIGGER trade_profiles_lock_is_verified
  BEFORE UPDATE ON public.trade_profiles
  FOR EACH ROW EXECUTE FUNCTION public.lock_is_verified();
```
Longer term this approval belongs in an `admin-approve-verification` Edge Function (see edge-functions-auditor) so the admin web app calls it with service role and writes a `moderation_audit_log` row; the RLS above is the Phase-0 stopgap.
- **Effort:** M
- **Phase:** 0
- **Layman's:** A worker can currently tick "my licence is approved" themselves — the verification badge means nothing.

---

### F-RLS-03 — Every authenticated user can read every builder/trade profile incl. `contact_phone` (PII directory)
- **Severity:** P0
- **Status:** RISKY
- **Evidence:**
  - `supabase/migrations/20260511000006_rls.sql:82-87` — `builder_profiles_select_authenticated ... USING (auth.role() = 'authenticated')`.
  - `supabase/migrations/20260511000006_rls.sql:110-115` — `trade_profiles_select_authenticated ... USING (auth.role() = 'authenticated')`.
  - `supabase/migrations/20260512000005_profile_extended_columns.sql:16-29` adds `contact_name`, `contact_phone` to `builder_profiles` and `about`/location to both; `trade_profiles` also holds `hourly_rate`, `day_rate`, `bio`.
- **Why it matters at 25k AU users:** A single authenticated account can `SELECT id, contact_name, contact_phone, service_suburb FROM builder_profiles` (and the trade equivalent) and walk the entire table — there is no per-row predicate. That is a harvestable directory of ~25k Australians' phone numbers and locations exposed to anyone who signs up. Under the Privacy Act 1988, APP 6 (use/disclosure) and APP 11 (security) make broad exposure of personal contact data a reportable problem if scraped; at 5,000 MAU this is a realistic competitor/spam target. PostgREST gives the attacker pagination for free.
- **Fix (concrete):** Contact data should only be visible to a counterparty with an active relationship (an application or conversation), not the world. Split the policy: a *public* projection (display name, primary trade, avatar — needed for application/conversation joins) and a *contact* gate. Cleanest is a security-definer RPC or view exposing only non-PII columns and a relationship-scoped policy for the rest. New migration `supabase/migrations/20260516000003_profile_pii_scope.sql`:
```sql
-- Replace the blanket authenticated read with a relationship-scoped one.
DROP POLICY IF EXISTS "trade_profiles_select_authenticated"
  ON public.trade_profiles;
DROP POLICY IF EXISTS "builder_profiles_select_authenticated"
  ON public.builder_profiles;

-- A user always reads their own full row.
CREATE POLICY "trade_profiles_select_own"
  ON public.trade_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "builder_profiles_select_own"
  ON public.builder_profiles FOR SELECT USING (auth.uid() = id);

-- A counterparty reads a trade's row only if they share an application
-- or a conversation (i.e. a real working relationship exists).
CREATE POLICY "trade_profiles_select_counterparty"
  ON public.trade_profiles FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.applications a
            WHERE a.trade_id = trade_profiles.id
              AND a.builder_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.conversations c
            WHERE c.trade_id = trade_profiles.id
              AND c.builder_id = auth.uid())
  );

CREATE POLICY "builder_profiles_select_counterparty"
  ON public.builder_profiles FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.applications a
            WHERE a.builder_id = builder_profiles.id
              AND a.trade_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.conversations c
            WHERE c.builder_id = builder_profiles.id
              AND c.trade_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.jobs j        -- so trades can see the
            WHERE j.builder_id = builder_profiles.id  -- poster of an open job
              AND j.status IN ('open','filled')
              AND j.deleted_at IS NULL)
  );

-- Admin full read.
CREATE POLICY "trade_profiles_select_admin"
  ON public.trade_profiles FOR SELECT
  USING ((auth.jwt() ->> 'user_role') = 'admin');
CREATE POLICY "builder_profiles_select_admin"
  ON public.builder_profiles FOR SELECT
  USING ((auth.jwt() ->> 'user_role') = 'admin');
```
NEEDS HUMAN INPUT: confirm the product wants a trade to see the *builder of an open job* before applying (the third `EXISTS` above) — if a non-PII teaser is preferred, expose those columns through a `security_invoker` view instead and keep `contact_phone` strictly relationship-scoped. The data layer's `eq('id', userId)` self-reads (`profile_remote_datasource.dart`) are unaffected; verify the application/conversation join queries still resolve under the narrower policy before shipping.
- **Effort:** M
- **Phase:** 0
- **Layman's:** Anyone with an account can download every other user's phone number and town.

---

### F-RLS-04 — No admin authorization model exists for any privileged operation
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** Across all 17 migrations, the only policy referencing `role = 'admin'` is `20260512000001_legal_acceptances.sql:36-46`. There is no admin policy for `verification_documents`, `jobs`, `applications`, `reviews`, `profiles`, or moderation. `supabase/functions/` does not exist (`00_SCOPE.md:33,90-92`) — no `admin-approve-verification`, `suspend-user`, `report-content`. The admin web app (out of repo) has nothing server-side to call.
- **Why it matters at 25k AU users:** Every operation the admin web app needs (approve a licence, suspend a fraudulent account, action a report, moderate a review) currently has *no enforcement point*. Either the admin web app will use the service-role key directly (bypassing all RLS, no audit), or the operations don't happen. With one engineer on call and Australian regulatory exposure, "no admin authz layer" means trust-and-safety is unenforceable and uninstrumented. This is the structural root cause behind F-RLS-02.
- **Fix (concrete):** Two-part: (a) the JWT `user_role` claim is the authorization primitive — once F-RLS-01 makes `admin` non-self-assignable, `(auth.jwt() ->> 'user_role') = 'admin'` is a safe predicate; add admin policies on the tables that need moderation (pattern shown in F-RLS-02). (b) Privileged *writes that must be audited* (suspensions, approvals) belong in Edge Functions invoked by the admin app — defer the function bodies to edge-functions-auditor, but the RLS predicate pattern is:
```sql
-- Reusable admin predicate. Define once; reference in admin policies.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT (auth.jwt() ->> 'user_role') = 'admin';
$$;
-- e.g. admin moderation read on reviews:
CREATE POLICY "reviews_admin_all" ON public.reviews
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
```
- **Effort:** L
- **Phase:** 1 (F-RLS-02's stopgap is Phase 0; the full model is Phase 1)
- **Layman's:** There is no defined "admins can do X" anywhere — the admin tools have nothing to safely talk to.

---

### F-RLS-05 — `applications` INSERT lets the trade set an arbitrary `builder_id`; no `WITH CHECK` on UPDATE
- **Severity:** P1
- **Status:** BROKEN
- **Evidence:**
  - `supabase/migrations/20260511000006_rls.sql:197-202` — `applications_insert_trade WITH CHECK (auth.uid() = trade_id)`. `applications.builder_id` (`20260511000003_applications.sql:24`) is a NOT NULL column the trade supplies; nothing checks it equals the job's actual `builder_id`.
  - `supabase/migrations/20260511000006_rls.sql:205-213` — `applications_update USING (auth.uid() = trade_id OR auth.uid() = builder_id)` with **no `WITH CHECK`**. A trade can `UPDATE` their application to `status='hired'`, write `rejection_reason`, or change `builder_id`.
- **Why it matters at 25k AU users:** The `OR auth.uid() = builder_id` read path (Q3) relies on `applications.builder_id` being trustworthy, but the trade sets it. A trade could insert an application with `builder_id` = some victim builder for a job that builder didn't post, polluting that builder's applicant inbox, or set their own status to `hired`. Missing `WITH CHECK` on UPDATE is the classic Postgres RLS footgun (USING gates which rows are visible to update; WITH CHECK gates what the new row may look like — absent, the new row is unconstrained). At 50k+ applications this is a data-integrity and trust problem the single engineer will debug as "ghost applicants".
- **Fix (concrete):** `supabase/migrations/20260516000004_applications_integrity.sql`:
```sql
DROP POLICY IF EXISTS "applications_insert_trade" ON public.applications;
CREATE POLICY "applications_insert_trade"
  ON public.applications FOR INSERT
  WITH CHECK (
    auth.uid() = trade_id
    -- builder_id must be the real poster of the job being applied to.
    AND builder_id = (SELECT j.builder_id FROM public.jobs j
                       WHERE j.id = job_id)
    AND status = 'pending'                 -- can't self-create as 'hired'
  );

DROP POLICY IF EXISTS "applications_update" ON public.applications;
-- Trade may only withdraw / decline; builder may shortlist/reject/hire.
CREATE POLICY "applications_update_trade"
  ON public.applications FOR UPDATE
  USING (auth.uid() = trade_id)
  WITH CHECK (auth.uid() = trade_id
              AND status IN ('withdrawn','declined_by_trade'));
CREATE POLICY "applications_update_builder"
  ON public.applications FOR UPDATE
  USING (auth.uid() = builder_id)
  WITH CHECK (auth.uid() = builder_id
              AND status IN ('shortlisted','rejected','hired','pending'));
```
NEEDS HUMAN INPUT: confirm the exact status-transition matrix per role against `application_status` lifecycle in CLAUDE.md; the lists above are the safe default.
- **Effort:** S
- **Phase:** 1
- **Layman's:** An applicant can currently mark their own application "hired" and aim applications at builders who never posted the job.

---

### F-RLS-06 — `messages` / `notifications` / `conversations` / `profiles` UPDATE policies missing or weak `WITH CHECK`
- **Severity:** P1
- **Status:** RISKY
- **Evidence:**
  - `supabase/migrations/20260511000006_rls.sql:273-284` — `messages_update_read` has `USING (...)` but **no `WITH CHECK`**. Any conversation participant can `UPDATE` *any* column of *any* message in the conversation — including rewriting `body` of the other person's message or changing `sender_id`.
  - `conversations` (`:218-238`) has SELECT + INSERT policies but **no UPDATE and no DELETE policy** — fine for now (no UPDATE allowed = deny), noted for completeness.
  - `profiles_update_own` (`:33-39`) has `WITH CHECK (auth.uid() = id)` but no column restriction — a user can overwrite `onboarding_completed_at` arbitrarily (low impact) — acceptable, noted.
- **Why it matters at 25k AU users:** "Mark as read" must not be a write primitive over the entire message row. With 200k+ messages, a participant editing the counterparty's message body is a tampering/repudiation vector in a marketplace where messages are evidence of agreed scope/price. The fix scopes the UPDATE to the read-receipt fields only.
- **Fix (concrete):** `supabase/migrations/20260516000005_messages_update_scope.sql`:
```sql
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;
CREATE POLICY "messages_update_read"
  ON public.messages FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id
              AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id
              AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid()))
  );

-- Immutable body/sender: only read_at may move. WITH CHECK can't see OLD,
-- so enforce immutability with a BEFORE UPDATE trigger.
CREATE OR REPLACE FUNCTION public.messages_only_read_at_mutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.body IS DISTINCT FROM OLD.body
     OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'only read_at may be updated on a message'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS messages_immutable_body ON public.messages;
CREATE TRIGGER messages_immutable_body
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_only_read_at_mutable();
```
- **Effort:** S
- **Phase:** 1
- **Layman's:** "Mark message read" currently also lets you secretly edit the other person's messages.

---

### F-RLS-07 — `reviews` has no INSERT integrity guard, no UPDATE/DELETE policy, no "only after completion"
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `supabase/migrations/20260511000006_rls.sql:339-352` — `reviews_select_authenticated` (read by anyone authenticated) and `reviews_insert_reviewer WITH CHECK (auth.uid() = reviewer_id)`. There is no check that the reviewer was party to `job_id`, that `reviewee_id` is the counterparty, or that the job is completed. `reviews` has no UPDATE/DELETE policy (so deny — acceptable), but `UNIQUE(job_id, reviewer_id)` only stops duplicates, not fabrication. (Cross-ref trust-safety-auditor.)
- **Why it matters at 25k AU users:** A user can write a review for any `job_id`/`reviewee_id` they choose as long as `reviewer_id = self`. That enables reputation attacks (review-bomb a competitor) and fake positive reviews, with all of them publicly readable. Reputation is the marketplace's core value; with 10k+ jobs this is exploitable at scale and the solo engineer has no moderation tooling (F-RLS-04).
- **Fix (concrete):** `supabase/migrations/20260516000006_reviews_integrity.sql`:
```sql
DROP POLICY IF EXISTS "reviews_insert_reviewer" ON public.reviews;
CREATE POLICY "reviews_insert_reviewer"
  ON public.reviews FOR INSERT
  WITH CHECK (
    auth.uid() = reviewer_id
    AND EXISTS (
      -- reviewer & reviewee were the two parties on a CLOSED/filled job
      SELECT 1 FROM public.jobs j
      JOIN public.applications a
        ON a.job_id = j.id AND a.status = 'hired'
      WHERE j.id = reviews.job_id
        AND j.status IN ('filled','closed')
        AND (
          (j.builder_id = auth.uid() AND a.trade_id = reviews.reviewee_id)
          OR
          (a.trade_id = auth.uid() AND j.builder_id = reviews.reviewee_id)
        )
    )
  );
```
NEEDS HUMAN INPUT: confirm which `job_status` value means "work finished" (CLAUDE.md lifecycle says `Completed`; the enum here is `draft|open|filled|closed|cancelled` — likely `closed`).
- **Effort:** M
- **Phase:** 1
- **Layman's:** Anyone can post a fake 1-star review about any user for any job they were never part of.

---

### F-RLS-08 — Session management: no idle timeout for admins; default refresh-token rotation unverified
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `lib/core/config/supabase_config.dart:24-33` initializes Supabase with only `authFlowType: AuthFlowType.pkce`. No `autoRefreshToken` override (defaults true — fine), no app-level idle/absolute session cap. Refresh-token rotation and JWT TTL are dashboard settings **not determinable from the repo** (`00_SCOPE.md:113-114`). There is no separate, shorter session policy for `admin` sessions, and no client-side inactivity sign-out. The JWT `user_role` claim is only re-evaluated on token refresh (the code force-refreshes after role assignment — `auth_provider.dart:348,889` — good), so a demoted/suspended user keeps elevated access until their access token expires.
- **Why it matters at 25k AU users:** An admin JWT is the keys to the kingdom (F-RLS-04). If an admin's device is left unlocked or a token leaks, a long-lived non-rotating refresh token = indefinite admin access, with one engineer and no SIEM to notice. AU Privacy Act APP 11 expects reasonable access controls on bulk PII. Even for normal users, a suspended account (when F-RLS-04/trust-safety lands) stays usable until token expiry — there is no session-revocation story.
- **Fix (concrete):** (1) NEEDS HUMAN INPUT — confirm in Supabase dashboard: **Auth → Sessions**: enable *refresh token rotation* + *reuse interval*, set a *time-box* (e.g. 8h inactivity / 30d absolute) and a shorter JWT expiry (e.g. 1h). (2) For admin: until admin moves to the web app, force `signOut()` on app background-for-N-minutes for admin-role sessions. (3) On suspension (future), call `auth.admin.signOut(userId)` server-side (Edge Function) to kill the refresh token immediately rather than waiting for JWT expiry. Document the chosen values in `docs/runbooks/`.
- **Effort:** S (config) / M (admin idle + revoke)
- **Phase:** 1
- **Layman's:** A stolen or forgotten admin login can stay valid far too long, and we can't yet instantly kick a banned user out.

---

### F-RLS-09 — `jobs` policies are correct (PASS-WITH-NOTE: soft-deleted rows readable via owner policy, draft visibility)
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `supabase/migrations/20260511000006_rls.sql:138-178`. `jobs_select_open` correctly requires `status IN ('open','filled') AND deleted_at IS NULL`. `jobs_select_own`, `jobs_insert_own`, `jobs_update_own`, `jobs_delete_own` all gate on `auth.uid() = builder_id` with matching `WITH CHECK` on insert/update. A trade cannot modify a job they didn't create (Q4 = No).
- **Why it matters at 25k AU users:** This is the model done right and is the template the broken policies should follow. The only notes: `jobs_delete_own` is a hard `DELETE` policy while the schema uses `deleted_at` soft-delete — a buggy/malicious client could hard-delete instead of soft-delete, cascading `applications`/`conversations`. And `jobs_select_own` returns drafts/soft-deleted to the owner (intended).
- **Fix (concrete):** Consider revoking hard `DELETE` and forcing soft-delete via UPDATE only:
```sql
DROP POLICY IF EXISTS "jobs_delete_own" ON public.jobs;
-- No DELETE policy ⇒ deletes denied; soft-delete goes through jobs_update_own
-- (set deleted_at). Cascade-heavy hard deletes become impossible.
```
- **Effort:** XS
- **Phase:** 2
- **Layman's:** Job permissions are solid; just stop allowing permanent deletes so a glitch can't wipe a job and all its applicants.

---

### F-RLS-10 — Soft-delete is policy-filtered only on `jobs`; no `deleted_at` elsewhere
- **Severity:** P2
- **Status:** PASS-WITH-NOTE
- **Evidence:** `00_SCOPE.md:88-89` — only `jobs` has `deleted_at`. It *is* filtered in the policy (`jobs_select_open`, `:144`), not just in app queries — correct. `profiles`/`applications`/`messages`/`conversations` have no soft-delete, so there is no "deleted rows leak through policy" bug today.
- **Why it matters at 25k AU users:** When a delete-account / data-retention flow is built (currently MISSING per `00_SCOPE.md:83-84`), any future `deleted_at` must be enforced **in the RLS policy**, not just in the Dart query, or deleted users' PII becomes readable by forgetting one `.is('deleted_at', null)` client-side. Flagging now so the pattern is set before that work.
- **Fix (concrete):** When adding soft-delete to any table, always add `AND deleted_at IS NULL` to its public SELECT policy (mirror `jobs_select_open`). No migration needed today.
- **Effort:** XS
- **Phase:** 2
- **Layman's:** Deleted jobs are correctly hidden by the database itself; keep doing it that way for everything else later.

---

### F-RLS-11 — `profile_completeness` view: self-scoped but no admin path and relies on `security_invoker`
- **Severity:** P2
- **Status:** PASS-WITH-NOTE
- **Evidence:** `supabase/migrations/20260514000001_profile_completeness.sql:42-72` — `WITH (security_invoker = on)`, `WHERE p.id = auth.uid()`, `REVOKE ALL FROM PUBLIC`, `GRANT SELECT TO authenticated`. Correctly scoped: an authed user only sees their own completeness because both the `WHERE` and the invoker-RLS bind to `auth.uid()`.
- **Why it matters at 25k AU users:** This is the right pattern (contrast F-RLS-03). Two notes: (1) the comment claims BI/admin dashboards use it, but with `security_invoker = on` + `WHERE p.id = auth.uid()` an admin gets only *their own* row — the future admin dashboard cannot read it as designed; (2) it depends on the underlying-table RLS being correct, which F-RLS-03 currently breaks (the join over `builder_profiles`/`trade_profiles` is over-permissive). Fixing F-RLS-03 also tightens this view automatically.
- **Fix (concrete):** Leave as-is for the mobile app. For the admin dashboard, expose a separate admin-only function `SELECT ... WHERE is_admin()` rather than loosening this view. No Phase-0 change.
- **Effort:** XS
- **Phase:** 3
- **Layman's:** The "profile X% complete" calculation is correctly private; just note the admin dashboard will need its own version.

---

### F-RLS-12 — Service-role key: not present in `lib/` (PASS-WITH-NOTE) but admin web app risk
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `grep -rniE "service_role|SERVICE_ROLE|serviceRole" lib/` → **1 hit, comment only**: `lib/features/profile/data/datasources/profile_remote_datasource.dart:132` ("...an admin/edge-function with service_role can read..."). No key literal, no env read of a service key. `supabase_config.dart` uses `AppEnv.supabaseAnonKey` only. Confirms `00_SCOPE.md:102-104`.
- **Why it matters at 25k AU users:** The mobile app is clean — good. The latent risk is *where the admin operations will run* (F-RLS-04): if the separate admin web app embeds the service-role key in a browser bundle, every RLS policy in this audit is moot. Out of this repo's scope but must be flagged for Ken.
- **Fix (concrete):** Ensure the admin web app keeps the service-role key server-side only (never in client JS); route privileged ops through Edge Functions / a backend, never a browser. Add a CI grep in the admin repo equivalent to `scripts/validate.sh`.
- **Effort:** XS
- **Phase:** 3
- **Layman's:** The phone app handles keys correctly; just make sure the separate admin website never ships the master key to browsers.

---

### F-RLS-13 — `messages_insert` correct; `conversations_insert` allows orphan/duplicate-party conversations
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `supabase/migrations/20260511000006_rls.sql:230-238` — `conversations_insert WITH CHECK (auth.uid() = builder_id OR auth.uid() = trade_id)`. A user can insert a conversation where they are `builder_id` and set `trade_id` to any arbitrary user (or vice-versa), and `job_id` is nullable with no check the inserter is actually that job's builder. `messages_insert` (`:258-270`) is correctly tight (`sender_id = auth.uid()` + membership EXISTS).
- **Why it matters at 25k AU users:** Any user can open a conversation channel *to* any other user (cold-DM / spam vector) since only one side of the pair must be the caller. At 5k MAU this is an unsolicited-contact and harassment surface with no rate limit (rate-limit table MISSING per `00_SCOPE.md:81`) and no moderation (F-RLS-04). The counterparty's `messages_select`/`conversations_select` will surface the unwanted thread.
- **Fix (concrete):** Require a real relationship to start a conversation (an application exists between the pair, or the initiator is the job's builder):
```sql
DROP POLICY IF EXISTS "conversations_insert" ON public.conversations;
CREATE POLICY "conversations_insert"
  ON public.conversations FOR INSERT
  WITH CHECK (
    (auth.uid() = builder_id OR auth.uid() = trade_id)
    AND EXISTS (
      SELECT 1 FROM public.applications a
      WHERE a.builder_id = conversations.builder_id
        AND a.trade_id  = conversations.trade_id
        AND (conversations.job_id IS NULL OR a.job_id = conversations.job_id)
    )
  );
```
NEEDS HUMAN INPUT: confirm the product rule for who may *initiate* contact (builder-first only, or either side after an application).
- **Effort:** S
- **Phase:** 1
- **Layman's:** Right now anyone can start a private chat with any stranger on the platform.

---

## Cross-cutting recommendations

1. **Make `admin` impossible to self-assign before anything else (F-RLS-01).** Every other admin control (F-RLS-02, F-RLS-04) builds on the JWT `user_role` claim being trustworthy. This is the single highest-leverage fix and is Effort S.
2. **Always pair `USING` with `WITH CHECK` on every UPDATE policy, and column-immutability with a `BEFORE UPDATE` trigger.** The repo's recurring bug class is "USING-only" UPDATE policies (`applications`, `messages`, `verification_documents`, `trade_profiles`). `WITH CHECK` cannot see `OLD`, so column-level immutability (status, is_verified, body, builder_id) needs trigger guards — adopt this as the standard pattern.
3. **Adopt one `public.is_admin()` SQL function** (`SELECT (auth.jwt() ->> 'user_role') = 'admin'`) and reference it in all admin policies, so the authz definition lives in one place.
4. **Replace blanket `auth.role() = 'authenticated'` SELECT with relationship-scoped predicates** for any table holding PII (`builder_profiles`, `trade_profiles`). "Authenticated" ≠ "authorized" — it is the whole 25k userbase.
5. **Privileged, audited writes belong in Edge Functions, not RLS alone.** RLS fixes here are the Phase-0/1 stopgap; the durable design (admin approval, suspension, moderation) needs the Edge Functions the edge-functions-auditor will scope, each writing a `moderation_audit_log` row (table MISSING — coordinate with trust-safety-auditor).
6. **Lock down session lifetime in the Supabase dashboard and document it** (F-RLS-08) — refresh-token rotation + reuse interval + shorter JWT TTL — and build a server-side session-revocation path before any suspension feature ships.
7. **Prefer soft-delete-only (revoke hard `DELETE`)** on `jobs` and any future table with cascades, so a single bad client call can't wipe related applications/conversations.

---

## Open questions for Ken

1. **Admin provisioning:** How are admins meant to be created — manual SQL by you, or via the admin web app with the service role? (Drives whether F-RLS-01's `forbid_self_admin` trigger should also exempt a specific provisioning path.)
2. **Counterparty visibility:** Should a trade see a builder's `contact_phone` *before* applying to that builder's open job, or only after an application/conversation exists? (F-RLS-03 third `EXISTS`.)
3. **Application status matrix:** Exact allowed `application_status` transitions per role — confirm the trade/builder split in F-RLS-05.
4. **Review eligibility:** Which `job_status` means "work completed" for the review-after-completion guard (F-RLS-07) — `closed`? Is there a separate `completed` concept not in the enum?
5. **Conversation initiation:** Who may start a conversation — builder-only after an application, or either party? (F-RLS-13.)
6. **Session policy:** Confirm the Supabase dashboard Auth session settings (refresh rotation on? JWT TTL? inactivity timeout?) — not determinable from the repo. Desired admin idle-timeout value?
7. **Admin web app key handling:** Confirm the separate admin web app keeps the service-role key strictly server-side (F-RLS-12).
8. **Supabase Auth hook deployment:** `custom_access_token` must be selected in Dashboard → Authentication → Hooks for the `user_role` claim to exist at all — confirm it is actually wired in production (if not, *every* `auth.jwt() ->> 'user_role'` admin predicate silently fails closed, which is safe, but admin functionality won't work).
