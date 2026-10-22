-- Private company staff chat. Does not alter marketplace messaging or roles.
BEGIN;
CREATE TABLE public.admin_chat_threads (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 member_low uuid NOT NULL REFERENCES public.profiles(id),
 member_high uuid NOT NULL REFERENCES public.profiles(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(member_low,member_high), CHECK(member_low<member_high)
);
CREATE INDEX admin_chat_threads_high_idx ON public.admin_chat_threads(member_high);
CREATE TABLE public.admin_chat_messages (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 thread_id uuid NOT NULL REFERENCES public.admin_chat_threads(id) ON DELETE CASCADE,
 sender_id uuid NOT NULL REFERENCES public.profiles(id),
 client_tag uuid NOT NULL,
 body text NOT NULL CHECK(length(btrim(body)) BETWEEN 1 AND 5000),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(thread_id,sender_id,client_tag)
);
CREATE INDEX admin_chat_messages_thread_idx ON public.admin_chat_messages(thread_id,id DESC);
CREATE INDEX admin_chat_messages_rate_idx ON public.admin_chat_messages(sender_id,created_at DESC);
CREATE TABLE public.admin_chat_reads (
 thread_id uuid NOT NULL REFERENCES public.admin_chat_threads(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES public.profiles(id), last_message_id bigint NOT NULL,
 PRIMARY KEY(thread_id,user_id)
);

CREATE FUNCTION public.admin_chat_eligible(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_company_actor_role(p_user) IS NOT NULL AND EXISTS (
 SELECT 1 FROM auth.users WHERE id=p_user AND email_confirmed_at IS NOT NULL
 AND lower(split_part(email,'@',2))='jobdun.com.au')
$$;
CREATE FUNCTION public.admin_chat_allowed() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_chat_eligible(auth.uid()) AND
 (NOT EXISTS(SELECT 1 FROM public.admin_platform_settings WHERE key='admin_mfa_required' AND value='true'::jsonb)
 OR coalesce(auth.jwt()->>'aal'='aal2',false))
$$;
CREATE FUNCTION public.admin_chat_member(p_thread uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_chat_allowed() AND EXISTS(SELECT 1 FROM public.admin_chat_threads
 WHERE id=p_thread AND auth.uid() IN(member_low,member_high))
$$;
CREATE FUNCTION public.admin_chat_require() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.admin_company_require('session');
 IF NOT public.admin_chat_allowed() THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
END $$;

ALTER TABLE public.admin_chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_chat_reads ENABLE ROW LEVEL SECURITY;
CREATE POLICY participant_read ON public.admin_chat_threads FOR SELECT TO authenticated
 USING ((SELECT public.admin_chat_allowed()) AND (SELECT auth.uid()) IN(member_low,member_high));
CREATE POLICY participant_read ON public.admin_chat_messages FOR SELECT TO authenticated
 USING (public.admin_chat_member(thread_id));
CREATE POLICY own_read_position ON public.admin_chat_reads FOR SELECT TO authenticated
 USING (user_id=(SELECT auth.uid()) AND public.admin_chat_member(thread_id));
REVOKE ALL ON public.admin_chat_threads,public.admin_chat_messages,public.admin_chat_reads FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_chat_threads,public.admin_chat_messages,public.admin_chat_reads TO authenticated;
REVOKE ALL ON SEQUENCE public.admin_chat_messages_id_seq FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.admin_chat_staff(p_query text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 PERFORM public.admin_chat_require();
 IF length(p_query)>100 THEN RAISE EXCEPTION 'invalid_query'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name,x.id),'[]'::jsonb) INTO result FROM
 (SELECT s.user_id AS id,coalesce(nullif(p.display_name,''),'Staff member') AS name,s.staff_role AS "staffRole"
 FROM public.admin_staff s JOIN public.profiles p ON p.id=s.user_id
 WHERE s.user_id<>auth.uid() AND public.admin_chat_eligible(s.user_id)
 AND (coalesce(p_query,'')='' OR position(lower(p_query) IN lower(coalesce(p.display_name,'')))>0)
 ORDER BY name,s.user_id LIMIT 50) x;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_chat_open(p_peer uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid;
BEGIN
 PERFORM public.admin_chat_require();
 IF p_peer IS NULL OR p_peer=auth.uid() OR NOT public.admin_chat_eligible(p_peer) THEN
 RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
 INSERT INTO public.admin_chat_threads(member_low,member_high) VALUES(least(auth.uid(),p_peer),greatest(auth.uid(),p_peer))
 ON CONFLICT(member_low,member_high) DO UPDATE SET member_low=excluded.member_low RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_chat_inbox() RETURNS jsonb
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
CREATE FUNCTION public.admin_chat_history(p_thread uuid,p_before bigint DEFAULT NULL,p_after bigint DEFAULT NULL) RETURNS jsonb
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
CREATE FUNCTION public.admin_chat_send(p_thread uuid,p_body text,p_client_tag uuid) RETURNS jsonb
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
CREATE FUNCTION public.admin_chat_read(p_thread uuid,p_last bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.admin_chat_require();
 IF NOT public.admin_chat_member(p_thread) OR NOT EXISTS(SELECT 1 FROM public.admin_chat_messages WHERE thread_id=p_thread AND id=p_last) THEN
 RAISE EXCEPTION 'invalid_read_position' USING ERRCODE='42501'; END IF;
 INSERT INTO public.admin_chat_reads(thread_id,user_id,last_message_id) VALUES(p_thread,auth.uid(),p_last)
 ON CONFLICT(thread_id,user_id) DO UPDATE SET last_message_id=greatest(public.admin_chat_reads.last_message_id,excluded.last_message_id);
END $$;
REVOKE ALL ON FUNCTION public.admin_chat_eligible(uuid),public.admin_chat_allowed(),public.admin_chat_member(uuid),public.admin_chat_require(),public.admin_chat_staff(text),public.admin_chat_open(uuid),public.admin_chat_inbox(),public.admin_chat_history(uuid,bigint,bigint),public.admin_chat_send(uuid,text,uuid),public.admin_chat_read(uuid,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_chat_allowed(),public.admin_chat_member(uuid),public.admin_chat_staff(text),public.admin_chat_open(uuid),public.admin_chat_inbox(),public.admin_chat_history(uuid,bigint,bigint),public.admin_chat_send(uuid,text,uuid),public.admin_chat_read(uuid,bigint) TO authenticated;
-- INSERT events wake participant-only refetches. Persisted history is authoritative.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
 ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_chat_messages;
 END IF;
END $$;
COMMIT;
