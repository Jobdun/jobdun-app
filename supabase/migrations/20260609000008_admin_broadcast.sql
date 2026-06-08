-- 20260609000008_admin_broadcast.sql
-- Push program — Stream A: admin broadcast. Gives admins a console action to
-- send a push + in-app update to a targeted audience.
--
-- This RPC ONLY inserts notification rows (type='announcement'). The central
-- fan-out trigger from 20260609000007 (notifications_push_fanout) turns each
-- inserted row into a push automatically — so we never call push-send here.
-- announcement → category 'announcements' (see notification_category in
-- 20260609000006); a user who opted out of that category still gets the in-app
-- row but no push, by the trigger's design.
--
-- Admin-gated EXACTLY like admin_set_user_status (20260609000003): a non-admin
-- raises 42501 before any row is touched. SECURITY DEFINER so it can insert
-- notifications for other users despite owner-only RLS, and audited via
-- log_admin_action (20260530000002).

-- admin_broadcast — resolve p_audience to a set of profile ids, insert one
-- announcement notification per id, audit, and return the recipient count.
--
-- p_audience:
--   'all'      → every public.profiles.id
--   'builders' → ids whose user_roles.role = 'builder'
--   'trades'   → ids whose user_roles.role = 'trade'
--   else       → a single profile id (p_audience::uuid)
CREATE OR REPLACE FUNCTION public.admin_broadcast(
  p_title    text,
  p_body     text,
  p_audience text,
  p_data     jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT t.id, 'announcement', p_title, p_body, COALESCE(p_data, '{}'::jsonb)
  FROM (
    SELECT p.id
    FROM public.profiles p
    WHERE p_audience = 'all'

    UNION

    SELECT ur.user_id AS id
    FROM public.user_roles ur
    WHERE (p_audience = 'builders' AND ur.role = 'builder')
       OR (p_audience = 'trades'   AND ur.role = 'trade')

    UNION

    SELECT p.id
    FROM public.profiles p
    WHERE p_audience NOT IN ('all', 'builders', 'trades')
      AND p.id = p_audience::uuid
  ) AS t;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM public.log_admin_action(
    'broadcast', 'notifications', NULL,
    jsonb_build_object('audience', p_audience, 'count', v_count)
  );

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_broadcast(text, text, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_broadcast(text, text, text, jsonb) TO authenticated;

COMMENT ON FUNCTION public.admin_broadcast(text, text, text, jsonb) IS
  'Push program (Stream A): admin sends an announcement to All / builders / '
  'trades / a single user. Admin-only; inserts type=announcement notification '
  'rows (auto-pushed by notifications_push_fanout); audited via '
  'log_admin_action. Returns the recipient count.';
