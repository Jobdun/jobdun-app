-- Roll back web/Edge attachment use first. This refuses destructive rollback
-- while finalized messages exist; export/retain those files before removal.
BEGIN;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.admin_chat_messages WHERE attachment_id IS NOT NULL) THEN RAISE EXCEPTION 'attachment_messages_require_retention'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.admin_chat_inbox() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.admin_chat_require();
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x."lastAt" DESC NULLS LAST,x.id),'[]'::jsonb) INTO result FROM (
 SELECT t.id,p.id AS "peerId",coalesce(nullif(p.display_name,''),'Staff member') AS name,
 public.admin_chat_eligible(p.id) AS available,
 (SELECT count(*) FROM public.admin_chat_messages m WHERE m.thread_id=t.id AND m.sender_id<>auth.uid()
 AND m.id>coalesce(r.last_message_id,0)) AS unread,
 last_message.created_at AS "lastAt",left(last_message.body,120) AS preview
 FROM public.admin_chat_threads t JOIN public.profiles p ON p.id=CASE WHEN t.member_low=auth.uid() THEN t.member_high ELSE t.member_low END
 LEFT JOIN public.admin_chat_reads r ON r.thread_id=t.id AND r.user_id=auth.uid()
 LEFT JOIN LATERAL (SELECT body,created_at FROM public.admin_chat_messages WHERE thread_id=t.id ORDER BY id DESC LIMIT 1) last_message ON true
 WHERE auth.uid() IN(t.member_low,t.member_high)
 ORDER BY last_message.created_at DESC NULLS LAST,t.id LIMIT 100) x;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.admin_chat_history(p_thread uuid,p_before bigint DEFAULT NULL,p_after bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; oldest bigint; newest bigint;
BEGIN
 PERFORM public.admin_chat_require();
 IF NOT public.admin_chat_member(p_thread) THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 IF (p_before IS NOT NULL AND p_before<1) OR (p_after IS NOT NULL AND p_after<1) OR (p_before IS NOT NULL AND p_after IS NOT NULL) THEN RAISE EXCEPTION 'invalid_cursor'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]'::jsonb),min(x.id),max(x.id) INTO result,oldest,newest FROM
 (SELECT id,sender_id AS "senderId",body,created_at AS "createdAt",client_tag AS "clientTag"
 FROM public.admin_chat_messages WHERE thread_id=p_thread AND(p_before IS NULL OR id<p_before) AND(p_after IS NULL OR id>p_after)
 ORDER BY CASE WHEN p_after IS NOT NULL THEN id END ASC,id DESC LIMIT 50) x;
 RETURN jsonb_build_object('messages',result,'hasMore',CASE WHEN p_after IS NULL THEN EXISTS(SELECT 1 FROM public.admin_chat_messages WHERE thread_id=p_thread AND id<oldest) ELSE EXISTS(SELECT 1 FROM public.admin_chat_messages WHERE thread_id=p_thread AND id>newest) END);
END $$;
CREATE OR REPLACE FUNCTION public.admin_chat_send(p_thread uuid,p_body text,p_client_tag uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.admin_chat_messages%ROWTYPE; peer uuid; v_body text:=btrim(p_body);
BEGIN
 PERFORM public.admin_chat_require();
 IF NOT public.admin_chat_member(p_thread) THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 SELECT CASE WHEN member_low=auth.uid() THEN member_high ELSE member_low END INTO peer
 FROM public.admin_chat_threads WHERE id=p_thread FOR UPDATE;
 IF NOT public.admin_chat_eligible(peer) THEN RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
 IF v_body IS NULL OR length(v_body) NOT BETWEEN 1 AND 5000 OR p_client_tag IS NULL THEN RAISE EXCEPTION 'invalid_message'; END IF;
 SELECT * INTO item FROM public.admin_chat_messages WHERE thread_id=p_thread AND sender_id=auth.uid() AND client_tag=p_client_tag;
 IF FOUND THEN
  IF item.body<>v_body THEN RAISE EXCEPTION 'retry_payload_changed'; END IF;
 ELSE
  IF (SELECT count(*) FROM public.admin_chat_messages WHERE sender_id=auth.uid() AND created_at>clock_timestamp()-interval '1 minute')>=30 THEN
   RAISE EXCEPTION 'chat_rate_limit'; END IF;
  INSERT INTO public.admin_chat_messages(thread_id,sender_id,client_tag,body) VALUES(p_thread,auth.uid(),p_client_tag,v_body) RETURNING * INTO item;
 END IF;
 RETURN jsonb_build_object('id',item.id,'senderId',item.sender_id,'body',item.body,'createdAt',item.created_at,'clientTag',item.client_tag);
END $$;
DROP FUNCTION public.admin_chat_send_attachment(uuid,text,uuid,uuid),public.admin_chat_file_cleanup_done(uuid),public.admin_chat_file_cleanup_claim(),public.admin_chat_file_access(uuid,text,uuid),public.admin_chat_file_validate(uuid,text,uuid),public.admin_chat_file_reserve(uuid,text,uuid,uuid,text,text,bigint,text),public.admin_chat_file_require(uuid,text,uuid),public.admin_chat_file_actor_require(uuid,text,uuid),public.admin_chat_file_json(uuid);
ALTER TABLE public.admin_chat_messages DROP CONSTRAINT admin_chat_messages_body_check;
ALTER TABLE public.admin_chat_messages DROP COLUMN attachment_id;
ALTER TABLE public.admin_chat_messages ADD CONSTRAINT admin_chat_messages_body_check CHECK(length(btrim(body)) BETWEEN 1 AND 5000);
DROP TABLE public.admin_chat_attachments;
-- Keep restrictive object policy, private bucket and objects for operator
-- retention. Other broad Storage policies must never expose retained files.
COMMIT;
