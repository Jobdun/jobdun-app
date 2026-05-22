-- Sprint W3-followups — Soft delete on profile tables
--
-- Adds a nullable `deleted_at timestamptz` column to builder_profiles and
-- trade_profiles. Mirrors the pattern already in use on jobs, messages, and
-- verification_documents — rows are filtered with `is(deleted_at, null)` in
-- the data layer rather than physically removed, so referential history is
-- preserved (a deleted tradie's old job_applications still resolve).
--
-- Reversibility: SAFE. Columns are NULL-able and default to NULL. ALTER TABLE
-- DROP COLUMN restores the previous shape without data loss.
--
-- Verification:
--   supabase db push
--   psql "$SUPABASE_DB_URL" -c "\d public.builder_profiles" -- shows deleted_at
--   psql "$SUPABASE_DB_URL" -c "\d public.trade_profiles"   -- shows deleted_at

ALTER TABLE public.builder_profiles
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Partial indexes for the common "active rows only" query path. PostgreSQL
-- uses these when `WHERE deleted_at IS NULL` is in the filter — the index
-- only stores rows where deleted_at IS NULL, so it's small + fast.
CREATE INDEX IF NOT EXISTS idx_builder_profiles_active
  ON public.builder_profiles (id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_trade_profiles_active
  ON public.trade_profiles (id) WHERE deleted_at IS NULL;
