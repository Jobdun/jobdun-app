-- Assertions run twice: after first apply, then after rollback and reapply.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.admin_company_mutate(text,uuid,jsonb,integer)') IS NULL THEN RAISE EXCEPTION 'mutation RPC missing'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.routine_privileges WHERE routine_name='admin_company_actor_role' AND grantee='authenticated') THEN RAISE EXCEPTION 'actor helper exposed'; END IF;
END $$;
UPDATE public.admin_staff SET staff_role='support' WHERE user_id='a0000000-0000-0000-0000-000000000002';
UPDATE public.profiles SET phone='+61 412 345 678' WHERE id='b0000000-0000-0000-0000-000000000001';
INSERT INTO public.trade_categories(slug,display_name,category,sort_order) VALUES('electrician','Electrician','electrical',10) ON CONFLICT DO NOTHING;
SELECT set_config('request.jwt.claim.role','service_role',true);
INSERT INTO public.conversations(id,job_id,builder_id,trade_id)
VALUES('f0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001',
 'b0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000002');
INSERT INTO public.reports(id,reporter_id,reported_id,conversation_id,reason,details)
VALUES('f0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001',
 'b0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000001','other','Synthetic local report');
SELECT set_config('request.jwt.claim.role','authenticated',true);
DO $$ DECLARE v_role text; v_permission text; v_expected text[];
 v_all text[]:=ARRAY['users.read','users.manage','marketplace.read','marketplace.manage','verification.read','verification.manage',
  'support.read','support.manage','staff.read','staff.manage','platform.read','platform.manage','analytics.read',
  'communications.read','communications.send','audit.read'];
BEGIN
 FOR v_role IN SELECT unnest(ARRAY['owner','operations','verification','support','read_only']) LOOP
  UPDATE public.admin_staff SET staff_role=v_role WHERE user_id='a0000000-0000-0000-0000-000000000002';
  PERFORM set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
  v_expected:=CASE v_role
   WHEN 'owner' THEN v_all
   WHEN 'operations' THEN ARRAY['users.read','users.manage','marketplace.read','marketplace.manage','support.read','support.manage','analytics.read','communications.read','communications.send','audit.read']
   WHEN 'verification' THEN ARRAY['users.read','verification.read','verification.manage','audit.read']
   WHEN 'support' THEN ARRAY['users.read','marketplace.read','support.read','support.manage','audit.read']
   WHEN 'read_only' THEN ARRAY['users.read','marketplace.read','support.read','analytics.read','communications.read','audit.read'] END;
  FOREACH v_permission IN ARRAY v_all LOOP
   IF public.admin_company_has_permission(v_permission) IS DISTINCT FROM (v_permission=ANY(v_expected)) THEN
    RAISE EXCEPTION 'permission matrix mismatch: % %',v_role,v_permission;
   END IF;
  END LOOP;
  IF NOT public.admin_company_has_permission('session') THEN RAISE EXCEPTION 'session denied: %',v_role; END IF;
  IF v_role='verification' AND (public.admin_company_overview()->'counts'->>'pendingVerifications')::int<>1 THEN RAISE EXCEPTION 'verification queue count'; END IF;
  PERFORM set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
 END LOOP;
 UPDATE public.admin_staff SET staff_role='support' WHERE user_id='a0000000-0000-0000-0000-000000000002';
