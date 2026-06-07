-- Rollback for 20260608000002_messaging_guardrails.sql
-- Apply manually: psql "$SUPABASE_DB_URL" -f this_file

ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_body_len_chk;

-- Restore the original (insecure) read-update policy.
DO $$ BEGIN
  CREATE POLICY "messages_update_read"
    ON public.messages FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
