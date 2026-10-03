-- The mobile feed uses the same projection for jobs and jobs_public_browse.
-- Adding open_to_apprentices to jobs did not update this explicit view, so
-- anonymous browsing failed with 42703 after the apprentice app update.
--
-- Append only the invitation boolean. Preserve the curated projection,
-- approximate coordinates, withheld place ID, published-status filter,
-- ownership semantics, and existing grants. Do not replace this with j.*.
-- CREATE OR REPLACE preserves view grants and requires new columns at the end.
-- Additive and compatible with older app versions: retain on an app rollback.

BEGIN;

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
  j.open_to_apprentices
FROM public.jobs j
WHERE j.status IN ('open', 'filled') AND j.deleted_at IS NULL;

GRANT SELECT ON public.jobs_public_browse TO anon, authenticated;

COMMIT;
