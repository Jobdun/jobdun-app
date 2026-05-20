-- ============================================================
-- Migration: profile_role_consistency — SELECT scoped by user_roles
--
-- RBAC lockdown (docs/RBAC_SUPABASE_AUDIT.md §6, §7 #1):
--
-- Today, builder_profiles_select_authenticated and trade_profiles_select_*
-- are `auth.role() = 'authenticated'` — wide-open to any signed-in user
-- and, more importantly, they ignore whether the row's owner is actually
-- *currently* a builder/trade. If an orphan stub exists (from a future
-- bug or from a legacy data import), it stays readable.
--
-- This migration narrows both SELECT policies with an EXISTS guard:
-- a builder_profiles row is only readable when its owner is currently
-- recorded as 'builder' in user_roles, mirror for trade. The insert/
-- update policies are unchanged — they already restrict writes to the
-- row owner (auth.uid() = id).
-- ============================================================

-- ---------- builder_profiles ----------
DROP POLICY IF EXISTS "builder_profiles_select_authenticated" ON public.builder_profiles;

DO $$ BEGIN
  CREATE POLICY "builder_profiles_select_authenticated"
    ON public.builder_profiles
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = public.builder_profiles.id
          AND ur.role    = 'builder'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------- trade_profiles ----------
DROP POLICY IF EXISTS "trade_profiles_select_authenticated" ON public.trade_profiles;

DO $$ BEGIN
  CREATE POLICY "trade_profiles_select_authenticated"
    ON public.trade_profiles
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = public.trade_profiles.id
          AND ur.role    = 'trade'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------- invariants the rest of this file relies on ----------
-- Per migration 20260511000006_rls.sql:90-102 and :117-129, the following
-- policies still exist and are intentionally unchanged by this migration:
--   * builder_profiles_insert_own  -- WITH CHECK (auth.uid() = id)
--   * builder_profiles_update_own  -- USING + WITH CHECK (auth.uid() = id)
--   * trade_profiles_insert_own    -- WITH CHECK (auth.uid() = id)
--   * trade_profiles_update_own    -- USING + WITH CHECK (auth.uid() = id)
-- If a future migration changes those, re-evaluate whether the EXISTS
-- guard above is still sufficient.

-- ============================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================
-- DROP POLICY IF EXISTS "builder_profiles_select_authenticated" ON public.builder_profiles;
-- DROP POLICY IF EXISTS "trade_profiles_select_authenticated"   ON public.trade_profiles;
--
-- DO $$ BEGIN
--   CREATE POLICY "builder_profiles_select_authenticated"
--     ON public.builder_profiles FOR SELECT
--     USING (auth.role() = 'authenticated');
-- EXCEPTION WHEN duplicate_object THEN NULL;
-- END $$;
--
-- DO $$ BEGIN
--   CREATE POLICY "trade_profiles_select_authenticated"
--     ON public.trade_profiles FOR SELECT
--     USING (auth.role() = 'authenticated');
-- EXCEPTION WHEN duplicate_object THEN NULL;
-- END $$;
-- ============================================================
