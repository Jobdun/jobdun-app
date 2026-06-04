-- =============================================================================
-- backfill_published_at.sql — fix existing open/filled jobs missing published_at
-- =============================================================================
-- Jobs created before the create-path published_at fix have published_at = NULL,
-- so the feed's `ORDER BY published_at DESC` can't sort them. This stamps them
-- with their created_at (preserving original chronology). Run once in the
-- Supabase SQL Editor (service-role).
-- =============================================================================

-- 1. How many rows are affected?
select count(*) as null_published
from public.jobs
where published_at is null
  and status in ('open', 'filled')
  and deleted_at is null;

-- 2. Backfill (idempotent — only touches NULL rows).
update public.jobs
   set published_at = created_at
 where published_at is null
   and status in ('open', 'filled')
   and deleted_at is null;

-- 3. Confirm none remain.
select count(*) as still_null
from public.jobs
where published_at is null
  and status in ('open', 'filled')
  and deleted_at is null;