END $$;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v jsonb; v_id uuid; v_audit bigint; v_resource text; BEGIN
 IF public.admin_company_session()->>'staffRole'<>'owner' THEN RAISE EXCEPTION 'owner bootstrap'; END IF;
 IF (public.admin_company_overview()->'counts'->>'profiles')::int<1 THEN RAISE EXCEPTION 'owner overview'; END IF;
 IF public.admin_company_public_config() ? 'admin_mfa_required' THEN RAISE EXCEPTION 'MFA leaked into public config'; END IF;
 IF (public.admin_company_list('settings',1,NULL,NULL)->'rows') IS NULL THEN RAISE EXCEPTION 'settings list'; END IF;
 IF (public.admin_company_list('reference',1,NULL,NULL)->>'pageSize')::int<>50 THEN RAISE EXCEPTION 'reference list'; END IF;
 FOREACH v_resource IN ARRAY ARRAY['applications','quotes','timesheets','reports','reviews','enquiries','support','staff','settings',
  'communications','health','reference','verifications'] LOOP
  v:=public.admin_company_list(v_resource,1,NULL,NULL);
  IF (v->>'pageSize')::int<>50 OR jsonb_typeof(v->'rows')<>'array' THEN RAISE EXCEPTION 'list failed: %',v_resource; END IF;
 END LOOP;
 IF public.admin_company_list('reports',2,NULL,NULL)->'rows'<>'[]'::jsonb THEN RAISE EXCEPTION 'out-of-range page'; END IF;
 IF (public.admin_company_search_users('builder@example.invalid','email','all','all',1)->>'total')::int<>1 THEN RAISE EXCEPTION 'email search'; END IF;
 IF (public.admin_company_search_users('Synthetic','name','all','all',1)->>'total')::int<1 THEN RAISE EXCEPTION 'name search'; END IF;
 IF (public.admin_company_search_users('0412345678','phone','all','all',1)->>'total')::int<>1 THEN RAISE EXCEPTION 'AU phone normalization'; END IF;
 IF (public.admin_company_search_users('%','email','all','all',1)->>'total')::int<>0 THEN RAISE EXCEPTION 'email wildcard escaped'; END IF;
 v:=public.admin_company_mutate('support',NULL,'{"subject":"Synthetic help","user_id":null,"priority":"normal","assignee_id":null,"status":"open","reason":"Local test case"}',NULL);
 v_id:=(v->>'id')::uuid;
 IF v_id IS NULL OR (v->>'version')::int<>1 THEN RAISE EXCEPTION 'support creation'; END IF;
 v:=public.admin_company_mutate('setting',(SELECT id FROM public.admin_platform_settings WHERE key='marketplace_enabled'),'{"value":false,"reason":"Local marketplace pause"}',1);
 IF (v->>'version')::int<>2 OR NOT EXISTS(SELECT 1 FROM public.admin_actions WHERE action='company_setting' AND metadata->'old_value'='true'::jsonb AND metadata->'new_value'='false'::jsonb) THEN RAISE EXCEPTION 'setting audit before after'; END IF;
 v:=public.admin_company_mutate('report','f0000000-0000-0000-0000-000000000002','{"status":"actioned","reason":"Reviewed synthetic evidence"}',1);
 IF (v->>'version')::int<>2 THEN RAISE EXCEPTION 'report decision'; END IF;
 v:=public.admin_company_mutate('support',v_id,'{"subject":"Synthetic help revised","user_id":null,"priority":"high","assignee_id":null,"status":"in_progress","reason":"Local test update"}',1);
 IF (v->>'version')::int<>2 THEN RAISE EXCEPTION 'support update'; END IF;
 SELECT count(*) INTO v_audit FROM public.admin_actions WHERE target_id=v_id;
 BEGIN
  PERFORM public.admin_company_mutate('support',v_id,'{"subject":"Stale synthetic","user_id":null,"priority":"high","assignee_id":null,"status":"open","reason":"Stale update test"}',1);
  RAISE EXCEPTION 'stale mutation accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 IF (SELECT count(*) FROM public.admin_actions WHERE target_id=v_id)<>v_audit THEN RAISE EXCEPTION 'stale audit committed'; END IF;
 BEGIN
  PERFORM public.admin_company_mutate('support',v_id,'{"subject":"Missing reason","user_id":null,"priority":"high","assignee_id":null,"status":"open"}',2);
  RAISE EXCEPTION 'missing reason accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.admin_company_mutate('support',v_id,'{"subject":"Extra key","user_id":null,"priority":"high","assignee_id":null,"status":"open","reason":"Extra key test","secret":"bad"}',2);
  RAISE EXCEPTION 'extra key accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE v jsonb; BEGIN
 IF public.admin_company_session()->>'staffRole'<>'support' THEN RAISE EXCEPTION 'support session'; END IF;
 IF public.admin_company_has_permission('platform.read') THEN RAISE EXCEPTION 'support platform grant'; END IF;
 IF (public.admin_company_overview()->'counts'->>'jobs')::int<>1 OR (public.admin_company_overview()->'counts'->>'openSupport')::int<>1
 OR (public.admin_company_overview()->'counts'->'pendingVerifications') IS DISTINCT FROM 'null'::jsonb
 OR public.admin_company_overview()->'trends'<>'[]'::jsonb THEN RAISE EXCEPTION 'support overview scope'; END IF;
 IF (public.admin_company_list('support',1,NULL,'active')->>'total')::int<0 THEN RAISE EXCEPTION 'active support filter'; END IF;
 BEGIN PERFORM public.admin_company_list('settings',1,NULL,NULL); RAISE EXCEPTION 'support settings accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_company_mutate('staff',NULL,'{"user_id":"b0000000-0000-0000-0000-000000000001","staff_role":"owner","active":true,"reason":"Unauthorized owner"}',NULL); RAISE EXCEPTION 'support staff accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','suspended','Test reason'); RAISE EXCEPTION 'support user status accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.log_admin_action('forged','profiles',NULL,'{}'::jsonb); RAISE EXCEPTION 'direct audit forgery accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF (SELECT count(*) FROM storage.objects WHERE bucket_id='private-docs')<>0 THEN RAISE EXCEPTION 'support storage scope'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
