-- Rollback for 20260608000001_message_client_tag.sql
-- Kept here (not in migrations/) so the CLI does not run it forward.
-- Apply manually: psql "$SUPABASE_DB_URL" -f this_file

DROP INDEX IF EXISTS public.messages_conv_client_tag_uidx;
ALTER TABLE public.messages DROP COLUMN IF EXISTS client_tag;
