-- Phase D (messaging inbox safety) CP-1, spec: docs/superpowers/specs/2026-06-08-messaging-phase-d-inbox-safety-design.md §Migration 1
-- (re-stamped from the plan's 20260608000002 — that slot was taken by message_reactions)
-- Per-side pin + permanent mute toggle for conversations.
-- Mirrors the existing builder_archived_at / trade_archived_at pattern.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_pinned_at  timestamptz,
  ADD COLUMN IF NOT EXISTS trade_pinned_at    timestamptz,
  ADD COLUMN IF NOT EXISTS builder_muted_at   timestamptz,
  ADD COLUMN IF NOT EXISTS trade_muted_at     timestamptz;

-- Partial index: pinned conversations for each side (small set, fast lookup).
CREATE INDEX IF NOT EXISTS conversations_builder_pinned_idx
  ON public.conversations (builder_id, builder_pinned_at DESC)
  WHERE builder_pinned_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS conversations_trade_pinned_idx
  ON public.conversations (trade_id, trade_pinned_at DESC)
  WHERE trade_pinned_at IS NOT NULL;

-- The existing conversations_update_participant policy (added in
-- 20260520000004_swipe_actions.sql) already covers UPDATE for participants;
-- no new policy needed for these columns.
