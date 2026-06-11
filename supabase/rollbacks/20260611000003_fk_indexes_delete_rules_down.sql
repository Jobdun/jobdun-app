-- DOWN for 20260611000003_fk_indexes_delete_rules.sql. Run manually only.

BEGIN;

DROP INDEX IF EXISTS public.idx_saved_jobs_job_id;
DROP INDEX IF EXISTS public.idx_hidden_jobs_job_id;
DROP INDEX IF EXISTS public.idx_bookings_job_id;
DROP INDEX IF EXISTS public.idx_jobs_hired_trade_id;
DROP INDEX IF EXISTS public.idx_timesheets_builder_id;
DROP INDEX IF EXISTS public.idx_reviews_reviewer_id;
DROP INDEX IF EXISTS public.idx_mvr_user_id;
DROP INDEX IF EXISTS public.idx_mvr_verification_id;
DROP INDEX IF EXISTS public.idx_mvr_resolved_by;
DROP INDEX IF EXISTS public.idx_verification_events_actor;
DROP INDEX IF EXISTS public.idx_vfe_user_id;
DROP INDEX IF EXISTS public.idx_ure_changed_by;
DROP INDEX IF EXISTS public.idx_vd_reviewed_by;
DROP INDEX IF EXISTS public.idx_conversations_last_sender;
DROP INDEX IF EXISTS public.idx_message_reactions_user;

ALTER TABLE public.manual_verification_requests
  DROP CONSTRAINT manual_verification_requests_resolved_by_fkey,
  ADD CONSTRAINT manual_verification_requests_resolved_by_fkey
    FOREIGN KEY (resolved_by) REFERENCES public.profiles(id);

ALTER TABLE public.verification_events
  DROP CONSTRAINT verification_events_actor_id_fkey,
  ADD CONSTRAINT verification_events_actor_id_fkey
    FOREIGN KEY (actor_id) REFERENCES public.profiles(id);

ALTER TABLE public.user_role_events
  DROP CONSTRAINT user_role_events_changed_by_fkey,
  ADD CONSTRAINT user_role_events_changed_by_fkey
    FOREIGN KEY (changed_by) REFERENCES auth.users(id);

COMMIT;
