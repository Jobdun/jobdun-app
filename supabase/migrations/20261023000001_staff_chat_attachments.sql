-- Local-only until reviewed rollout. Trusted metadata is writable only by Edge.
BEGIN;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('admin-chat-files','admin-chat-files',false,3145728,ARRAY['image/jpeg','image/png','image/webp','application/pdf','text/plain'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=3145728,allowed_mime_types=excluded.allowed_mime_types;
-- Restrictive policies also prevent an existing broad permissive Storage policy
-- from accidentally exposing this bucket. Service role bypasses RLS.
DROP POLICY IF EXISTS admin_chat_files_service_only ON storage.objects;
CREATE POLICY admin_chat_files_service_only ON storage.objects AS RESTRICTIVE FOR ALL TO anon,authenticated
USING(bucket_id <> 'admin-chat-files') WITH CHECK(bucket_id <> 'admin-chat-files');
CREATE TABLE public.admin_chat_attachments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 thread_id uuid NOT NULL REFERENCES public.admin_chat_threads(id),
 owner_id uuid NOT NULL REFERENCES public.profiles(id),
 client_tag uuid NOT NULL,
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 180 AND name !~ '[[:cntrl:]/\\]'),
 mime text NOT NULL CHECK(mime IN('image/jpeg','image/png','image/webp','application/pdf','text/plain')),
 size bigint NOT NULL CHECK(size BETWEEN 1 AND 3145728),
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 state text NOT NULL DEFAULT 'reserved' CHECK(state IN('reserved','validated','finalized','cleaning','cleaned')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '1 hour',
 UNIQUE(owner_id,client_tag)
);
CREATE INDEX admin_chat_attachments_expiry_idx ON public.admin_chat_attachments(expires_at) WHERE state <> 'finalized';
CREATE INDEX admin_chat_attachments_owner_idx ON public.admin_chat_attachments(owner_id,created_at DESC);
ALTER TABLE public.admin_chat_attachments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_chat_attachments FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.admin_chat_attachments TO service_role;
ALTER TABLE public.admin_chat_messages ADD COLUMN attachment_id uuid UNIQUE REFERENCES public.admin_chat_attachments(id);
ALTER TABLE public.admin_chat_messages DROP CONSTRAINT admin_chat_messages_body_check;
ALTER TABLE public.admin_chat_messages ADD CONSTRAINT admin_chat_messages_body_check CHECK (
 length(btrim(body)) BETWEEN 0 AND 5000 AND (length(btrim(body))>0 OR attachment_id IS NOT NULL));

CREATE FUNCTION public.admin_chat_file_json(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',id,'name',name,'mime',mime,'size',size) FROM public.admin_chat_attachments WHERE id=p_id
$$;
CREATE FUNCTION public.admin_chat_file_actor_require(p_actor uuid,p_aal text,p_thread uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 IF p_aal NOT IN('aal1','aal2') OR p_aal IS NULL OR NOT public.admin_chat_eligible(p_actor) OR
 (EXISTS(SELECT 1 FROM public.admin_platform_settings WHERE key='admin_mfa_required' AND value='true'::jsonb) AND p_aal<>'aal2')
 OR NOT EXISTS(SELECT 1 FROM public.admin_chat_threads WHERE id=p_thread AND p_actor IN(member_low,member_high))
 THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
END $$;
CREATE FUNCTION public.admin_chat_file_require(p_actor uuid,p_aal text,p_thread uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE peer uuid;
BEGIN
 PERFORM public.admin_chat_file_actor_require(p_actor,p_aal,p_thread);
 SELECT CASE WHEN member_low=p_actor THEN member_high ELSE member_low END INTO peer FROM public.admin_chat_threads WHERE id=p_thread;
 IF NOT public.admin_chat_eligible(peer) THEN RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
END $$;
CREATE FUNCTION public.admin_chat_file_reserve(p_actor uuid,p_aal text,p_thread uuid,p_client_tag uuid,p_name text,p_mime text,p_size bigint,p_sha256 text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.admin_chat_attachments%ROWTYPE;
BEGIN
 PERFORM public.admin_chat_file_require(p_actor,p_aal,p_thread);
 -- Serialize limits and immutable retry identity across all of an actor's threads.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text,71423));
 IF p_client_tag IS NULL OR p_name IS NULL OR length(p_name) NOT BETWEEN 1 AND 180 OR p_name ~ '[[:cntrl:]/\\]' OR
 p_mime IS NULL OR p_mime NOT IN('image/jpeg','image/png','image/webp','application/pdf','text/plain') OR
 p_size IS NULL OR p_size NOT BETWEEN 1 AND 3145728 OR p_sha256 IS NULL OR p_sha256 !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION 'invalid_file'; END IF;
 SELECT * INTO item FROM public.admin_chat_attachments WHERE owner_id=p_actor AND client_tag=p_client_tag FOR UPDATE;
 IF FOUND THEN
  IF item.thread_id<>p_thread OR item.name<>p_name OR item.mime<>p_mime OR item.size<>p_size OR item.sha256<>p_sha256 THEN RAISE EXCEPTION 'retry_payload_changed'; END IF;
  IF item.state='cleaning' OR (item.state<>'finalized' AND item.expires_at<=clock_timestamp()) THEN RAISE EXCEPTION 'attachment_expired'; END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM public.admin_chat_messages WHERE thread_id=p_thread AND sender_id=p_actor AND client_tag=p_client_tag) THEN RAISE EXCEPTION 'retry_payload_changed'; END IF;
  IF (SELECT count(*) FROM public.admin_chat_attachments WHERE owner_id=p_actor AND created_at>clock_timestamp()-interval '1 minute')>=20 OR
   (SELECT count(*) FROM public.admin_chat_attachments WHERE owner_id=p_actor AND state IN('reserved','validated','cleaning'))>=10
  THEN RAISE EXCEPTION 'attachment_rate_limit'; END IF;
  INSERT INTO public.admin_chat_attachments(thread_id,owner_id,client_tag,name,mime,size,sha256)
  VALUES(p_thread,p_actor,p_client_tag,p_name,p_mime,p_size,p_sha256) RETURNING * INTO item;
 END IF;
 RETURN public.admin_chat_file_json(item.id)||jsonb_build_object('path',item.id::text,'state',item.state);
END $$;
CREATE FUNCTION public.admin_chat_file_validate(p_actor uuid,p_aal text,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.admin_chat_attachments%ROWTYPE;
BEGIN
 SELECT * INTO item FROM public.admin_chat_attachments WHERE id=p_id FOR UPDATE;
 PERFORM public.admin_chat_file_require(p_actor,p_aal,item.thread_id);
 IF item.owner_id<>p_actor OR item.state NOT IN('reserved','validated','finalized') OR (item.state<>'finalized' AND item.expires_at<=clock_timestamp()) THEN RAISE EXCEPTION 'invalid_attachment'; END IF;
 IF item.state='reserved' THEN UPDATE public.admin_chat_attachments SET state='validated' WHERE id=p_id; END IF;
 RETURN public.admin_chat_file_json(item.id);
END $$;
CREATE FUNCTION public.admin_chat_file_access(p_actor uuid,p_aal text,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.admin_chat_attachments%ROWTYPE;
BEGIN
 SELECT * INTO item FROM public.admin_chat_attachments WHERE id=p_id;
 PERFORM public.admin_chat_file_actor_require(p_actor,p_aal,item.thread_id);
 IF item.state<>'finalized' THEN PERFORM public.admin_chat_file_require(p_actor,p_aal,item.thread_id); END IF;
 IF item.state NOT IN('validated','finalized') OR (item.state<>'finalized' AND (item.owner_id<>p_actor OR item.expires_at<=clock_timestamp())) THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 RETURN public.admin_chat_file_json(item.id)||jsonb_build_object('path',item.id::text);
END $$;
-- Cleanup first locks expired non-finalized rows and permanently makes them
-- unsendable. Failed Storage removal leaves a retryable cleaning tombstone.
CREATE FUNCTION public.admin_chat_file_cleanup_claim() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 WITH candidates AS (SELECT id FROM public.admin_chat_attachments a WHERE ((state IN('reserved','validated','cleaning') AND expires_at<=clock_timestamp()) OR (state='cleaned' AND created_at<clock_timestamp()-interval '24 hours'))
 AND NOT EXISTS(SELECT 1 FROM public.admin_chat_messages m WHERE m.attachment_id=a.id) ORDER BY expires_at LIMIT 10 FOR UPDATE SKIP LOCKED),
 claimed AS (UPDATE public.admin_chat_attachments a SET state='cleaning' FROM candidates c WHERE a.id=c.id RETURNING a.id)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'path',id::text)),'[]'::jsonb) INTO result FROM claimed;
 RETURN result;
END $$;
CREATE FUNCTION public.admin_chat_file_cleanup_done(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 -- Mark successfully removed objects separately, releasing pending capacity.
 -- Keep immutable retry tombstones for 24 hours; a second removal at that time
 -- catches any very late upload that raced the first expiry cleanup.
 UPDATE public.admin_chat_attachments SET state='cleaned' WHERE id=p_id AND state='cleaning' AND created_at>=clock_timestamp()-interval '24 hours';
 -- Deletion remains guarded against any linked message even under corruption.
 DELETE FROM public.admin_chat_attachments a WHERE id=p_id AND state='cleaning' AND created_at<clock_timestamp()-interval '24 hours'
 AND NOT EXISTS(SELECT 1 FROM public.admin_chat_messages m WHERE m.attachment_id=a.id);
END $$;
CREATE FUNCTION public.admin_chat_send_attachment(p_thread uuid,p_body text,p_client_tag uuid,p_attachment uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.admin_chat_messages%ROWTYPE; file public.admin_chat_attachments%ROWTYPE; peer uuid; v_body text:=btrim(coalesce(p_body,''));
BEGIN
 PERFORM public.admin_chat_require();
 IF NOT public.admin_chat_member(p_thread) THEN RAISE EXCEPTION 'chat_denied' USING ERRCODE='42501'; END IF;
 SELECT CASE WHEN member_low=auth.uid() THEN member_high ELSE member_low END INTO peer FROM public.admin_chat_threads WHERE id=p_thread FOR UPDATE;
 IF NOT public.admin_chat_eligible(peer) THEN RAISE EXCEPTION 'recipient_unavailable' USING ERRCODE='42501'; END IF;
 IF length(v_body)>5000 OR p_client_tag IS NULL OR p_attachment IS NULL THEN RAISE EXCEPTION 'invalid_message'; END IF;
 SELECT * INTO item FROM public.admin_chat_messages WHERE thread_id=p_thread AND sender_id=auth.uid() AND client_tag=p_client_tag;
 IF FOUND THEN
  IF item.body<>v_body OR item.attachment_id IS DISTINCT FROM p_attachment THEN RAISE EXCEPTION 'retry_payload_changed'; END IF;
 ELSE
  SELECT * INTO file FROM public.admin_chat_attachments WHERE id=p_attachment FOR UPDATE;
  IF NOT FOUND OR file.owner_id<>auth.uid() OR file.thread_id<>p_thread OR file.client_tag<>p_client_tag OR file.state<>'validated' OR file.expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'invalid_attachment'; END IF;
  IF (SELECT count(*) FROM public.admin_chat_messages WHERE sender_id=auth.uid() AND created_at>clock_timestamp()-interval '1 minute')>=30 THEN RAISE EXCEPTION 'chat_rate_limit'; END IF;
  INSERT INTO public.admin_chat_messages(thread_id,sender_id,client_tag,body,attachment_id) VALUES(p_thread,auth.uid(),p_client_tag,v_body,p_attachment) RETURNING * INTO item;
  UPDATE public.admin_chat_attachments SET state='finalized' WHERE id=p_attachment;
 END IF;
 RETURN jsonb_build_object('id',item.id,'senderId',item.sender_id,'body',item.body,'createdAt',item.created_at,'clientTag',item.client_tag,'attachment',public.admin_chat_file_json(item.attachment_id));
END $$;

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
 last_message.created_at AS "lastAt",left(coalesce(nullif(last_message.body,''),public.admin_chat_file_json(last_message.attachment_id)->>'name'),120) AS preview
 FROM public.admin_chat_threads t JOIN public.profiles p ON p.id=CASE WHEN t.member_low=auth.uid() THEN t.member_high ELSE t.member_low END
 LEFT JOIN public.admin_chat_reads r ON r.thread_id=t.id AND r.user_id=auth.uid()
 LEFT JOIN LATERAL (SELECT body,created_at,attachment_id FROM public.admin_chat_messages WHERE thread_id=t.id ORDER BY id DESC LIMIT 1) last_message ON true
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
 (SELECT id,sender_id AS "senderId",body,created_at AS "createdAt",client_tag AS "clientTag",public.admin_chat_file_json(attachment_id) AS attachment
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
  IF item.body<>v_body OR item.attachment_id IS NOT NULL THEN RAISE EXCEPTION 'retry_payload_changed'; END IF;
 ELSE
  IF (SELECT count(*) FROM public.admin_chat_messages WHERE sender_id=auth.uid() AND created_at>clock_timestamp()-interval '1 minute')>=30 THEN
   RAISE EXCEPTION 'chat_rate_limit'; END IF;
  INSERT INTO public.admin_chat_messages(thread_id,sender_id,client_tag,body) VALUES(p_thread,auth.uid(),p_client_tag,v_body) RETURNING * INTO item;
 END IF;
 RETURN jsonb_build_object('id',item.id,'senderId',item.sender_id,'body',item.body,'createdAt',item.created_at,'clientTag',item.client_tag);
END $$;

REVOKE ALL ON FUNCTION public.admin_chat_file_actor_require(uuid,text,uuid),public.admin_chat_file_json(uuid),public.admin_chat_file_require(uuid,text,uuid),public.admin_chat_file_reserve(uuid,text,uuid,uuid,text,text,bigint,text),public.admin_chat_file_validate(uuid,text,uuid),public.admin_chat_file_access(uuid,text,uuid),public.admin_chat_file_cleanup_claim(),public.admin_chat_file_cleanup_done(uuid),public.admin_chat_send_attachment(uuid,text,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_chat_file_require(uuid,text,uuid),public.admin_chat_file_reserve(uuid,text,uuid,uuid,text,text,bigint,text),public.admin_chat_file_validate(uuid,text,uuid),public.admin_chat_file_access(uuid,text,uuid),public.admin_chat_file_cleanup_claim(),public.admin_chat_file_cleanup_done(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_chat_send_attachment(uuid,text,uuid,uuid) TO authenticated;
COMMIT;
