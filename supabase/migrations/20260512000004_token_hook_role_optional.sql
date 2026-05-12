-- ============================================================
-- Migration: custom_access_token hook — role becomes optional
--
-- Why: 20260511000008 silently COALESCEd missing user_roles rows to 'trade'.
-- That defeats T1.2 — SSO users (no user_roles row by design) get a fake
-- 'trade' claim and RoleSelectionSheet never fires. This migration replaces
-- the function body so the user_role claim is omitted when no row exists.
-- Client (auth_provider._roleFromSession) returns null on missing claim,
-- which is what the sheet logic expects.
-- ============================================================

CREATE OR REPLACE FUNCTION public.custom_access_token(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  uuid;
  v_role     text;
  v_claims   jsonb;
BEGIN
  v_user_id := (event->>'user_id')::uuid;
  v_claims  := event->'claims';

  SELECT role INTO v_role
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

  -- Only inject the claim when a role row actually exists. If null, the
  -- Flutter client sees no user_role claim and prompts via RoleSelectionSheet.
  IF v_role IS NOT NULL THEN
    v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role));
  END IF;

  RETURN jsonb_set(event, '{claims}', v_claims);
END;
$$;

GRANT EXECUTE ON FUNCTION public.custom_access_token(jsonb)
  TO supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.custom_access_token(jsonb)
  FROM PUBLIC, anon, authenticated;
