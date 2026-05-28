-- ============================================================
-- Migration: admin read policies for profiles + jobs + role tables
-- Purpose : enable the admin web app to read the full dataset
--           it needs for dashboard counts, users list, jobs
--           list, and audit views. Mobile RLS is untouched —
--           all existing owner-scoped policies remain.
-- Pattern : mirrors verification_documents_admin_select / etc.
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
EXCEPTION WHEN duplicate_object THEN NULL;
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
EXCEPTION WHEN duplicate_object THEN NULL;
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
EXCEPTION WHEN duplicate_object THEN NULL;
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
EXCEPTION WHEN duplicate_object THEN NULL;
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
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- job_applications -------------------------------------------
DO $$ BEGIN
  CREATE POLICY "job_applications_admin_read"
    ON public.job_applications FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
