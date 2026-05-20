-- ============================================================
-- Migration: user_role_events — append-only audit log
--
-- RBAC lockdown (docs/RBAC_SUPABASE_AUDIT.md §7 #1, audit-trail):
-- Captures the lifecycle of every user_roles row. Two event sources:
--   * INSERT  — initial role assignment (signup path)        reason='signup'
--   * UPDATE OF role — admin-driven role change (Edge Fn)    reason='admin_change'
--
-- Self-serve role changes are blocked by 20260520000001 — any UPDATE that
-- reaches this trigger is therefore service_role-signed by construction.
--
-- Read access: a user can see their own role history; admins (rows in
-- user_roles where role='admin') can see all events.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_role_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  old_role    text,
  new_role    text NOT NULL,
  changed_by  uuid REFERENCES auth.users(id),
  reason      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_role_events_user_id_idx
  ON public.user_role_events (user_id);

CREATE INDEX IF NOT EXISTS user_role_events_created_at_idx
  ON public.user_role_events (created_at DESC);

ALTER TABLE public.user_role_events ENABLE ROW LEVEL SECURITY;

-- Users can see their own role history.
DO $$ BEGIN
  CREATE POLICY "role_events_select_own"
    ON public.user_role_events
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admins (user_roles.role='admin') get full read/write across the log.
-- ALL covers SELECT/INSERT/UPDATE/DELETE — but in practice the audit log
-- is append-only via the trigger; no admin UI writes directly.
DO $$ BEGIN
  CREATE POLICY "role_events_admin_all"
    ON public.user_role_events
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger function: write one user_role_events row per user_roles INSERT
-- or UPDATE OF role. SECURITY DEFINER lets the trigger write rows the
-- end-user has no direct RLS grant to write — exactly what we want for
-- an append-only audit log.
CREATE OR REPLACE FUNCTION public.log_role_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reason text;
  v_old    text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_reason := 'signup';
    v_old    := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    -- 20260520000001's trigger ensures only service_role can land here
    -- with a changed role. Anything else got an exception before this
    -- AFTER trigger could fire.
    IF OLD.role IS NOT DISTINCT FROM NEW.role THEN
      RETURN NEW; -- no-op update; nothing to log
    END IF;
    v_reason := 'admin_change';
    v_old    := OLD.role;
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.user_role_events (
    user_id, old_role, new_role, changed_by, reason
  ) VALUES (
    NEW.user_id, v_old, NEW.role, auth.uid(), v_reason
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_role_event ON public.user_roles;
CREATE TRIGGER trg_log_role_event
  AFTER INSERT OR UPDATE OF role ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_role_event();

-- ============================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================
-- DROP TRIGGER IF EXISTS trg_log_role_event ON public.user_roles;
-- DROP FUNCTION IF EXISTS public.log_role_event();
-- DROP POLICY IF EXISTS "role_events_admin_all"  ON public.user_role_events;
-- DROP POLICY IF EXISTS "role_events_select_own" ON public.user_role_events;
-- DROP INDEX  IF EXISTS public.user_role_events_created_at_idx;
-- DROP INDEX  IF EXISTS public.user_role_events_user_id_idx;
-- DROP TABLE  IF EXISTS public.user_role_events;
-- ============================================================
