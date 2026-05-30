-- supabase/migrations/20260530000004_admin_view_verification_raw.sql
--
-- STEP 6 — audited admin access to the raw regulator payload.
--
-- The raw ABR/regulator response lives in verification_events.raw_response (the
-- legal receipt). It is never shown to the builder/trade. An admin may inspect
-- it during a review, but that inspection must be LOGGED (it's PII access).
--
-- This SECURITY DEFINER RPC bundles both: it writes an admin_actions audit row
-- via log_admin_action, then returns the latest api_call raw_response for the
-- verification. SECURITY DEFINER because verification_events has no admin client
-- read grant — the RPC is the only (audited) door.
-- Reversibility: SAFE — see DOWN block.

CREATE OR REPLACE FUNCTION public.admin_view_verification_raw(p_verification_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_raw jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  PERFORM public.log_admin_action(
    'view_verification_raw',
    'verification_events',
    p_verification_id,
    '{}'::jsonb
  );

  SELECT raw_response INTO v_raw
    FROM public.verification_events
   WHERE verification_id = p_verification_id
     AND event_type = 'api_call'
   ORDER BY created_at DESC
   LIMIT 1;

  RETURN v_raw;
END;
$$;

COMMENT ON FUNCTION public.admin_view_verification_raw(uuid) IS
  'Audited admin read of verification_events.raw_response. Admin-only; writes an '
  'admin_actions row before returning the latest api_call payload.';

GRANT EXECUTE ON FUNCTION public.admin_view_verification_raw(uuid) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.admin_view_verification_raw(uuid) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.admin_view_verification_raw(uuid);
-- ============================================================================
