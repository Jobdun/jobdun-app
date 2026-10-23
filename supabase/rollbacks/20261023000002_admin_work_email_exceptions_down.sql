-- Revoke the web's exception-aware identity fallback before this rollback.
-- Audit records are retained; removing this gate denies personal-email chat.
BEGIN;
CREATE OR REPLACE FUNCTION public.admin_chat_eligible(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_company_actor_role(p_user) IS NOT NULL AND EXISTS (
 SELECT 1 FROM auth.users WHERE id=p_user AND email_confirmed_at IS NOT NULL
 AND lower(split_part(email,'@',2))='jobdun.com.au')
$$;
DROP FUNCTION public.admin_work_email_exception_set(uuid,integer,text),public.admin_work_email_exception_allowed();
DROP FUNCTION company_admin_private.work_email_exception_matches(uuid);
DROP TABLE public.admin_work_email_exceptions;
COMMIT;
