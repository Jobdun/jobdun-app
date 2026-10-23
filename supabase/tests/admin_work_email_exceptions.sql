-- Synthetic account IDs/emails only; every fixture change rolls back.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.admin_work_email_exception_allowed()') IS NULL THEN RAISE EXCEPTION 'self-only work exception RPC missing'; END IF;
END $$;
UPDATE auth.users SET email_confirmed_at=now();
UPDATE auth.users SET email='owner@jobdun.com.au' WHERE id='a0000000-0000-0000-0000-000000000001';
UPDATE auth.users SET email='personal@example.invalid' WHERE id='a0000000-0000-0000-0000-000000000002';
UPDATE public.profiles SET user_status='active',display_name='Identical synthetic staff name' WHERE id::text LIKE 'a%';
INSERT INTO public.admin_staff(user_id,staff_role) SELECT id,'owner' FROM public.profiles WHERE id::text LIKE 'a%' ON CONFLICT(user_id) DO UPDATE SET active=true,staff_role='owner';
UPDATE public.admin_platform_settings SET value='true' WHERE key='admin_mfa_required';
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'work owner received someone else exception'; END IF;
 IF has_table_privilege('authenticated','public.admin_work_email_exceptions','SELECT') OR has_table_privilege('authenticated','public.admin_work_email_exceptions','INSERT') OR has_table_privilege('authenticated','public.admin_work_email_exceptions','UPDATE') THEN RAISE EXCEPTION 'direct exception grants'; END IF;
 BEGIN PERFORM 1 FROM public.admin_work_email_exceptions; RAISE EXCEPTION 'direct exception read'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF has_function_privilege('anon','public.admin_work_email_exception_allowed()','EXECUTE') THEN RAISE EXCEPTION 'anonymous exception oracle'; END IF;
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',8,'Synthetic temporary access'); RAISE EXCEPTION 'eight day exception allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',-1,'Synthetic temporary access'); RAISE EXCEPTION 'negative days allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',7,'Synthetic temporary access');
 IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'RPC not self-only'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE t uuid; BEGIN
 IF NOT public.admin_work_email_exception_allowed() OR NOT public.admin_chat_allowed() THEN RAISE EXCEPTION 'approved personal staff denied'; END IF;
 t:=public.admin_chat_open('a0000000-0000-0000-0000-000000000001');
 PERFORM public.admin_chat_send(t,'Exception chat regression',gen_random_uuid());
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',7,'Attempt self extension'); RAISE EXCEPTION 'personal owner self extension'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',0,'Attempt personal revoke'); RAISE EXCEPTION 'personal owner revoke'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000003',1,'Attempt other grant'); RAISE EXCEPTION 'personal owner granted other'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 IF public.admin_work_email_exception_allowed() OR public.admin_chat_allowed() THEN RAISE EXCEPTION 'same-name unrelated personal owner allowed'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',true);
DO $$ BEGIN
 IF NOT public.admin_work_email_exception_allowed() OR public.admin_chat_allowed() THEN RAISE EXCEPTION 'MFA exception bypass'; END IF;
END $$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',true);
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM public.admin_actions WHERE action='work_email_exception_grant')<>1 THEN RAISE EXCEPTION 'grant audit missing or denied attempts audited'; END IF;
 IF EXISTS(SELECT 1 FROM public.admin_actions WHERE action LIKE 'work_email_exception_%' AND metadata::text LIKE '%@%') THEN RAISE EXCEPTION 'email in audit'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.admin_work_email_exceptions WHERE approved_by='a0000000-0000-0000-0000-000000000001' AND expires_at<=created_at+interval '7 days') THEN RAISE EXCEPTION 'approval/expiry bound missing'; END IF;
