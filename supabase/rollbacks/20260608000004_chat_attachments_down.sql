-- Rollback for 20260608000004_chat_attachments.sql
-- Apply manually: psql "$SUPABASE_DB_URL" -f this_file

DROP POLICY IF EXISTS "chat_attach_read"  ON storage.objects;
DROP POLICY IF EXISTS "chat_attach_write" ON storage.objects;
DELETE FROM storage.buckets WHERE id = 'chat-attachments';

ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_body_len_chk;
ALTER TABLE public.messages
  ADD CONSTRAINT messages_body_len_chk
  CHECK (char_length(body) <= 4000 AND char_length(btrim(body)) >= 1) NOT VALID;

ALTER TABLE public.messages
  DROP COLUMN IF EXISTS attachment_path,
  DROP COLUMN IF EXISTS attachment_mime,
  DROP COLUMN IF EXISTS attachment_w,
  DROP COLUMN IF EXISTS attachment_h;
