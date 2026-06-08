-- 20260609000003_admin_moderation.sql
-- #21a admin moderation: turn the read-only admin console's moderation
-- placeholder into real actions. Admins can suspend/ban a user and close a
-- listing, each gated to the admin role and recorded in the admin_actions
-- audit trail (via log_admin_action from 20260530000002). The admin web wires
-- these RPCs onto the existing moderation card + a job-actions menu.

-- 1. user_status on profiles. Default 'active'; non-self-assignable — there is
--    no user-facing UPDATE policy for it, only the SECURITY DEFINER RPC below
--    writes it (mirrors how admin role is locked down).
DO $$ BEGIN
  CREATE TYPE public.user_status AS ENUM ('active', 'suspended', 'banned');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS user_status   public.user_status NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS status_reason text;

-- 2. admin_set_user_status — suspend / ban / reactivate. Admin-gated before the
--    write (a non-admin raises 42501 and never touches the row), then audited.
--    SECURITY DEFINER so it can update another user's profile despite owner-only
--    RLS.
CREATE OR REPLACE FUNCTION public.admin_set_user_status(
  p_user_id uuid,
  p_status  text,
  p_reason  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  UPDATE public.profiles
     SET user_status   = p_status::public.user_status,
         status_reason = p_reason
   WHERE id = p_user_id;

  PERFORM public.log_admin_action(
    'set_user_status', 'profiles', p_user_id,
    jsonb_build_object('status', p_status, 'reason', p_reason)
  );
END;
$$;

-- 3. admin_set_job_status — moderate a listing (e.g. close a dodgy job). Same
--    gate + audit. p_status is cast to the existing public.job_status enum.
CREATE OR REPLACE FUNCTION public.admin_set_job_status(
  p_job_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  UPDATE public.jobs
     SET status = p_status::public.job_status
   WHERE id = p_job_id;

  PERFORM public.log_admin_action(
    'set_job_status', 'jobs', p_job_id,
    jsonb_build_object('status', p_status)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_status(uuid, text, text) FROM public;
REVOKE ALL ON FUNCTION public.admin_set_job_status(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_job_status(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.admin_set_user_status(uuid, text, text) IS
  '#21a admin moderation: set a user active/suspended/banned. Admin-only; '
  'audited via log_admin_action. Enforcement (blocking suspended users) is a '
  'follow-up RLS concern.';
COMMENT ON FUNCTION public.admin_set_job_status(uuid, text) IS
  '#21a admin moderation: set a job status (e.g. closed). Admin-only; audited.';
