-- ============================================================
-- Migration: admin read policies for profiles + jobs + role tables
-- Purpose : enable the admin web app to read the full dataset
--           it needs for dashboard counts, users list, jobs
--           list, and audit views. Mobile RLS is untouched —
--           all existing owner-scoped policies remain.
-- Pattern : mirrors verification_documents_admin_select / etc.
--
-- Idempotency
--   Each block is wrapped in DO $$ ... EXCEPTION so the migration is
--   safe to re-run on any database state:
--     - duplicate_object   → policy already exists, skip silently
--     - undefined_table    → table doesn't exist in this DB, log + skip
--   This lets the script complete on partially-bootstrapped databases
--   without leaving later policies un-applied.
-- ============================================================

-- profiles ---------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "profiles_admin_read"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip profiles_admin_read: table public.profiles does not exist';
END $$;

-- builder_profiles -------------------------------------------
DO $$ BEGIN
  CREATE POLICY "builder_profiles_admin_read"
    ON public.builder_profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip builder_profiles_admin_read: table public.builder_profiles does not exist';
END $$;

-- trade_profiles ---------------------------------------------
DO $$ BEGIN
  CREATE POLICY "trade_profiles_admin_read"
    ON public.trade_profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip trade_profiles_admin_read: table public.trade_profiles does not exist';
END $$;

-- user_roles -------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "user_roles_admin_read"
    ON public.user_roles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip user_roles_admin_read: table public.user_roles does not exist';
END $$;

-- jobs -------------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "jobs_admin_read"
    ON public.jobs FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip jobs_admin_read: table public.jobs does not exist';
END $$;

-- applications -----------------------------------------------
-- NB: the table is named `applications`, not `job_applications`.
-- The Flutter model is called JobApplication but the DB table is
-- public.applications (see 20260511000003_applications.sql).
DO $$ BEGIN
  CREATE POLICY "applications_admin_read"
    ON public.applications FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN
    RAISE NOTICE 'skip applications_admin_read: table public.applications does not exist';
END $$;
