-- Phase D hardening: rules + guardrails for block/report (2026-06-12 review).
--
-- 1) Self-targeting is meaningless — reject at the schema.
-- 2) Reports must come from a participant of the reported conversation
--    (defence-in-depth; conversation ids are unguessable uuids, but the
--    policy should not rely on that).
-- 3) One PENDING report per (reporter, conversation): resolves admin-queue
--    flooding. Re-reporting becomes possible again once the first report is
--    reviewed/actioned/dismissed.
--
-- Reviewed-and-accepted non-issue: a blocked participant can cosmetically
-- flip conversations.status back to 'active' (participant UPDATE policy is
-- column-unrestricted). Enforcement does NOT live in that column — the
-- `blocks` table drives the send-guard and the get_or_create guard, both
-- SECURITY-DEFINER/RLS-side — so a status flip changes nothing real.

BEGIN;

-- ── 1. No self-targeting ──────────────────────────────────────────────────
ALTER TABLE public.blocks
  ADD CONSTRAINT blocks_no_self_block CHECK (blocker_id <> blocked_id);

ALTER TABLE public.reports
  ADD CONSTRAINT reports_no_self_report CHECK (reporter_id <> reported_id);

-- ── 2. Reports only from conversation participants ────────────────────────
DROP POLICY IF EXISTS "reports_insert_own" ON public.reports;
CREATE POLICY "reports_insert_own" ON public.reports FOR INSERT
  WITH CHECK (
    auth.uid() = reporter_id
    AND EXISTS (
      SELECT 1 FROM public.conversations c
       WHERE c.id = conversation_id
         AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

-- ── 3. One pending report per reporter+conversation ───────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS reports_one_pending_per_conversation
  ON public.reports (reporter_id, conversation_id)
  WHERE status = 'pending';

COMMIT;
