-- ============================================================
-- Migration: lock user_role — role is immutable from clients
--
-- RBAC lockdown (docs/RBAC_SUPABASE_AUDIT.md §7 #1):
--   * Drop the user_roles_update_own RLS policy that let any authenticated
--     user PATCH their own user_roles.role. With the policy gone, PostgREST
--     UPDATE requests against /user_roles return 401/403.
--   * Defence in depth — add a BEFORE UPDATE trigger on user_roles that
--     blocks role mutation by any caller other than the service_role.
--     This blocks bugs that might re-add a permissive RLS policy in
--     future migrations, and also blocks direct database access from
--     anyone holding only the anon/authenticated grant.
--
-- Future role-change path: an admin Edge Function (NOT built in this PR)
-- runs with the service_role key and bypasses both layers. Document that
-- in the function's source comment when/if it ships.
-- ============================================================

-- Drop the self-serve update policy added in migrations 6 and 9.
DROP POLICY IF EXISTS "user_roles_update_own" ON public.user_roles;

-- Defence-in-depth trigger: even if a future migration re-adds an UPDATE
-- policy by mistake, the trigger still rejects role mutations from anyone
-- other than the service_role.
CREATE OR REPLACE FUNCTION public.forbid_role_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Allow non-role column updates (e.g. created_at backfill, never used today
  -- but future-proof). Only block when the role itself changed.
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    -- auth.role() returns 'service_role' when the request is signed with the
    -- service-role key, 'authenticated' for end-users, 'anon' for unauthed.
    IF auth.role() <> 'service_role' THEN
      RAISE EXCEPTION 'user_roles.role is immutable from client; role changes must go through an admin Edge Function (service_role)'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_forbid_role_mutation ON public.user_roles;
CREATE TRIGGER trg_forbid_role_mutation
  BEFORE UPDATE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.forbid_role_mutation();

-- ============================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================
-- DROP TRIGGER IF EXISTS trg_forbid_role_mutation ON public.user_roles;
-- DROP FUNCTION IF EXISTS public.forbid_role_mutation();
--
-- DO $$ BEGIN
--   CREATE POLICY "user_roles_update_own"
--     ON public.user_roles FOR UPDATE
--     USING (auth.uid() = user_id)
--     WITH CHECK (
--       auth.uid() = user_id
--       AND role IN ('builder', 'trade')
--     );
-- EXCEPTION WHEN duplicate_object THEN NULL;
-- END $$;
-- ============================================================
