-- ============================================================
-- Messaging Phase A — client_tag for optimistic send + idempotent retries
-- Spec: docs/superpowers/specs/2026-06-08-messaging-reliability-core-design.md
--
-- The client generates a UUID per message (client_tag) and sends it with the
-- insert. This lets the optimistic local bubble be reconciled with the realtime
-- echo (dedup by client_tag, not by server id), and makes a re-send after a
-- failure idempotent via upsert(..., ignoreDuplicates: true).
-- ============================================================

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_tag uuid;

-- NON-partial unique index on purpose: Postgres treats NULLs as distinct, so
-- pre-existing rows (client_tag IS NULL) and any future server-only inserts are
-- unconstrained, while two inserts sharing a client_tag in the same conversation
-- collide. A non-partial index is also required so PostgREST upsert can use it as
-- the ON CONFLICT arbiter (a partial index can't be targeted via on_conflict).
CREATE UNIQUE INDEX IF NOT EXISTS messages_conv_client_tag_uidx
  ON public.messages (conversation_id, client_tag);
