-- Rollback for 20260720000001_jobs_public_browse.sql
-- Removes the anonymous job-browsing surface. RLS on public.jobs was never
-- changed, so dropping the view fully restores the pre-migration exposure.
DROP VIEW IF EXISTS public.jobs_public_browse;
