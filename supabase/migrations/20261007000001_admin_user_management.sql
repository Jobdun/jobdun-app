-- Admin directory invitations and role management. Apply before deploying
-- admin-users. No account creation, email, or existing role data changes here.
BEGIN;

-- This policy previously trusted a JWT role claim until the token expired.
-- Definer avoids recursive user_roles RLS while using the current actor row.
CREATE OR REPLACE FUNCTION public.admin_user_management_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
    WHERE r.user_id = auth.uid() AND r.role = 'admin' AND p.user_status = 'active'
  );
$$;
REVOKE ALL ON FUNCTION public.admin_user_management_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_user_management_is_admin() TO authenticated;
DROP POLICY IF EXISTS user_roles_admin_read ON public.user_roles;
CREATE POLICY user_roles_admin_read ON public.user_roles FOR SELECT TO authenticated
USING ((SELECT public.admin_user_management_is_admin()));

CREATE OR REPLACE FUNCTION public.admin_user_management_ready(p_actor_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' OR p_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
    WHERE r.user_id = p_actor_id AND r.role = 'admin' AND p.user_status = 'active'
  ) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  RETURN true;
END;
$$;

-- Public self-signup still cannot assign admin. The service role is trusted
-- only inside Edge; the role RPC below additionally verifies its real actor.
CREATE OR REPLACE FUNCTION public.forbid_self_admin()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.role = 'admin' AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.forbid_role_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'user_roles.role is immutable from client; role changes must go through an admin Edge Function (service_role)'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_role_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_reason text;
  v_old text;
  v_actor uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_reason := 'signup';
    v_old := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.role IS NOT DISTINCT FROM NEW.role THEN RETURN NEW; END IF;
    v_reason := 'admin_change';
    v_old := OLD.role;
  ELSE RETURN NEW;
  END IF;
  -- Never honor caller-supplied context on an authenticated signup request.
  IF auth.role() = 'service_role'
    AND nullif(current_setting('jobdun.admin_actor_id', true), '') IS NOT NULL THEN
    v_actor := current_setting('jobdun.admin_actor_id', true)::uuid;
    v_reason := nullif(current_setting('jobdun.admin_role_reason', true), '');
  END IF;
  INSERT INTO public.user_role_events(user_id, old_role, new_role, changed_by, reason)
  VALUES (NEW.user_id, v_old, NEW.role, v_actor, v_reason);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_actor_id uuid, p_user_id uuid, p_role text, p_expected_role text, p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_old_role text;
  v_name text;
  v_previous_actor text;
  v_previous_reason text;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_actor_id IS NULL OR p_user_id IS NULL OR p_role IS NULL
    OR p_role NOT IN ('builder','trade','admin')
    OR (p_expected_role IS NOT NULL AND p_expected_role NOT IN ('builder','trade','admin'))
    OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 500
    OR p_reason ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  -- Serialize promotions/demotions, including opposing concurrent requests.
  PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles', 0));
  -- Lock fresh actor rows so a concurrent suspension/demotion cannot slip
  -- between this verification and commit. Never trust JWT user_role.
  PERFORM 1 FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
    WHERE r.user_id = p_actor_id AND r.role = 'admin' AND p.user_status = 'active'
    FOR UPDATE OF r, p;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501'; END IF;
  IF p_actor_id = p_user_id THEN RAISE EXCEPTION 'self_role_change' USING ERRCODE = 'P0001'; END IF;
  PERFORM 1 FROM auth.users WHERE id = p_user_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001'; END IF;

  SELECT role INTO v_old_role FROM public.user_roles WHERE user_id = p_user_id FOR UPDATE;
  -- NULL means the UI observed no role, not permission to overwrite any role.
  IF v_old_role IS DISTINCT FROM p_expected_role THEN
    RAISE EXCEPTION 'role_conflict' USING ERRCODE = 'P0001';
  END IF;
  IF v_old_role = 'admin' AND p_role <> 'admin'
    AND (SELECT count(*) FROM public.user_roles WHERE role = 'admin') <= 1 THEN
    RAISE EXCEPTION 'last_admin' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.profiles(id, display_name)
    SELECT id, nullif(btrim(raw_user_meta_data->>'full_name'), '') FROM auth.users WHERE id = p_user_id
    ON CONFLICT (id) DO NOTHING;
  SELECT display_name INTO v_name FROM public.profiles WHERE id = p_user_id;
  IF p_role = 'builder' THEN
    INSERT INTO public.builder_profiles(id) VALUES(p_user_id) ON CONFLICT (id) DO NOTHING;
  ELSIF p_role = 'trade' THEN
    INSERT INTO public.trade_profiles(id, full_name) VALUES(p_user_id, v_name) ON CONFLICT (id) DO NOTHING;
  END IF;
  -- Preserve both historical role profiles; never clear apprentice, business,
  -- verification, job, quote or application data when changing the auth role.
  v_previous_actor := current_setting('jobdun.admin_actor_id', true);
  v_previous_reason := current_setting('jobdun.admin_role_reason', true);
  PERFORM set_config('jobdun.admin_actor_id', p_actor_id::text, true);
  PERFORM set_config('jobdun.admin_role_reason', btrim(p_reason), true);
  INSERT INTO public.user_roles(user_id, role) VALUES(p_user_id, p_role)
    ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;
  PERFORM set_config('jobdun.admin_actor_id', coalesce(v_previous_actor, ''), true);
  PERFORM set_config('jobdun.admin_role_reason', coalesce(v_previous_reason, ''), true);

  INSERT INTO public.admin_actions(actor_id, action, target_table, target_id, metadata)
    VALUES(p_actor_id, 'set_user_role', 'user_roles', p_user_id,
      jsonb_build_object('old_role', v_old_role, 'new_role', p_role, 'reason', btrim(p_reason)));
  RETURN jsonb_build_object('userId', p_user_id, 'role', p_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_user_invitation_preflight(p_actor_id uuid, p_email text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM public.admin_user_management_ready(p_actor_id);
  IF p_email IS NULL OR length(p_email) NOT BETWEEN 3 AND 254 THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(btrim(p_email))) THEN
    RAISE EXCEPTION 'user_exists' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

-- Reuse shared rate-limit storage; unlike the older verification helper this
-- path increments atomically and fails closed when the database is unavailable.
ALTER TABLE public.verification_rate_limits DROP CONSTRAINT verification_rate_limits_endpoint_check;
ALTER TABLE public.verification_rate_limits ADD CONSTRAINT verification_rate_limits_endpoint_check
  CHECK (endpoint IN ('verify-abn','verify-licence','admin-users-invite','admin-users-set-role'));

CREATE OR REPLACE FUNCTION public.admin_user_management_rate_limit(p_actor_id uuid, p_ip text, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_endpoint text;
  v_actor_limit integer;
  v_ip_limit integer;
  v_minute timestamptz := date_trunc('minute', clock_timestamp());
  v_actor_bucket text := 'user:' || p_actor_id::text;
  v_ip_bucket text := 'ip:' || coalesce(nullif(btrim(p_ip), ''), 'unknown');
BEGIN
  PERFORM public.admin_user_management_ready(p_actor_id);
  IF p_action IS NULL OR p_action NOT IN ('invite','set-role') OR length(p_ip) > 200 THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  v_endpoint := 'admin-users-' || p_action;
  v_actor_limit := CASE WHEN p_action = 'invite' THEN 5 ELSE 30 END;
  v_ip_limit := CASE WHEN p_action = 'invite' THEN 20 ELSE 90 END;
  PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:rate-limit', 0));
  IF (SELECT coalesce(sum(attempt_count),0) FROM public.verification_rate_limits
      WHERE endpoint = v_endpoint AND bucket_key = v_actor_bucket AND window_start >= v_minute - interval '1 hour') >= v_actor_limit
    OR (SELECT coalesce(sum(attempt_count),0) FROM public.verification_rate_limits
      WHERE endpoint = v_endpoint AND bucket_key = v_ip_bucket AND window_start >= v_minute - interval '1 hour') >= v_ip_limit THEN
    RETURN jsonb_build_object('allowed', false, 'retry_after', 3660);
  END IF;
  INSERT INTO public.verification_rate_limits(bucket_key, endpoint, window_start, attempt_count)
    VALUES(v_actor_bucket, v_endpoint, v_minute, 1), (v_ip_bucket, v_endpoint, v_minute, 1)
    ON CONFLICT (bucket_key, endpoint, window_start) DO UPDATE
    SET attempt_count = public.verification_rate_limits.attempt_count + 1;
  RETURN jsonb_build_object('allowed', true, 'retry_after', 3660);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_user_management_ready(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_user_invitation_preflight(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_user_management_rate_limit(uuid,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid,uuid,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_management_ready(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_user_invitation_preflight(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_user_management_rate_limit(uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid,uuid,text,text,text) TO service_role;

COMMIT;
