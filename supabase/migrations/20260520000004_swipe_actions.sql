-- ============================================================
-- Migration: Swipe-action backing tables
--
-- Adds the persistence the new UI affordances need (Sprint UI-3
-- from docs/UI_MODERN_AUDIT.md):
--
--   1. conversations.{builder,trade}_{archived_at,muted_until}
--      Per-participant archive + mute state. The conversation row
--      itself stays shared; each side stamps its own column when
--      they swipe.
--
--   2. saved_jobs  — tradies bookmark jobs they want to come back to.
--   3. hidden_jobs — tradies dismiss jobs they're not interested in;
--      hidden rows are filtered out of /jobs feed queries client-side.
--
-- Side-effect: adds a conversations UPDATE policy that the existing
-- mark-read code was already silently relying on. The original
-- 20260511000006_rls.sql migration only declared SELECT + INSERT, so
-- markConversationRead() either no-op'd or fell back to a bypass —
-- either way, archive/mute would have hit the same gap. This migration
-- closes it for everyone.
-- ============================================================

-- ── 1. Conversations: per-side archive + mute state ──────────────
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS trade_archived_at   timestamptz,
  ADD COLUMN IF NOT EXISTS builder_muted_until timestamptz,
  ADD COLUMN IF NOT EXISTS trade_muted_until   timestamptz;

-- Partial indexes so the common filter ("conversations not archived
-- for me") doesn't full-scan. Tradies dominate the read volume; the
-- builder side gets the same treatment for symmetry.
CREATE INDEX IF NOT EXISTS conversations_trade_active_idx
  ON public.conversations (trade_id, last_message_at DESC)
  WHERE trade_archived_at IS NULL;

CREATE INDEX IF NOT EXISTS conversations_builder_active_idx
  ON public.conversations (builder_id, last_message_at DESC)
  WHERE builder_archived_at IS NULL;

-- Backfill the missing UPDATE policy. Participants can update their
-- own conversation row (mark-read, archive, mute). Column-level locks
-- live in the application layer rather than RLS; the alternative is a
-- security-definer function per column which is overkill for v1.
DO $$ BEGIN
  CREATE POLICY "conversations_update_participant"
    ON public.conversations FOR UPDATE
    USING (auth.uid() IN (builder_id, trade_id))
    WITH CHECK (auth.uid() IN (builder_id, trade_id));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2. saved_jobs — tradies bookmark a job ────────────────────────
CREATE TABLE IF NOT EXISTS public.saved_jobs (
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  job_id     uuid        NOT NULL REFERENCES public.jobs(id)     ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (user_id, job_id)
);

CREATE INDEX IF NOT EXISTS saved_jobs_user_id_created_at_idx
  ON public.saved_jobs (user_id, created_at DESC);

ALTER TABLE public.saved_jobs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "saved_jobs_select_own"
    ON public.saved_jobs FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "saved_jobs_insert_own"
    ON public.saved_jobs FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "saved_jobs_delete_own"
    ON public.saved_jobs FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 3. hidden_jobs — tradies dismiss a job ────────────────────────
CREATE TABLE IF NOT EXISTS public.hidden_jobs (
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  job_id     uuid        NOT NULL REFERENCES public.jobs(id)     ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (user_id, job_id)
);

CREATE INDEX IF NOT EXISTS hidden_jobs_user_id_idx
  ON public.hidden_jobs (user_id);

ALTER TABLE public.hidden_jobs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "hidden_jobs_select_own"
    ON public.hidden_jobs FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "hidden_jobs_insert_own"
    ON public.hidden_jobs FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "hidden_jobs_delete_own"
    ON public.hidden_jobs FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
