-- Jobs feed hot-path index.
--
-- Supports the default feed query served by JobRemoteDataSourceImpl.getJobs()
-- (lib/features/jobs/data/datasources/job_remote_datasource.dart) and the
-- cache-miss path of the jobs-feed Edge Function:
--
--   SELECT <feedColumns> FROM jobs
--   WHERE status IN ('open','filled') AND deleted_at IS NULL
--   ORDER BY published_at DESC
--   LIMIT 20;
--
-- Before this index the planner used the single-column jobs_status_idx to filter,
-- then performed an in-memory sort on published_at. A partial index on
-- published_at DESC whose predicate matches the feed's WHERE clause lets Postgres
-- return the page from one pre-sorted index scan (no Sort node). Only open/filled,
-- non-deleted rows are indexed, keeping it small (drafts/closed/deleted excluded).
--
-- NOTE: plain (transactional) CREATE INDEX — the jobs table is small today. If the
-- production jobs table grows large, re-issue this as a SEPARATE, non-transactional
-- migration using CREATE INDEX CONCURRENTLY to avoid holding a write lock on jobs.
--
-- Rollback: supabase/rollbacks/20260622000001_jobs_feed_index_down.sql

CREATE INDEX IF NOT EXISTS jobs_feed_published_idx
  ON public.jobs (published_at DESC)
  WHERE deleted_at IS NULL AND status IN ('open', 'filled');