RESET ROLE;
UPDATE public.admin_staff SET staff_role='operations' WHERE user_id='a0000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE v_audit bigint; BEGIN
 PERFORM public.admin_set_job_status('c0000000-0000-0000-0000-000000000001','open','Operations status test');
 PERFORM public.admin_broadcast('Test notice','Synthetic local broadcast','all','{}'::jsonb);
 PERFORM public.admin_set_user_status('b0000000-0000-0000-0000-000000000001','suspended','Operations moderation test');
 SELECT count(*) INTO v_audit FROM public.admin_actions WHERE action='set_user_status';
 BEGIN PERFORM public.admin_set_user_status('b0000000-0000-0000-0000-000000000002','suspended',NULL);
  RAISE EXCEPTION 'reasonless moderation accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF (SELECT count(*) FROM public.admin_actions WHERE action='set_user_status')<>v_audit THEN RAISE EXCEPTION 'reasonless moderation audited'; END IF;
 BEGIN PERFORM public.admin_set_user_status('a0000000-0000-0000-0000-000000000001','suspended','Staff moderation test');
  RAISE EXCEPTION 'operations changed staff account';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE v jsonb; v_staff uuid; v_case uuid; BEGIN
 SELECT id INTO v_staff FROM public.admin_staff WHERE user_id='a0000000-0000-0000-0000-000000000002';
 v:=public.admin_company_mutate('staff',v_staff,
  '{"user_id":"a0000000-0000-0000-0000-000000000002","staff_role":"verification","active":true,"reason":"Assign verification staff"}',1);
 IF (v->>'version')::int<>2 THEN RAISE EXCEPTION 'staff version'; END IF;
 v:=public.admin_company_mutate('verification-assignment','d0000000-0000-0000-0000-000000000001',
  '{"assignee_id":"a0000000-0000-0000-0000-000000000002","reason":"Balance local review queue"}',1);
 IF (v->>'version')::int<>2 THEN RAISE EXCEPTION 'assignment version'; END IF;
 v:=public.admin_company_mutate('reference',NULL,
  '{"source":"trade_categories","slug":"electrician","display_name":"Electrician (test)","sort_order":10,"reason":"Test reference update"}',1);
 IF (v->>'version')::int<>2 OR v->'id'<>'null'::jsonb THEN RAISE EXCEPTION 'reference version or id'; END IF;
 SELECT id INTO v_case FROM public.admin_support_cases WHERE subject='Synthetic help revised';
 v:=public.admin_company_mutate('note',NULL,jsonb_build_object('case_id',v_case,'body','Synthetic local note','reason','Record context for review'),NULL);
 IF (v->>'version')::int<>1 THEN RAISE EXCEPTION 'note creation'; END IF;
END $$;
DO $$ BEGIN
 BEGIN PERFORM public.admin_company_mutate('setting',(SELECT id FROM public.admin_platform_settings WHERE key='admin_mfa_required'),'{"value":true,"reason":"Enforce owner MFA"}',1); RAISE EXCEPTION 'AAL1 MFA enable accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',true);
DO $$ BEGIN
 IF (public.admin_company_mutate('setting',(SELECT id FROM public.admin_platform_settings WHERE key='admin_mfa_required'),
  '{"value":true,"reason":"Require second factor for staff"}',1)->>'version')::int<>2 THEN RAISE EXCEPTION 'AAL2 MFA enable'; END IF;
END $$;
SELECT set_config('request.jwt.claims','{"aal":"aal1"}',true);
DO $$ BEGIN
 IF public.admin_company_session()->>'mfaRequired'<>'true' THEN RAISE EXCEPTION 'AAL1 MFA recovery session'; END IF;
 BEGIN PERFORM public.admin_company_list('settings',1,NULL,NULL); RAISE EXCEPTION 'AAL1 scoped read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
SET LOCAL ROLE service_role;
DO $$ BEGIN
 IF NOT public.admin_company_assert_owner('a0000000-0000-0000-0000-000000000001','aal2') THEN RAISE EXCEPTION 'service owner proof'; END IF;
 BEGIN PERFORM public.admin_company_assert_owner('a0000000-0000-0000-0000-000000000001','aal1'); RAISE EXCEPTION 'service AAL1 accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_company_assert_owner('b0000000-0000-0000-0000-000000000001','aal2'); RAISE EXCEPTION 'service nonowner accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.admin_company_assert_owner('a0000000-0000-0000-0000-000000000001','aal2'); RAISE EXCEPTION 'client owner proof accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 BEGIN UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000001'; RAISE EXCEPTION 'last owner deactivated';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'last_active_owner' THEN RAISE; END IF; END;
END $$;
ROLLBACK;
