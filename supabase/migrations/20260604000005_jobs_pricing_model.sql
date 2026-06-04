-- ============================================================
-- Jobs pricing/quoting data model (negotiation anchor — NOT a transaction).
-- Price on Jobdun is a negotiation anchor only: no escrow, no commission,
-- Jobdun never touches money.
--
-- Adds:
--   jobs.pricing_unit   enum  hourly | sqm | lm | per_job   (always set)
--   jobs.pricing_type   enum  builder_set | request_quote   (always set)
--   jobs.budget_amount  numeric  (builder's rate when builder_set; null when request_quote)
--   applications.quote_amount  numeric  (tradie's price in the job's unit; NEVER updates jobs)
--
-- Additive + reversible (see 20260604000005_jobs_pricing_model_down.sql).
-- Backfill is included so a replay on a populated environment is safe; the
-- mobile app is pre-launch (no real data) at time of writing.
-- ============================================================

-- ---- enums (idempotent, repo pattern) ----
DO $$ BEGIN
  CREATE TYPE public.job_pricing_unit AS ENUM ('hourly','sqm','lm','per_job');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.job_pricing_type AS ENUM ('builder_set','request_quote');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---- jobs columns (nullable first so the backfill can populate them) ----
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS pricing_unit  public.job_pricing_unit,
  ADD COLUMN IF NOT EXISTS pricing_type  public.job_pricing_type,
  ADD COLUMN IF NOT EXISTS budget_amount numeric(10, 2);

-- ---- backfill existing rows ----
-- Old data has no unit -> per_job. A row with an existing price is builder_set
-- (budget_amount = that price); a priceless row becomes request_quote.
UPDATE public.jobs SET
  pricing_unit  = COALESCE(pricing_unit, 'per_job'),
  budget_amount = COALESCE(budget_amount, budget_min),
  pricing_type  = COALESCE(
    pricing_type,
    CASE WHEN budget_min IS NOT NULL
         THEN 'builder_set'::public.job_pricing_type
         ELSE 'request_quote'::public.job_pricing_type END);

-- ---- enforce "always set" + defaults ----
ALTER TABLE public.jobs
  ALTER COLUMN pricing_unit SET DEFAULT 'per_job',
  ALTER COLUMN pricing_unit SET NOT NULL,
  ALTER COLUMN pricing_type SET DEFAULT 'builder_set',
  ALTER COLUMN pricing_type SET NOT NULL;

-- ---- CHECK constraints (the agreed conditional + non-negative) ----
DO $$ BEGIN
  ALTER TABLE public.jobs ADD CONSTRAINT jobs_budget_amount_when_set CHECK (
    (pricing_type = 'builder_set' AND budget_amount IS NOT NULL)
    OR (pricing_type = 'request_quote'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.jobs ADD CONSTRAINT jobs_budget_amount_positive CHECK (
    budget_amount IS NULL OR budget_amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---- applications.quote_amount ----
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS quote_amount numeric(10, 2);

UPDATE public.applications
  SET quote_amount = COALESCE(quote_amount, proposed_rate)
  WHERE proposed_rate IS NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.applications ADD CONSTRAINT applications_quote_amount_positive CHECK (
    quote_amount IS NULL OR quote_amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---- guard: only the applicant (trade) may set/alter quote_amount ----
-- RLS applications_update lets either party UPDATE the row (builder shortlists/
-- hires; trade withdraws). This BEFORE UPDATE trigger keeps the *number* itself
-- tradie-owned so a builder can never edit the quote. SECURITY: relies on
-- auth.uid(); writes from service_role (auth.uid() IS NULL) are intentionally
-- not blocked (admin/back-office path).
CREATE OR REPLACE FUNCTION public.applications_protect_quote()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.quote_amount IS DISTINCT FROM OLD.quote_amount
     AND auth.uid() IS NOT NULL
     AND auth.uid() <> OLD.trade_id THEN
    RAISE EXCEPTION 'quote_amount can only be changed by the applicant';
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS applications_protect_quote ON public.applications;
CREATE TRIGGER applications_protect_quote
  BEFORE UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.applications_protect_quote();
