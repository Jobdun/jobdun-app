-- ============================================================
-- Migration 4: Messaging — conversations and messages
-- ============================================================

CREATE TABLE IF NOT EXISTS public.conversations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id          uuid REFERENCES public.jobs(id) ON DELETE SET NULL,
  builder_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trade_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_message_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),

  UNIQUE (job_id, builder_id, trade_id)
);

CREATE INDEX conversations_builder_id_idx ON public.conversations(builder_id);
CREATE INDEX conversations_trade_id_idx ON public.conversations(trade_id);

CREATE TABLE IF NOT EXISTS public.messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body            text NOT NULL,
  read_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX messages_conversation_id_idx ON public.messages(conversation_id);
CREATE INDEX messages_sender_id_idx ON public.messages(sender_id);

-- Keep conversations.last_message_at in sync
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER messages_update_last_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_conversation_last_message();
