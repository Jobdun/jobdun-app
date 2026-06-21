-- Phase D CP-1 §Migration 2 — user-level blocks + send guard + get_or_create guard
-- User-level block table.
-- A block is symmetric in effect (neither side can send) but asymmetric in
-- storage (only the blocker's row exists). The blocked user cannot query this
-- table, so they cannot detect the block.

CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS blocks_blocked_id_idx ON public.blocks (blocked_id);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "blocks_select_own"
    ON public.blocks FOR SELECT
    USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "blocks_insert_own"
    ON public.blocks FOR INSERT
    WITH CHECK (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "blocks_delete_own"
    ON public.blocks FOR DELETE
    USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Amend messages_insert to reject sends from a blocked user.
-- Drop the old policy and recreate with the additional guard.
DROP POLICY IF EXISTS "messages_insert" ON public.messages;

DO $$ BEGIN
  CREATE POLICY "messages_insert"
    ON public.messages FOR INSERT
    WITH CHECK (
      auth.uid() = sender_id
      AND EXISTS (
        SELECT 1 FROM public.conversations c
         WHERE c.id = conversation_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
           AND c.status <> 'blocked'
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
         WHERE b.blocked_id = auth.uid()
           AND b.blocker_id IN (
             SELECT CASE WHEN c2.builder_id = auth.uid()
                         THEN c2.trade_id
                         ELSE c2.builder_id END
               FROM public.conversations c2
              WHERE c2.id = conversation_id
           )
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Guard get_or_create_conversation against blocked pairs.
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

  -- Refuse to open/re-open a thread between blocked users.
  IF EXISTS (
    SELECT 1 FROM public.blocks
     WHERE (blocker_id = p_builder AND blocked_id = p_trade)
        OR (blocker_id = p_trade   AND blocked_id = p_builder)
  ) THEN
    RAISE EXCEPTION 'user_blocked';
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
