BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.admin_chat_send_attachment(uuid,text,uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'attachment RPC missing'; END IF;
END $$;
SELECT set_config('request.jwt.claim.role','service_role',true);
UPDATE auth.users SET email='staff'||right(id::text,1)||'@jobdun.com.au',email_confirmed_at=now() WHERE id::text LIKE 'a%';
UPDATE public.admin_platform_settings SET value='false' WHERE key='admin_mfa_required';
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.admin_chat_open('a0000000-0000-0000-0000-000000000002') AS thread \gset
SELECT set_config('chat.file_thread', :'thread',true);
DO $$ BEGIN
 IF has_function_privilege('authenticated','public.admin_chat_file_validate(uuid,text,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.admin_chat_attachments','INSERT') THEN RAISE EXCEPTION 'trust escalation granted'; END IF;
 BEGIN PERFORM public.admin_chat_send_attachment(current_setting('chat.file_thread')::uuid,'',gen_random_uuid(),gen_random_uuid()); RAISE EXCEPTION 'unvalidated accepted'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'invalid_attachment' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
SELECT public.admin_chat_file_reserve('a0000000-0000-0000-0000-000000000001','aal1',:'thread','10000000-0000-4000-8000-000000000001','notes.txt','text/plain',5,repeat('a',64))->>'id' AS attachment \gset
SELECT set_config('chat.file_id', :'attachment',true);
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.admin_chat_file_reserve('a0000000-0000-0000-0000-000000000001','aal1',current_setting('chat.file_thread')::uuid,'10000000-0000-4000-8000-000000000001','notes.txt','text/plain',5,repeat('a',64));
 IF a->>'id'<>current_setting('chat.file_id') THEN RAISE EXCEPTION 'upload retry not stable'; END IF;
 BEGIN PERFORM public.admin_chat_file_reserve('a0000000-0000-0000-0000-000000000001','aal1',current_setting('chat.file_thread')::uuid,'10000000-0000-4000-8000-000000000001','notes.txt','text/plain',5,repeat('b',64)); RAISE EXCEPTION 'changed bytes accepted'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'retry_payload_changed' THEN RAISE; END IF; END;
 BEGIN PERFORM public.admin_chat_file_access('a0000000-0000-0000-0000-000000000002','aal1',current_setting('chat.file_id')::uuid); RAISE EXCEPTION 'pending leaked to peer'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT public.admin_chat_file_validate('a0000000-0000-0000-0000-000000000001','aal1',:'attachment');
SELECT set_config('request.jwt.claim.role','authenticated',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.admin_chat_send_attachment(current_setting('chat.file_thread')::uuid,'','10000000-0000-4000-8000-000000000001',current_setting('chat.file_id')::uuid);
 b:=public.admin_chat_send_attachment(current_setting('chat.file_thread')::uuid,'','10000000-0000-4000-8000-000000000001',current_setting('chat.file_id')::uuid);
 IF a<>b OR a->'attachment'->>'name'<>'notes.txt' THEN RAISE EXCEPTION 'hydration/retry failed'; END IF;
 IF public.admin_chat_history(current_setting('chat.file_thread')::uuid)->'messages'->0->'attachment' <> a->'attachment' THEN RAISE EXCEPTION 'history hydration failed'; END IF;
 IF public.admin_chat_inbox()->0->>'preview'<>'notes.txt' THEN RAISE EXCEPTION 'inbox filename missing'; END IF;
 BEGIN PERFORM public.admin_chat_send(current_setting('chat.file_thread')::uuid,'changed','10000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'text reused attachment tag'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'retry_payload_changed' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
DO $$ BEGIN
 PERFORM public.admin_chat_file_access('a0000000-0000-0000-0000-000000000002','aal1',current_setting('chat.file_id')::uuid);
 BEGIN PERFORM public.admin_chat_file_access('a0000000-0000-0000-0000-000000000003','aal1',current_setting('chat.file_id')::uuid); RAISE EXCEPTION 'unrelated owner access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Expired pending cleanup must release capacity while preserving retry identity.
DO $$ DECLARE pending jsonb; claimed jsonb; BEGIN
 pending:=public.admin_chat_file_reserve('a0000000-0000-0000-0000-000000000001','aal1',current_setting('chat.file_thread')::uuid,gen_random_uuid(),'abandoned.txt','text/plain',5,repeat('a',64));
 UPDATE public.admin_chat_attachments SET expires_at=now()-interval '1 hour' WHERE id=(pending->>'id')::uuid;
 claimed:=public.admin_chat_file_cleanup_claim();
 IF jsonb_array_length(claimed)<>1 OR claimed->0->>'id'<>pending->>'id' THEN RAISE EXCEPTION 'cleanup claim mismatch'; END IF;
 PERFORM public.admin_chat_file_cleanup_done((pending->>'id')::uuid);
 IF jsonb_array_length(public.admin_chat_file_cleanup_claim())<>0 THEN RAISE EXCEPTION 'cleaned tombstone claimed repeatedly'; END IF;
 IF (SELECT state FROM public.admin_chat_attachments WHERE id=(pending->>'id')::uuid)<>'cleaned' THEN RAISE EXCEPTION 'cleanup did not preserve tombstone'; END IF;
END $$;
UPDATE public.admin_chat_attachments SET expires_at=now()-interval '1 day';
DO $$ BEGIN
 IF jsonb_array_length(public.admin_chat_file_cleanup_claim())<>0 THEN RAISE EXCEPTION 'finalized file cleanup'; END IF;
END $$;
UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000002';
DO $$ BEGIN
 PERFORM public.admin_chat_file_access('a0000000-0000-0000-0000-000000000001','aal1',current_setting('chat.file_id')::uuid);
 BEGIN PERFORM public.admin_chat_file_access('a0000000-0000-0000-0000-000000000002','aal1',current_setting('chat.file_id')::uuid); RAISE EXCEPTION 'revoked access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
\echo 'Staff attachments trust boundary, immutable retries, hydration, privacy and finalized cleanup passed.'
