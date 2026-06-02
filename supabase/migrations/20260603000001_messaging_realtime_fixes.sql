-- ============================================================
-- Messaging realtime + integrity fixes
-- Audit: docs/SUPABASE_REALTIME_BACKEND_AUDIT.md  (F-1, F-2, F-4, F-5, F-6)
--
-- Before this migration the messaging data layer + MessagingController were
-- fully wired, but the real setup could not work end-to-end because:
--   F-2  no table was in the supabase_realtime publication -> no live updates
--   F-1  nothing created a conversation -> messaging had no entry point
--   F-4  markConversationRead() wrote *_last_read_at columns that didn't exist
--   F-5  the inbox query never resolved the counterparty (always "Unknown")
--   F-6  the message-insert trigger only set last_message_at (no preview/unread)
-- ============================================================

-- ---------- F-4: read-receipt columns the datasource already writes ----------
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_last_read_at timestamptz,
  ADD COLUMN IF NOT EXISTS trade_last_read_at   timestamptz;

-- ---------- F-6: maintain preview + unread on every new message ----------
-- The AFTER INSERT trigger from 20260511000004 already calls this function;
-- we only widen what it maintains (no trigger re-create needed).
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.conversations c
     SET last_message_at        = NEW.created_at,
         last_message_preview   = left(NEW.body, 140),
         last_message_sender_id = NEW.sender_id,
         builder_unread_count   = c.builder_unread_count
                                   + CASE WHEN NEW.sender_id = c.trade_id   THEN 1 ELSE 0 END,
         trade_unread_count     = c.trade_unread_count
                                   + CASE WHEN NEW.sender_id = c.builder_id THEN 1 ELSE 0 END
   WHERE c.id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

-- ---------- F-1: atomic get-or-create conversation ----------
-- SECURITY DEFINER so the find-or-insert is atomic; we still assert the caller
-- is one of the two participants. Builder-initiated per the product decision,
-- but the function is symmetric so either side can open the thread.
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  p_builder uuid,
  p_trade   uuid,
  p_job     uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() NOT IN (p_builder, p_trade) THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  SELECT id INTO v_id FROM public.conversations
   WHERE builder_id = p_builder AND trade_id = p_trade
     AND ((p_job IS NULL AND job_id IS NULL) OR job_id = p_job)
   LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.conversations (builder_id, trade_id, job_id)
    VALUES (p_builder, p_trade, p_job)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.get_or_create_conversation(uuid, uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid, uuid) TO authenticated;

-- ---------- F-5: viewer-shaped inbox (counterparty resolved server-side) ----------
-- Returns one row per active conversation for the viewer, with the OTHER
-- participant's display fields and the viewer's own unread count already
-- resolved. SECURITY INVOKER -> RLS on conversations still applies, so the
-- function only ever returns rows the caller can already see.
CREATE OR REPLACE FUNCTION public.get_inbox(p_user uuid)
RETURNS TABLE (
  id                     uuid,
  job_id                 uuid,
  builder_id             uuid,
  trade_id               uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  status                 text,
  created_at             timestamptz,
  my_unread_count        int,
  other_display_name     text,
  other_avatar_url       text,
  job_title              text
) LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                      AS my_unread_count,
         other.display_name                                      AS other_display_name,
         other.avatar_url                                        AS other_avatar_url,
         j.title                                                 AS job_title
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
   WHERE (c.builder_id = p_user AND c.builder_archived_at IS NULL)
      OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL)
   ORDER BY c.last_message_at DESC NULLS LAST;
$$;
GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;

-- ---------- F-2: enable realtime delivery ----------
-- Postgres Changes / .stream() only deliver events for tables in the
-- supabase_realtime publication; REPLICA IDENTITY FULL ships the old row so
-- RLS-scoped UPDATE/DELETE events carry enough identity. (Confirmed against
-- Supabase realtime docs in the audit.)
ALTER TABLE public.messages               REPLICA IDENTITY FULL;
ALTER TABLE public.conversations          REPLICA IDENTITY FULL;
ALTER TABLE public.notifications          REPLICA IDENTITY FULL;
ALTER TABLE public.verification_documents REPLICA IDENTITY FULL;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['messages', 'conversations', 'notifications', 'verification_documents']
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;  -- already published (e.g. via Dashboard toggle)
    END;
  END LOOP;
END $$;
