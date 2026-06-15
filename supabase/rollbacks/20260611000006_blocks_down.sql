-- DOWN for 20260611000006. Run manually only. Restores the pre-block
-- messages_insert policy (from 20260603000001) and get_or_create_conversation
-- (same file) — bodies preserved here verbatim from the 2026-06-11 live dump.
DROP TABLE IF EXISTS public.blocks CASCADE;
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
CREATE POLICY "messages_insert" ON public.messages FOR INSERT
  WITH CHECK ((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
    FROM public.conversations c
    WHERE c.id = messages.conversation_id
      AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid()))));
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  p_builder uuid, p_trade uuid, p_job uuid DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
