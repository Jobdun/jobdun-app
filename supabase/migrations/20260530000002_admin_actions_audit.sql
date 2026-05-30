-- supabase/migrations/20260530000002_admin_actions_audit.sql
--
-- STEP 6 — generic admin audit log + log_admin_action() RPC.
--
-- Mirrors the user_role_events / log_role_event() pattern (20260520000002) but
-- as an explicitly-CALLED audit seam rather than a table trigger: privileged
-- admin actions that aren't a plain row write (e.g. "view raw regulator
-- payload") have nothing to hang a trigger on, so the admin app calls
-- log_admin_action(...) to leave a tamper-evident trail.
--
-- The verification "view raw" action (admin_verification_review_sheet) is the
-- first caller — viewing verification_events.raw_response is logged here first.
--
-- Write path: ONLY via the SECURITY DEFINER RPC (no client INSERT policy), so
-- the actor is always auth.uid() and can't be spoofed. Read: admins only.
-- Reversibility: SAFE — see DOWN block.

CREATE TABLE IF NOT EXISTS public.admin_actions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  action       text NOT NULL CHECK (action <> ''),
  target_table text,
  target_id    uuid,
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_actions_actor_id_idx
  ON public.admin_actions (actor_id);
CREATE INDEX IF NOT EXISTS admin_actions_created_at_idx
  ON public.admin_actions (created_at DESC);
CREATE INDEX IF NOT EXISTS admin_actions_target_idx
  ON public.admin_actions (target_table, target_id);

ALTER TABLE public.admin_actions ENABLE ROW LEVEL SECURITY;

-- Admins (user_roles.role='admin') can read the whole log. No INSERT/UPDATE/
-- DELETE policy exists on purpose — writes go exclusively through the RPC
-- below, which is SECURITY DEFINER and therefore bypasses RLS for the insert.
DO $$ BEGIN
  CREATE POLICY "admin_actions_admin_read"
    ON public.admin_actions
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- log_admin_action: append one audited row, attributed to the calling admin.
-- Rejects non-admins. Returns the new row id so the caller can correlate.
CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action       text,
  p_target_table text DEFAULT NULL,
  p_target_id    uuid DEFAULT NULL,
  p_metadata     jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  INSERT INTO public.admin_actions (actor_id, action, target_table, target_id, metadata)
  VALUES (auth.uid(), p_action, p_target_table, p_target_id, COALESCE(p_metadata, '{}'::jsonb))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.log_admin_action(text, text, uuid, jsonb) IS
  'Append-only admin audit seam. Admin-only; attributes the row to auth.uid(). '
  'First caller: verification "view raw" action.';

GRANT EXECUTE ON FUNCTION public.log_admin_action(text, text, uuid, jsonb) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.log_admin_action(text, text, uuid, jsonb) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.log_admin_action(text, text, uuid, jsonb);
-- DROP POLICY IF EXISTS "admin_actions_admin_read" ON public.admin_actions;
-- DROP INDEX IF EXISTS public.admin_actions_target_idx;
-- DROP INDEX IF EXISTS public.admin_actions_created_at_idx;
-- DROP INDEX IF EXISTS public.admin_actions_actor_id_idx;
-- DROP TABLE IF EXISTS public.admin_actions;
-- ============================================================================
