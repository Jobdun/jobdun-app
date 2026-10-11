-- Run only through run_admin_safety.sh (disposable network-disabled database).
BEGIN;
CREATE TEMP TABLE test_results (name text, passed boolean, detail text);
GRANT ALL ON test_results TO authenticated, anon, service_role;
CREATE FUNCTION pg_temp.check_true(p_name text, p_value boolean) RETURNS void LANGUAGE sql AS $$
  INSERT INTO test_results VALUES (p_name, p_value IS TRUE, NULL)
$$;
CREATE FUNCTION pg_temp.expect_error(p_name text, p_sql text, p_state text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'unexpected success' USING ERRCODE = 'T0001';
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_results VALUES(p_name, SQLSTATE = p_state, SQLSTATE || ': ' || SQLERRM);
    RETURN;
  END;
END;
$$;
CREATE FUNCTION pg_temp.expect_success(p_name text, p_sql text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_results VALUES(p_name, false, SQLSTATE || ': ' || SQLERRM);
    RETURN;
  END;
  INSERT INTO test_results VALUES(p_name, true, NULL);
END;
$$;
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000002', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.expect_error('owner cannot reactivate', $$UPDATE public.profiles SET user_status='active' WHERE id=auth.uid()$$, '42501');
SELECT pg_temp.expect_error('owner cannot set reason', $$UPDATE public.profiles SET status_reason='erased' WHERE id=auth.uid()$$, '42501');
SELECT pg_temp.expect_error('owner cannot upsert protected status', $$INSERT INTO public.profiles(id,user_status) VALUES(auth.uid(),'active') ON CONFLICT(id) DO UPDATE SET user_status=excluded.user_status$$, '42501');
SELECT pg_temp.expect_success('profile name and avatar edits remain allowed', $$UPDATE public.profiles SET display_name='Updated local name',avatar_url='https://example.invalid/avatar.png' WHERE id=auth.uid()$$);
SELECT pg_temp.expect_success('onboarding id upsert remains allowed', $$INSERT INTO public.profiles(id) VALUES(auth.uid()) ON CONFLICT(id) DO UPDATE SET id=excluded.id$$);
UPDATE public.verification_documents SET deleted_at=now() WHERE trade_id=auth.uid();
SELECT pg_temp.check_true('owner can soft-delete own document', EXISTS(SELECT 1 FROM public.verification_documents WHERE trade_id=auth.uid() AND deleted_at IS NOT NULL));
UPDATE public.verification_documents SET deleted_at=NULL WHERE trade_id=auth.uid();
SELECT pg_temp.check_true('owner can restore own document', EXISTS(SELECT 1 FROM public.verification_documents WHERE trade_id=auth.uid() AND deleted_at IS NULL));
SELECT pg_temp.expect_error('nonadmin moderation denied', $$SELECT public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','banned','Local reason')$$, '42501');
SELECT pg_temp.expect_success('nonadmin directory is empty', $$DO $body$ BEGIN IF EXISTS(SELECT 1 FROM public.admin_user_directory) THEN RAISE EXCEPTION 'leaked directory'; END IF; END $body$;$$);

-- Suspended and banned actors retain both a JWT claiming admin and their role.
DO $actors$ DECLARE actor text; BEGIN
  FOREACH actor IN ARRAY ARRAY['a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000004'] LOOP
    PERFORM set_config('request.jwt.claim.sub', actor, true);
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub',actor,'role','authenticated','user_role','admin')::text, true);
    PERFORM pg_temp.expect_error(actor || ' status RPC', $$SELECT public.admin_set_user_status(auth.uid(),'active','Local reason')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' job RPC', $$SELECT public.admin_set_job_status('c0000000-0000-0000-0000-000000000001','closed')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' review RPC', $$SELECT public.review_verification_document('d0000000-0000-0000-0000-000000000001','approved')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' revoke RPC', $$SELECT public.revoke_verification('b0000000-0000-0000-0000-000000000002','abn','Local reason')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' raw RPC', $$SELECT public.admin_view_verification_raw('e0000000-0000-0000-0000-000000000001')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' broadcast RPC', $$SELECT public.admin_broadcast('Local title','Local body','all')$$, '42501');
    PERFORM pg_temp.expect_error(actor || ' audit RPC', $$SELECT public.log_admin_action('fake_action')$$, '42501');
    PERFORM pg_temp.check_true(actor || ' private documents unreadable', (SELECT count(*)=0 FROM public.verification_documents));
    PERFORM pg_temp.check_true(actor || ' admin audit unreadable', (SELECT count(*)=0 FROM public.admin_actions));
    PERFORM pg_temp.check_true(actor || ' storage unreadable', (SELECT count(*)=0 FROM storage.objects));
    PERFORM pg_temp.check_true(actor || ' other profiles unreadable', (SELECT count(*)=0 FROM public.profiles WHERE id <> auth.uid()));
    PERFORM pg_temp.check_true(actor || ' other roles unreadable', (SELECT count(*)=0 FROM public.user_roles WHERE user_id <> auth.uid()));
    PERFORM pg_temp.expect_success(actor || ' directory is empty', $$DO $body$ BEGIN IF EXISTS(SELECT 1 FROM public.admin_user_directory) THEN RAISE EXCEPTION 'leaked directory'; END IF; END $body$;$$);
    PERFORM pg_temp.check_true(actor || ' verifications unreadable', (SELECT count(*)=0 FROM public.verifications));
    PERFORM pg_temp.check_true(actor || ' other role events unreadable', (SELECT count(*)=0 FROM public.user_role_events WHERE user_id <> auth.uid()));
  END LOOP;
END $actors$;

SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
SELECT pg_temp.check_true('active admin sees private documents', (SELECT count(*)=1 FROM public.verification_documents));
SELECT pg_temp.check_true('active admin storage restricted to private-docs', (SELECT count(*)=1 FROM storage.objects));
SELECT pg_temp.expect_error('active admin cannot fabricate an audit action', $$SELECT public.log_admin_action('set_user_status','profiles','b0000000-0000-0000-0000-000000000001','{"status":"banned"}')$$, '42501');
SELECT pg_temp.expect_error('active admin cannot forge role history', $$INSERT INTO public.user_role_events(user_id,new_role,reason) VALUES(auth.uid(),'trade','Forged history')$$, '42501');
SELECT pg_temp.expect_error('active admin cannot edit role history', $$UPDATE public.user_role_events SET reason='Rewritten history'$$, '42501');
SELECT pg_temp.expect_error('active admin cannot delete role history', $$DELETE FROM public.user_role_events$$, '42501');
SELECT pg_temp.expect_error('active admin cannot truncate role history', $$TRUNCATE public.user_role_events$$, '42501');
WITH changed AS (UPDATE public.verification_documents SET deleted_at=now()
  WHERE id='d0000000-0000-0000-0000-000000000001' RETURNING id)
SELECT pg_temp.check_true('active admin cannot soft-delete another users document', NOT EXISTS(SELECT 1 FROM changed));
WITH changed AS (UPDATE public.verification_documents SET deleted_at=NULL
  WHERE id='d0000000-0000-0000-0000-000000000001' RETURNING id)
SELECT pg_temp.check_true('active admin cannot restore another users document', NOT EXISTS(SELECT 1 FROM changed));
SELECT pg_temp.expect_error('admin cannot suspend self', $$SELECT public.admin_set_user_status(auth.uid(),'suspended','Local reason')$$, 'P0001');
SELECT pg_temp.expect_error('unknown user rejected', $$SELECT public.admin_set_user_status('ffffffff-ffff-ffff-ffff-ffffffffffff','banned','Local reason')$$, 'P0001');
SELECT pg_temp.expect_error('unknown job rejected', $$SELECT public.admin_set_job_status('ffffffff-ffff-ffff-ffff-ffffffffffff','closed')$$, 'P0001');
SELECT pg_temp.expect_error('unknown raw target rejected', $$SELECT public.admin_view_verification_raw('ffffffff-ffff-ffff-ffff-ffffffffffff')$$, 'P0001');
SELECT pg_temp.expect_success('directory role filtering happens in SQL', $$DO $body$ BEGIN IF (SELECT count(*) FROM public.admin_user_directory WHERE role='admin') <> 4 THEN RAISE EXCEPTION 'incomplete directory'; END IF; END $body$;$$);
SELECT pg_temp.expect_error('blank moderation reason rejected', $$SELECT public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','banned','   ')$$, '22023');
SELECT pg_temp.expect_error('invalid moderation status rejected', $$SELECT public.admin_set_user_status('b0000000-0000-0000-0000-000000000001',NULL,'Local reason')$$, '22023');
SELECT pg_temp.expect_error('blank broadcast title rejected', $$SELECT public.admin_broadcast('   ','Local body','all')$$, '22023');
SELECT pg_temp.expect_error('blank broadcast body rejected', $$SELECT public.admin_broadcast('Local title',E'\t\n','all')$$, '22023');
SELECT pg_temp.expect_error('oversize broadcast title rejected', $$SELECT public.admin_broadcast(repeat('x',81),'Local body','all')$$, '22023');
SELECT pg_temp.expect_error('oversize broadcast body rejected', $$SELECT public.admin_broadcast('Local title',repeat('x',241),'all')$$, '22023');
SELECT pg_temp.expect_error('missing broadcast audience rejected', $$SELECT public.admin_broadcast('Local title','Local body',NULL)$$, '22023');
SELECT pg_temp.expect_error('malformed broadcast audience rejected', $$SELECT public.admin_broadcast('Local title','Local body','nonsense')$$, '22023');
SELECT pg_temp.expect_error('nonexistent broadcast recipient rejected', $$SELECT public.admin_broadcast('Local title','Local body','ffffffff-ffff-ffff-ffff-ffffffffffff')$$, 'P0001');
SELECT pg_temp.expect_error('broadcast payload must be an object', $$SELECT public.admin_broadcast('Local title','Local body','all','[]')$$, '22023');
SELECT pg_temp.expect_error('single target cannot select group', $$SELECT public.admin_broadcast_to_user('Local title','Local body','all')$$, '22P02');
SELECT pg_temp.expect_error('single target must exist', $$SELECT public.admin_broadcast_to_user('Local title','Local body','ffffffff-ffff-ffff-ffff-ffffffffffff')$$, 'P0001');
SELECT pg_temp.expect_error('single target cannot be null', $$SELECT public.admin_broadcast_to_user('Local title','Local body',NULL)$$, '22023');
SELECT pg_temp.expect_error('new job overload requires reason', $$SELECT public.admin_set_job_status('c0000000-0000-0000-0000-000000000001','closed','   ')$$, '22023');
SELECT pg_temp.expect_success('new job overload accepts reason', $$SELECT public.admin_set_job_status('c0000000-0000-0000-0000-000000000001','closed','Synthetic test reason')$$);
SELECT pg_temp.expect_success('legacy job caller retained', $$SELECT public.admin_set_job_status('c0000000-0000-0000-0000-000000000001','cancelled')$$);
SELECT pg_temp.expect_success('legacy user caller retained', $$SELECT public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','suspended')$$);
SELECT pg_temp.expect_success('user moderation accepts reason', $$SELECT public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','active','Synthetic reactivation')$$);
SELECT pg_temp.expect_success('review still works', $$SELECT public.review_verification_document('d0000000-0000-0000-0000-000000000001','approved')$$);
SELECT pg_temp.expect_success('raw read still works', $$SELECT public.admin_view_verification_raw('e0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.expect_success('revoke still works', $$SELECT public.revoke_verification('b0000000-0000-0000-0000-000000000002','abn','Synthetic revocation')$$);
SELECT pg_temp.expect_success('single broadcast works', $$SELECT public.admin_broadcast_to_user('  Local title  ','  Local body  ','b0000000-0000-0000-0000-000000000002')$$);
SELECT pg_temp.expect_success('legacy group broadcast works', $$SELECT public.admin_broadcast('Local title','Local body','builders')$$);

-- Current membership must override even a JWT that still claims admin.
RESET ROLE;
SELECT set_config('request.jwt.claim.role', 'service_role', true);
UPDATE public.user_roles SET role='trade' WHERE user_id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000002', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.expect_error('demoted stale admin cannot broadcast', $$SELECT public.admin_broadcast('Local title','Local body','all')$$, '42501');
SELECT pg_temp.check_true('demoted stale admin loses storage access', (SELECT count(*)=0 FROM storage.objects));

SELECT set_config('request.jwt.claim.role', 'service_role', true);
SET LOCAL ROLE service_role;
SELECT pg_temp.expect_error('suspended Edge actor is rejected', $$SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000002','builder','trade','Synthetic reason')$$, '42501');
SELECT pg_temp.expect_error('last active admin cannot demote self', $$SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','builder','admin','Synthetic reason')$$, 'P0001');
SELECT pg_temp.expect_success('active Edge actor can promote', $$SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000002','builder','trade','Synthetic reason')$$);

RESET ROLE;
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.check_true('authenticated cannot call service-only role RPC', NOT has_function_privilege('authenticated','public.admin_set_user_role(uuid,uuid,text,text,text)','EXECUTE'));
SELECT pg_temp.expect_error('last active admin cannot ban self', $$SELECT public.admin_set_user_status(auth.uid(),'banned','Synthetic reason')$$, 'P0001');
SET LOCAL ROLE anon;
-- Actual ACL denials also run in fresh sessions in admin_safety_concurrency.sh.
SELECT pg_temp.check_true('anon cannot call broadcast', NOT has_function_privilege('anon','public.admin_broadcast(text,text,text,jsonb)','EXECUTE'));
SELECT pg_temp.check_true('anon cannot call review', NOT has_function_privilege('anon','public.review_verification_document(uuid,text,text,text,text)','EXECUTE'));
SELECT pg_temp.check_true('anon cannot inspect active-admin predicate', NOT has_function_privilege('anon','public.admin_user_management_is_admin()','EXECUTE'));

RESET ROLE;
SELECT pg_temp.check_true('single broadcast body is trimmed', EXISTS(SELECT 1 FROM public.notifications WHERE user_id='b0000000-0000-0000-0000-000000000002' AND title='Local title' AND body='Local body'));
SELECT pg_temp.check_true('job reason is audited', EXISTS(SELECT 1 FROM public.admin_actions WHERE action='set_job_status' AND metadata->>'reason'='Synthetic test reason'));
SELECT pg_temp.check_true(expected.action || ' writes an attributed audit event',
  EXISTS(SELECT 1 FROM public.admin_actions a WHERE a.action=expected.action
    AND a.actor_id='a0000000-0000-0000-0000-000000000001'))
FROM (VALUES ('set_user_status'),('review_verification_document'),
  ('view_verification_raw'),('revoke_verification'),('broadcast'),('set_user_role')) AS expected(action);
SELECT pg_temp.check_true('audited role RPC still appends role history', EXISTS(SELECT 1 FROM public.user_role_events WHERE user_id='b0000000-0000-0000-0000-000000000002' AND new_role='builder' AND reason='Synthetic reason'));
SELECT pg_temp.check_true('notification sink captured every delivery', (SELECT count(*) FROM public.admin_test_delivery_sink)=(SELECT count(*) FROM public.notifications));
SELECT * FROM test_results WHERE NOT passed;
DO $$ DECLARE failures text; BEGIN
  SELECT string_agg(name || ': ' || coalesce(detail,'assertion failed'), E'\n') INTO failures FROM test_results WHERE NOT passed;
  IF failures IS NOT NULL THEN RAISE EXCEPTION E'Admin safety regressions:\n%', failures; END IF;
  RAISE NOTICE 'Admin safety: % assertions passed', (SELECT count(*) FROM test_results);
END $$;
ROLLBACK;
