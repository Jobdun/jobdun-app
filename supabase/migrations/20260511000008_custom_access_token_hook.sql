-- ============================================================
-- Migration 8: custom_access_token hook
-- Injects user_role into the JWT so the Flutter app can read
-- session.user.userMetadata['user_role'] without an extra DB query.
--
-- After deploying:
--   Supabase Dashboard → Authentication → Hooks
--   → Custom Access Token Hook → select this function
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

  -- Look up the user's role; default to 'trade' if not found
  SELECT role INTO v_role
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

  v_role := COALESCE(v_role, 'trade');

  -- Inject into the claims object — Flutter reads session.user.userMetadata['user_role']
  v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role));

  RETURN jsonb_set(event, '{claims}', v_claims);
END;
$$;

-- Grant execute to the supabase_auth_admin role (required by Supabase hooks)
GRANT EXECUTE ON FUNCTION public.custom_access_token(jsonb)
  TO supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.custom_access_token(jsonb)
  FROM PUBLIC, anon, authenticated;
