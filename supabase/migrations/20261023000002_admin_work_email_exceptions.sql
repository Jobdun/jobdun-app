-- Temporary, account/email-bound exceptions. No accounts or emails are seeded.
-- This only relaxes the work-email identity gate; staff, status and MFA gates stay.
BEGIN;
CREATE TABLE public.admin_work_email_exceptions (
 user_id uuid PRIMARY KEY REFERENCES public.profiles(id),
 email text NOT NULL CHECK(length(email) BETWEEN 3 AND 320 AND email=lower(btrim(email))),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 approved_by uuid NOT NULL REFERENCES public.profiles(id),
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 500),
 CHECK(expires_at>created_at AND expires_at<=created_at+interval '7 days')
);
ALTER TABLE public.admin_work_email_exceptions ENABLE ROW LEVEL SECURITY;
-- No direct read/write policy or grants, including service clients. Approvals
-- must pass the owner-only RPC and its atomic audit. Migration operators retain
-- their normal trusted database administration access.
REVOKE ALL ON public.admin_work_email_exceptions FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION company_admin_private.work_email_exception_matches(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(
  SELECT 1 FROM public.admin_work_email_exceptions e JOIN auth.users u ON u.id=e.user_id
  WHERE e.user_id=p_user AND e.expires_at>statement_timestamp()
  AND u.email_confirmed_at IS NOT NULL AND lower(u.email)=e.email
  AND public.admin_company_actor_role(p_user) IS NOT NULL
 )
$$;
REVOKE ALL ON FUNCTION company_admin_private.work_email_exception_matches(uuid) FROM PUBLIC,anon,authenticated,service_role;

-- This endpoint exposes only the current account's boolean, never a roster,
-- exception details, email or an arbitrary UUID eligibility oracle. MFA remains
-- in downstream session/action gates so a pre-challenge identity check can run.
CREATE FUNCTION public.admin_work_email_exception_allowed() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT company_admin_private.work_email_exception_matches(auth.uid())
$$;

CREATE FUNCTION public.admin_work_email_exception_set(p_user uuid,p_days integer,p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_email text; v_now timestamptz; v_expires timestamptz; v_reason text:=btrim(p_reason);
BEGIN
 -- Existing permission guard serializes membership changes and enforces AAL2
 -- when the platform MFA policy is enabled. Exceptions never relax this guard.
 PERFORM public.admin_company_require('staff.manage');
 IF public.admin_company_actor_role(auth.uid()) IS DISTINCT FROM 'owner' THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
 -- Even an owner with an exception cannot grant, extend or revoke exceptions.
 -- Bind authority to the CURRENT confirmed work email, not JWT email/metadata.
 PERFORM 1 FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL
 AND lower(split_part(email,'@',2))='jobdun.com.au' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
 IF p_user IS NULL OR p_days IS NULL OR p_days NOT BETWEEN 0 AND 7 OR
 v_reason IS NULL OR length(v_reason) NOT BETWEEN 5 AND 500 THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 IF p_days=0 THEN
  DELETE FROM public.admin_work_email_exceptions WHERE user_id=p_user;
  INSERT INTO public.admin_actions(actor_id,action,target_table,target_id,metadata)
  VALUES(auth.uid(),'work_email_exception_revoke','admin_work_email_exceptions',p_user,'{}'::jsonb);
 ELSE
  IF public.admin_company_actor_role(p_user) IS NULL THEN
   RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
  SELECT lower(email) INTO v_email FROM auth.users WHERE id=p_user AND email_confirmed_at IS NOT NULL FOR SHARE;
  IF NOT FOUND OR v_email IS NULL THEN RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
  v_now:=clock_timestamp(); v_expires:=v_now+make_interval(days=>p_days);
  INSERT INTO public.admin_work_email_exceptions(user_id,email,created_at,expires_at,approved_by,reason)
  VALUES(p_user,v_email,v_now,v_expires,auth.uid(),v_reason)
  ON CONFLICT(user_id) DO UPDATE SET email=excluded.email,created_at=excluded.created_at,
  expires_at=excluded.expires_at,approved_by=excluded.approved_by,reason=excluded.reason;
  -- Free-form reason and email remain in the protected exception row. Audit
  -- receives fixed action, actor/target IDs and expiry only, avoiding PII copy.
  INSERT INTO public.admin_actions(actor_id,action,target_table,target_id,metadata)
  VALUES(auth.uid(),'work_email_exception_grant','admin_work_email_exceptions',p_user,jsonb_build_object('expires_at',v_expires));
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_chat_eligible(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_company_actor_role(p_user) IS NOT NULL AND EXISTS (
  SELECT 1 FROM auth.users WHERE id=p_user AND email_confirmed_at IS NOT NULL
  AND (lower(split_part(email,'@',2))='jobdun.com.au' OR company_admin_private.work_email_exception_matches(p_user))
 )
$$;
REVOKE ALL ON FUNCTION public.admin_work_email_exception_allowed(),public.admin_work_email_exception_set(uuid,integer,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.admin_work_email_exception_allowed(),public.admin_work_email_exception_set(uuid,integer,text) TO authenticated;
COMMIT;
