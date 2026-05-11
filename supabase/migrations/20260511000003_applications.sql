-- ============================================================
-- Migration 3: Job applications table
-- Columns derived from lib/features/applications/data/models/job_application_model.dart
-- and lib/features/applications/domain/entities/job_application.dart
-- ============================================================

-- Enum values match ApplicationStatus.dbValue in job_application.dart exactly
CREATE TYPE public.application_status AS ENUM (
  'pending',
  'shortlisted',
  'rejected',
  'withdrawn',
  'hired',
  'declined_by_trade'   -- maps to ApplicationStatus.declinedByTrade
);

CREATE TABLE IF NOT EXISTS public.applications (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id              uuid NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  trade_id            uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  builder_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status              public.application_status NOT NULL DEFAULT 'pending',

  -- applicant-submitted fields
  cover_note          text,
  proposed_rate       numeric(10, 2),
  proposed_rate_type  text,           -- 'hourly' | 'daily' | 'fixed'
  available_from      date,

  -- builder-written fields
  rejection_reason    text,

  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  -- one application per trade per job
  UNIQUE (job_id, trade_id)
);

CREATE INDEX applications_job_id_idx ON public.applications(job_id);
CREATE INDEX applications_trade_id_idx ON public.applications(trade_id);
CREATE INDEX applications_builder_id_idx ON public.applications(builder_id);

CREATE TRIGGER applications_updated_at
  BEFORE UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
