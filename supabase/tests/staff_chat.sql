-- Only disposable local fixtures. No Auth service, external network or delivery.
BEGIN;
SELECT set_config('request.jwt.claim.role','service_role',true);
UPDATE auth.users SET email='staff'||right(id::text,1)||'@jobdun.com.au',email_confirmed_at=now() WHERE id::text LIKE 'a%';
UPDATE public.profiles SET user_status='active' WHERE id='a0000000-0000-0000-0000-000000000003';
INSERT INTO public.admin_staff(user_id,staff_role) VALUES('a0000000-0000-0000-0000-000000000003','owner') ON CONFLICT(user_id) DO UPDATE SET active=true;
UPDATE public.admin_staff SET staff_role='read_only' WHERE user_id='a0000000-0000-0000-0000-000000000002';
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
SELECT public.admin_chat_open('a0000000-0000-0000-0000-000000000002') AS thread \gset
SELECT set_config('chat.test_thread', :'thread',true);
DO $$ DECLARE t uuid:=current_setting('chat.test_thread')::uuid; first jsonb; retry jsonb;
BEGIN
 first:=public.admin_chat_send(t,' First message ','10000000-0000-4000-8000-000000000001');
 retry:=public.admin_chat_send(t,'First message','10000000-0000-4000-8000-000000000001');
 IF first<>retry OR (SELECT count(*) FROM public.admin_chat_messages)<>1 THEN RAISE EXCEPTION 'duplicate retry'; END IF;
 IF public.admin_chat_open('a0000000-0000-0000-0000-000000000002')<>t THEN RAISE EXCEPTION 'duplicate thread'; END IF;
 BEGIN PERFORM public.admin_chat_send(t,'changed body','10000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'changed retry accepted'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'retry_payload_changed' THEN RAISE; END IF; END;
 IF has_table_privilege('authenticated','public.admin_chat_messages','INSERT') THEN RAISE EXCEPTION 'direct writes granted'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ DECLARE t uuid:=current_setting('chat.test_thread')::uuid; inbox jsonb; first_id bigint; second_id bigint;
BEGIN
 inbox:=public.admin_chat_inbox();
 IF (inbox->0->>'unread')::int<>1 THEN RAISE EXCEPTION 'unread missing'; END IF;
 SELECT min(id) INTO first_id FROM public.admin_chat_messages WHERE thread_id=t;
 second_id:=(public.admin_chat_send(t,'Reply from read-only staff','10000000-0000-4000-8000-000000000002')->>'id')::bigint;
 PERFORM public.admin_chat_read(t,second_id); PERFORM public.admin_chat_read(t,first_id);
 IF (SELECT last_message_id FROM public.admin_chat_reads WHERE thread_id=t)<>second_id THEN RAISE EXCEPTION 'read moved backward'; END IF;
 IF jsonb_array_length(public.admin_chat_history(t)->'messages')<>2 THEN RAISE EXCEPTION 'history mismatch'; END IF;
 IF jsonb_array_length(public.admin_chat_history(t,second_id)->'messages')<>1 THEN RAISE EXCEPTION 'cursor mismatch'; END IF;
END $$;
-- A third owner has no special access to someone else's conversation.
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.admin_chat_messages)<>0 OR (SELECT count(*) FROM public.admin_chat_threads)<>0 THEN RAISE EXCEPTION 'third-party leak'; END IF;
 BEGIN PERFORM public.admin_chat_history(current_setting('chat.test_thread')::uuid); RAISE EXCEPTION 'third party history allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- More than one history window, including the forward reconnect cursor.
INSERT INTO public.admin_chat_messages(thread_id,sender_id,client_tag,body)
 SELECT current_setting('chat.test_thread')::uuid,'a0000000-0000-0000-0000-000000000001',gen_random_uuid(),'History fixture '||n
 FROM generate_series(1,65) n;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE t uuid:=current_setting('chat.test_thread')::uuid; page jsonb; first_id bigint; cursor_id bigint;
BEGIN
 page:=public.admin_chat_history(t);
 IF jsonb_array_length(page->'messages')<>50 OR NOT(page->>'hasMore')::boolean THEN RAISE EXCEPTION 'backward pagination'; END IF;
 SELECT min(id) INTO first_id FROM public.admin_chat_messages WHERE thread_id=t;
 page:=public.admin_chat_history(t,NULL,first_id);
 IF jsonb_array_length(page->'messages')<>50 OR NOT(page->>'hasMore')::boolean THEN RAISE EXCEPTION 'forward pagination'; END IF;
 cursor_id:=(page->'messages'->49->>'id')::bigint;
 page:=public.admin_chat_history(t,NULL,cursor_id);
 IF jsonb_array_length(page->'messages')<>16 OR (page->>'hasMore')::boolean THEN RAISE EXCEPTION 'forward tail missing'; END IF;
 BEGIN PERFORM public.admin_chat_read(t,9223372036854775807); RAISE EXCEPTION 'forged read cursor accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.admin_chat_send(t,'Rate limited',gen_random_uuid()); RAISE EXCEPTION 'rate limit bypass'; EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'chat_rate_limit' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE public.admin_platform_settings SET value='true' WHERE key='admin_mfa_required';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF public.admin_chat_allowed() THEN RAISE EXCEPTION 'MFA bypass'; END IF;
END $$;
SELECT set_config('request.jwt.claims','{"aal":"aal2"}',true);
DO $$ BEGIN IF NOT public.admin_chat_allowed() THEN RAISE EXCEPTION 'AAL2 staff denied'; END IF; END $$;
SELECT set_config('request.jwt.claims','{}',true);
RESET ROLE;
UPDATE public.admin_platform_settings SET value='false' WHERE key='admin_mfa_required';
UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
DO $$ BEGIN
 BEGIN PERFORM public.admin_chat_send(current_setting('chat.test_thread')::uuid,'No longer allowed','10000000-0000-4000-8000-000000000003'); RAISE EXCEPTION 'inactive recipient allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.admin_chat_messages)<>0 THEN RAISE EXCEPTION 'revoked member leaked history'; END IF;
 BEGIN PERFORM public.admin_chat_inbox(); RAISE EXCEPTION 'revoked member allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
\echo 'Staff chat privacy, retry, read-only staff, cursors, MFA and revocation checks passed.'
