-- ============================================================
-- Messaging Phase B — photo/file attachments (v1: one image per message)
-- Spec: docs/superpowers/specs/2026-06-08-messaging-phase-b-attachments-design.md
--
-- v1 keeps it simple: one attachment per message, stored as columns on
-- `messages` (matches the locked "1 per message" decision) so it reuses the
-- whole Phase A send/realtime pipeline. A separate message_attachments table is
-- a later step if multi-attach is needed.
-- ============================================================

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS attachment_path text,
  ADD COLUMN IF NOT EXISTS attachment_mime text,
  ADD COLUMN IF NOT EXISTS attachment_w    int,
  ADD COLUMN IF NOT EXISTS attachment_h    int;

-- Allow an empty body when the message carries an attachment (was: non-blank).
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_body_len_chk;
ALTER TABLE public.messages
  ADD CONSTRAINT messages_body_len_chk
  CHECK (
    char_length(body) <= 4000
    AND (char_length(btrim(body)) >= 1 OR attachment_path IS NOT NULL)
  ) NOT VALID;

-- Private bucket (10 MB cap, image + PDF), created idempotently.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments', 'chat-attachments', false, 10485760,
  ARRAY['image/jpeg','image/png','image/webp','image/heic','application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: only the two participants of the conversation in the first path
-- segment (`<conversation_id>/<file>`) can read or write its objects.
DO $$ BEGIN
  CREATE POLICY "chat_attach_read" ON storage.objects FOR SELECT
    USING (
      bucket_id = 'chat-attachments'
      AND EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id::text = (storage.foldername(name))[1]
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "chat_attach_write" ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'chat-attachments'
      AND EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id::text = (storage.foldername(name))[1]
          AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
