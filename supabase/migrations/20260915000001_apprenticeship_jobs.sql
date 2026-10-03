-- Dedicated apprenticeship vacancies. Additive: old apps retain trade_job defaults.
BEGIN;
ALTER TABLE public.jobs ADD COLUMN job_kind text NOT NULL DEFAULT 'trade_job';
ALTER TABLE public.jobs ADD CONSTRAINT jobs_kind_valid
  CHECK (job_kind IN ('trade_job', 'apprenticeship'));
ALTER TABLE public.jobs ADD CONSTRAINT jobs_apprenticeship_terms
  CHECK (job_kind <> 'apprenticeship' OR (
    open_to_apprentices AND pricing_type = 'builder_set' AND pricing_unit = 'hourly'
    AND budget_amount IS NOT NULL AND budget_amount > 0
    AND budget_amount < 'Infinity'::numeric
  ));
CREATE INDEX jobs_apprenticeship_feed_idx ON public.jobs (published_at DESC)
  WHERE job_kind = 'apprenticeship' AND deleted_at IS NULL;
CREATE INDEX jobs_apprentice_invitation_feed_idx ON public.jobs (published_at DESC)
  WHERE open_to_apprentices AND deleted_at IS NULL;
CREATE OR REPLACE VIEW public.jobs_public_browse AS
SELECT
  j.id,
  j.builder_id,
  j.title,
  j.description,
  j.suburb,
  j.state,
  j.postcode,
  j.trade_type_required,
  j.budget_amount,
  j.pricing_unit,
  j.pricing_type,
  j.urgency,
  j.requires_verified,
  j.requires_white_card,
  j.requires_public_liability,
  j.required_certifications,
  j.start_date,
  j.estimated_duration_days,
  j.duration_text,
  j.application_count,
  j.view_count,
  j.status,
  j.published_at,
  j.created_at,
  j.updated_at,
  round(j.latitude::numeric, 2)::double precision AS latitude,
  round(j.longitude::numeric, 2)::double precision AS longitude,
  NULLIF(
    concat_ws(', ', NULLIF(j.suburb, ''), NULLIF(j.state, '')),
    ''
  ) AS formatted_address,
  NULL::text AS place_id,
  NULL::timestamptz AS deleted_at,
  j.search_vector,
  j.open_to_apprentices,
  j.job_kind
FROM public.jobs j
WHERE j.status IN ('open', 'filled') AND j.deleted_at IS NULL;

GRANT SELECT ON public.jobs_public_browse TO anon, authenticated;


COMMIT;
