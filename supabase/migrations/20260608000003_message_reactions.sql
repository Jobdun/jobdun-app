-- ============================================================
-- Messaging Phase C — message reactions (one per user per message)
-- Spec: docs/superpowers/specs/2026-06-08-messaging-phase-c-actions-design.md
--
-- One reaction per user per message (PRIMARY KEY (message_id, user_id)), so a
-- message carries at most two reactions (one builder + one tradie). Switching
-- emoji = upsert; tapping the same emoji = delete (toggle off). conversation_id
-- is denormalised so the realtime stream + RLS can scope by conversation
-- without a join.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.message_reactions (
  message_id      uuid NOT NULL REFERENCES public.messages(id)       ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id)  ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.profiles(id)       ON DELETE CASCADE,
  emoji           text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS message_reactions_conversation_idx
  ON public.message_reactions (conversation_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Participants of the conversation can read every reaction in it.
DO $$ BEGIN
  CREATE POLICY "reactions_select" ON public.message_reactions FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- A user may only write their OWN reaction, only in a conversation they're in.
DO $$ BEGIN
  CREATE POLICY "reactions_insert" ON public.message_reactions FOR INSERT
    WITH CHECK (
      user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "reactions_update" ON public.message_reactions FOR UPDATE
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "reactions_delete" ON public.message_reactions FOR DELETE
    USING (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Realtime delivery (Postgres Changes / .stream()).
ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
