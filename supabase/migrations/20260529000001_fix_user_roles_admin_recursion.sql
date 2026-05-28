-- ============================================================
-- Migration: fix recursive `user_roles_admin_read` policy
--
-- Background
--   20260528000001_admin_read_policies.sql created an admin-read policy
--   on public.user_roles whose USING clause itself queries user_roles:
--
--     EXISTS (SELECT 1 FROM public.user_roles
--             WHERE user_id = auth.uid() AND role = 'admin')
--
--   The other admin policies (profiles_admin_read, jobs_admin_read,
--   verifications_admin_read, verification_documents_admin_select, etc.)
--   all do the same EXISTS check. When any of them runs the subquery
--   against user_roles, Postgres applies user_roles_admin_read to that
--   subquery, which subqueries user_roles again — infinite recursion.
--
--   Live symptom: every admin REST call returned 500 with
--     proxy-status: PostgREST; error=42P17
--   (PostgreSQL infinite_recursion).
--
-- Fix
--   The custom_access_token_hook (20260511000008) already injects
--   `user_role` into the JWT — the Flutter app reads it as
--   session.user.userMetadata['user_role']. We use that same claim from
--   inside the policy via `auth.jwt() ->> 'user_role'`. No table lookup,
--   no recursion, and it's faster (function call vs. row scan).
--
-- Idempotency
--   DROP POLICY IF EXISTS is no-op-safe. CREATE POLICY is wrapped in
--   DO $$ … EXCEPTION duplicate_object so re-running on a DB that
--   already has the fixed policy is safe.
-- ============================================================

DROP POLICY IF EXISTS "user_roles_admin_read" ON public.user_roles;

DO $$ BEGIN
  CREATE POLICY "user_roles_admin_read"
    ON public.user_roles FOR SELECT
    TO authenticated
    USING (
      coalesce(auth.jwt() ->> 'user_role', '') = 'admin'
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip user_roles_admin_read: table public.user_roles does not exist';
END $$;
