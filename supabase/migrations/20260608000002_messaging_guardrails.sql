-- ============================================================
-- Messaging guardrails — security fix + text bounds
-- Spec: docs/superpowers/specs/2026-06-08-messaging-* (program guardrails)
-- ============================================================

-- 1) SECURITY FIX. `messages_update_read` granted UPDATE on messages to EITHER
--    participant with no WITH CHECK clause, so it defaulted to its USING clause —
--    letting a user edit or soft-delete the COUNTERPARTY's messages via the API.
--    Drop it. `messages_modify_own` (sender-only USING + WITH CHECK, added in
--    20260516000001_schema_reconciliation.sql) already covers every legitimate
--    sender-side update (future unsend/edit). No app path updates messages rows
--    cross-party (read receipts are conversation-level), so this only removes the
--    hole.
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;

-- 2) TEXT GUARDRAIL. Bound the message body: ≤ 4000 chars and non-blank after
--    trim. NOT VALID so it enforces on new inserts/updates without scanning (or
--    failing on) pre-existing rows — safe to apply to a live table.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.messages'::regclass
      AND conname = 'messages_body_len_chk'
  ) THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_body_len_chk
      CHECK (char_length(body) <= 4000 AND char_length(btrim(body)) >= 1)
      NOT VALID;
  END IF;
END $$;
