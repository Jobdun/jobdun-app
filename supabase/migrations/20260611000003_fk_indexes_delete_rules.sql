-- M2 (BACKEND_FULL_AUDIT_2026-06-11 · P1/P2): pure-DDL scale + integrity fixes.
--
-- 1) 15 foreign-key columns had no covering index (verified against the live
--    dump): seq-scan joins on hot paths (feed save/hide filters, schedule
--    views, timesheet lists, review uniqueness) and lock amplification on
--    parent-row deletes.
-- 2) Three FKs had no ON DELETE rule (NO ACTION), so `delete_my_account`'s
--    `DELETE FROM auth.users` cascade fails for any account that ever acted
--    as an admin/resolver. SET NULL keeps the audit row, unblocks deletion.

BEGIN;

-- ── FK covering indexes — hot paths ───────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_saved_jobs_job_id        ON public.saved_jobs (job_id);
CREATE INDEX IF NOT EXISTS idx_hidden_jobs_job_id       ON public.hidden_jobs (job_id);
CREATE INDEX IF NOT EXISTS idx_bookings_job_id          ON public.bookings (job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_hired_trade_id      ON public.jobs (hired_trade_id);
CREATE INDEX IF NOT EXISTS idx_timesheets_builder_id    ON public.timesheets (builder_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id      ON public.reviews (reviewer_id);

-- ── FK covering indexes — audit / admin paths (cheap, keeps deletes fast) ─
CREATE INDEX IF NOT EXISTS idx_mvr_user_id              ON public.manual_verification_requests (user_id);
CREATE INDEX IF NOT EXISTS idx_mvr_verification_id      ON public.manual_verification_requests (verification_id);
CREATE INDEX IF NOT EXISTS idx_mvr_resolved_by          ON public.manual_verification_requests (resolved_by);
CREATE INDEX IF NOT EXISTS idx_verification_events_actor ON public.verification_events (actor_id);
CREATE INDEX IF NOT EXISTS idx_vfe_user_id              ON public.verification_funnel_events (user_id);
CREATE INDEX IF NOT EXISTS idx_ure_changed_by           ON public.user_role_events (changed_by);
CREATE INDEX IF NOT EXISTS idx_vd_reviewed_by           ON public.verification_documents (reviewed_by);
CREATE INDEX IF NOT EXISTS idx_conversations_last_sender ON public.conversations (last_message_sender_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user   ON public.message_reactions (user_id);

-- ── NO ACTION → SET NULL on audit-actor FKs ───────────────────────────────
ALTER TABLE public.manual_verification_requests
  DROP CONSTRAINT manual_verification_requests_resolved_by_fkey,
  ADD CONSTRAINT manual_verification_requests_resolved_by_fkey
    FOREIGN KEY (resolved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.verification_events
  DROP CONSTRAINT verification_events_actor_id_fkey,
  ADD CONSTRAINT verification_events_actor_id_fkey
    FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.user_role_events
  DROP CONSTRAINT user_role_events_changed_by_fkey,
  ADD CONSTRAINT user_role_events_changed_by_fkey
    FOREIGN KEY (changed_by) REFERENCES auth.users(id) ON DELETE SET NULL;

COMMIT;
