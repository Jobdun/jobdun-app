-- Down migration for supabase/migrations/20260622000001_jobs_feed_index.sql
-- Drops the jobs feed hot-path partial index. Safe to run repeatedly.
--
-- Per the repo convention (see reference_supabase_down_migration_gotcha): the CLI
-- runs anything under migrations/ FORWARD, so this down script lives in rollbacks/
-- and is applied manually (psql / supabase db query) when reverting.

DROP INDEX IF EXISTS public.jobs_feed_published_idx;
