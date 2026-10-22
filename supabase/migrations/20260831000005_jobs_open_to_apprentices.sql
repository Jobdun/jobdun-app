-- supabase/migrations/20260831000005_jobs_open_to_apprentices.sql
--
-- "Open to apprentices" is an INVITATION SIGNAL, not a gate waiver.
--
-- requires_verified and requires_public_liability are stored and rendered on
-- the job card but never enforced at apply time (verified 2026-08-30: no
-- apply-path check exists anywhere in lib/features/applications or
-- lib/features/jobs/presentation -- the columns are read by JobModel and
-- displayed, and that is all). There is no gate to waive.
--
-- So this flag drives an OPEN TO APPRENTICES chip on the job card and an
-- apprentice-side feed filter. It gates nothing, which matches the platform's
-- stated posture: trust signals, never gates
-- (see 20260610000006_trade_public_credentials.sql).
--
-- Reversibility: SAFE -- additive column with a default.
-- Down: supabase/rollbacks/20260831000005_jobs_open_to_apprentices_down.sql

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS open_to_apprentices boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.jobs.open_to_apprentices IS
  'Builder invites apprentice applicants. Drives a job-card chip and an '
  'apprentice-side filter -- it gates nothing.';
