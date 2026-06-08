-- Rollback for 20260608000003_message_reactions.sql
-- Apply manually: psql "$SUPABASE_DB_URL" -f this_file

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.message_reactions;
EXCEPTION WHEN undefined_object THEN NULL; END $$;

DROP TABLE IF EXISTS public.message_reactions;
