-- ============================================================
-- Migration 2: Jobs table
-- Columns derived from lib/features/jobs/data/models/job_model.dart
-- and lib/features/jobs/domain/entities/job.dart
-- ============================================================

-- Enums matching Dart entity values exactly
DO $$ BEGIN
  CREATE TYPE public.job_status AS ENUM ('draft', 'open', 'filled', 'closed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.job_urgency AS ENUM ('standard', 'urgent');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.budget_type AS ENUM ('hourly', 'daily', 'fixed', 'negotiable');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.jobs (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  builder_id               uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- core listing
  title                    text NOT NULL,
  description              text NOT NULL,
  trade_type_required      text NOT NULL DEFAULT '',
  status                   public.job_status NOT NULL DEFAULT 'draft',

  -- location (suburb/state/postcode used for display; lat/lng for map pins)
  suburb                   text NOT NULL DEFAULT '',
  state                    text NOT NULL DEFAULT '',
  postcode                 text NOT NULL DEFAULT '',
  latitude                 double precision,
  longitude                double precision,

  -- budget
  budget_min               numeric(10, 2),
  budget_max               numeric(10, 2),
  budget_type              public.budget_type,

  -- scheduling
  urgency                  public.job_urgency NOT NULL DEFAULT 'standard',
  start_date               date,
  estimated_duration_days  int,
  duration_text            text,

  -- requirements
  requires_white_card      boolean NOT NULL DEFAULT false,
  requires_public_liability boolean NOT NULL DEFAULT true,
  requires_verified        boolean NOT NULL DEFAULT true,
  required_certifications  text[] NOT NULL DEFAULT '{}',

  -- counters (maintained by triggers / edge functions)
  application_count        int NOT NULL DEFAULT 0,
  view_count               int NOT NULL DEFAULT 0,

  -- lifecycle
  published_at             timestamptz,
  hired_trade_id           uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  deleted_at               timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS jobs_builder_id_idx ON public.jobs(builder_id);
CREATE INDEX IF NOT EXISTS jobs_status_idx ON public.jobs(status);
CREATE INDEX IF NOT EXISTS jobs_trade_type_idx ON public.jobs(trade_type_required);

DROP TRIGGER IF EXISTS jobs_updated_at ON public.jobs;
CREATE TRIGGER jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
