-- 20260609000009_message_notifications.sql
-- Push program — Stream B (use-case producers), 1/2: new-message notifications.
--
-- The audit's P1 gap was "a new chat message pushes NOTHING at all". This adds
-- the missing producer: an AFTER INSERT trigger on public.messages that inserts a
-- single notification row for the OTHER conversation participant (never the
-- sender). The central notifications_push_fanout trigger (20260609000007) turns
-- that row into a push — no app code, no per-feature FCM wiring.
--
-- Privacy (spec §8 decision 5): copy is "New message from <name>", NOT the
-- message text. Tapping opens the thread via data.conversation_id.
--
-- Schema (verified against 20260511000004_messaging.sql +
-- 20260603000001_messaging_realtime_fixes.sql):
--   conversations(id, builder_id, trade_id, ...)  -- both FK -> profiles.id
--   messages(id, conversation_id, sender_id, body, ...)
--   profiles(id, display_name, ...)               -- universal display name
--
-- notification_category('message_received') = 'messages' (LIKE 'message%'), so
-- the central trigger gates this on the user's 'messages' push preference.
--
-- SECURITY DEFINER + search_path='' so the insert reaches the counterparty's
-- notifications row despite owner-only RLS, mirroring notify_trades_on_new_job.

CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recipient_id  uuid;
  v_sender_name   text;
BEGIN
  -- Resolve the OTHER participant: whichever of (builder_id, trade_id) is not
  -- the sender. Returns NULL if the conversation is gone (defensive).
  SELECT CASE
           WHEN c.builder_id = NEW.sender_id THEN c.trade_id
           ELSE c.builder_id
         END
    INTO v_recipient_id
    FROM public.conversations c
   WHERE c.id = NEW.conversation_id;

  -- Skip if no recipient resolved, or sender == recipient (self-conversation /
  -- data anomaly) — never notify the sender about their own message.
  IF v_recipient_id IS NULL OR v_recipient_id = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  SELECT p.display_name INTO v_sender_name
    FROM public.profiles p
   WHERE p.id = NEW.sender_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_recipient_id,
    'message_received',
    'New message',
    'New message from ' || COALESCE(NULLIF(v_sender_name, ''), 'someone'),
    jsonb_build_object('conversation_id', NEW.conversation_id)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_on_new_message_trg ON public.messages;
CREATE TRIGGER notify_on_new_message_trg
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_message();

COMMENT ON FUNCTION public.notify_on_new_message() IS
  'Stream B producer: on a new message, inserts a message_received notification '
  'for the OTHER conversation participant (never the sender). Central push '
  'fanout delivers it. Copy is "New message from <name>" (no message preview).';

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- DROP TRIGGER IF EXISTS notify_on_new_message_trg ON public.messages;
-- DROP FUNCTION IF EXISTS public.notify_on_new_message();
-- ============================================================================
