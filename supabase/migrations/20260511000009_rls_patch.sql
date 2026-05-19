-- ============================================================
-- Migration 9: RLS patch — add missing INSERT/UPDATE policies
-- Run this if you applied migration 6 without these policies.
-- Safe to run multiple times (IF NOT EXISTS guards each policy).
-- ============================================================

-- profiles: allow own insert (trigger handles new users, but app needs fallback)
DO $$ BEGIN
  CREATE POLICY "profiles_insert_own"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- user_roles: allow authenticated user to set their own role during onboarding.
-- Restricted to builder/trade — prevents self-escalation to admin.
DO $$ BEGIN
  CREATE POLICY "user_roles_insert_own"
    ON public.user_roles FOR INSERT
    WITH CHECK (
      auth.uid() = user_id
      AND role IN ('builder', 'trade')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "user_roles_update_own"
    ON public.user_roles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (
      auth.uid() = user_id
      AND role IN ('builder', 'trade')
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
