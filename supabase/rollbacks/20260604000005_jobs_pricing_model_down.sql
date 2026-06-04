-- ============================================================
-- DOWN migration for 20260604000005_jobs_pricing_model.sql
-- Supabase migrations are forward-only; run this standalone to reverse
-- (e.g. `supabase db execute --file <this>` or via psql on a scratch DB).
-- Drops only what the up migration added; the legacy budget_min / budget_max /
-- budget_type and proposed_rate / proposed_rate_type columns are left intact.
-- ============================================================

DROP TRIGGER IF EXISTS applications_protect_quote ON public.applications;
DROP FUNCTION IF EXISTS public.applications_protect_quote();

ALTER TABLE public.applications
  DROP CONSTRAINT IF EXISTS applications_quote_amount_positive,
  DROP COLUMN IF EXISTS quote_amount;

ALTER TABLE public.jobs
  DROP CONSTRAINT IF EXISTS jobs_budget_amount_when_set,
  DROP CONSTRAINT IF EXISTS jobs_budget_amount_positive,
  DROP COLUMN IF EXISTS pricing_unit,
  DROP COLUMN IF EXISTS pricing_type,
  DROP COLUMN IF EXISTS budget_amount;

DROP TYPE IF EXISTS public.job_pricing_unit;
DROP TYPE IF EXISTS public.job_pricing_type;