END $$;
-- Current email and current confirmation are binding, not display name/JWT claims.
UPDATE auth.users SET email='changed@example.invalid' WHERE id='a0000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() OR public.admin_chat_allowed() THEN RAISE EXCEPTION 'email change accepted'; END IF; END $$;
RESET ROLE;
UPDATE auth.users SET email='personal@example.invalid',email_confirmed_at=NULL WHERE id='a0000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'unconfirmed exception allowed'; END IF; END $$;
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=now() WHERE id='a0000000-0000-0000-0000-000000000002';
UPDATE public.admin_work_email_exceptions SET expires_at=now()-interval '1 second',created_at=now()-interval '1 day';
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() OR public.admin_chat_allowed() THEN RAISE EXCEPTION 'expired exception allowed'; END IF; END $$;
RESET ROLE;
-- Regrant for current membership/status/role revocation cases.
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'Regrant synthetic access');
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',true);
DO $$ BEGIN
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'MFA bypass attempt'); RAISE EXCEPTION 'owner MFA bypass'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',true);
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=NULL WHERE id='a0000000-0000-0000-0000-000000000001';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'Unconfirmed owner attempt'); RAISE EXCEPTION 'unconfirmed owner allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE auth.users SET email_confirmed_at=now() WHERE id='a0000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','',true);
UPDATE public.admin_staff SET staff_role='operations' WHERE user_id='a0000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'Non-owner grant attempt'); RAISE EXCEPTION 'non-owner allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true);
UPDATE public.admin_staff SET staff_role='owner' WHERE user_id='a0000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
SELECT set_config('request.jwt.claim.sub','',true);
UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'inactive membership accepted'; END IF; END $$;
RESET ROLE;
UPDATE public.admin_staff SET active=true WHERE user_id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.sub','',true);
UPDATE public.profiles SET user_status='suspended' WHERE id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'suspended staff accepted'; END IF; END $$;
RESET ROLE;
UPDATE public.profiles SET user_status='active' WHERE id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.sub','',true);
DELETE FROM public.user_roles WHERE user_id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF public.admin_work_email_exception_allowed() THEN RAISE EXCEPTION 'removed admin accepted'; END IF; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
INSERT INTO public.user_roles(user_id,role) VALUES('a0000000-0000-0000-0000-000000000002','admin');
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',0,'Revoke synthetic access');
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN IF public.admin_work_email_exception_allowed() OR public.admin_chat_allowed() THEN RAISE EXCEPTION 'revoked exception accepted'; END IF; END $$;
RESET ROLE;
DO $$ BEGIN IF (SELECT count(*) FROM public.admin_actions WHERE action='work_email_exception_revoke')<>1 THEN RAISE EXCEPTION 'revoke audit missing'; END IF; END $$;
-- Approval and audit are atomic: a failing audit cannot leave a usable grant.
CREATE FUNCTION public.test_work_exception_audit_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='work_email_exception_grant' THEN RAISE EXCEPTION 'synthetic audit failure' USING ERRCODE='23514'; END IF; RETURN NEW; END $$;
CREATE TRIGGER test_work_exception_audit_failure BEFORE INSERT ON public.admin_actions FOR EACH ROW EXECUTE FUNCTION public.test_work_exception_audit_failure();
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'Atomic audit regression'); RAISE EXCEPTION 'audit failure not propagated'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.admin_work_email_exceptions) THEN RAISE EXCEPTION 'grant survived failed audit'; END IF; END $$;
DROP TRIGGER test_work_exception_audit_failure ON public.admin_actions;
DROP FUNCTION public.test_work_exception_audit_failure();
-- The existing policy remains authoritative when MFA enforcement is disabled.
UPDATE public.admin_platform_settings SET value='false' WHERE key='admin_mfa_required';
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',true);
SET LOCAL ROLE authenticated;
SELECT public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',1,'Policy off regression');
SELECT public.admin_work_email_exception_set('a0000000-0000-0000-0000-000000000002',0,'Policy off cleanup');
RESET ROLE;
ROLLBACK;
\echo 'Work email exception identity, expiry, owner/MFA, audit, RLS and chat regressions passed.'
