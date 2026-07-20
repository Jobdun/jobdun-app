-- App Review 5.1.1(v) (rejection 2026-07-15): guests must be able to browse
-- posted jobs without creating an account. Same owner-semantics curated-view
-- pattern as trade_profiles_public / builder_profiles_public (20260611000004):
-- explicit safe columns only, coordinates rounded to 2 dp (~1.1 km) so guest
-- map pins stay approximate, exact address (formatted_address) and place_id
-- withheld — the address surface degrades to "Suburb, STATE".
--
-- deleted_at is projected as constant NULL so the app's shared query shape
-- (`deleted_at=is.null`) works unchanged against both the base table and the
-- view; the WHERE clause already excludes soft-deleted rows.
--
-- search_vector is included so guest search (websearch text search) matches
-- the authenticated feed. RLS on public.jobs is untouched — anon still gets
-- zero rows from the base table; this view is the only anonymous surface.

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
  round(j.latitude::numeric, 2)::double precision  AS latitude,
  round(j.longitude::numeric, 2)::double precision AS longitude,
  NULLIF(
    concat_ws(', ', NULLIF(j.suburb, ''), NULLIF(j.state, '')),
    ''
  )                 AS formatted_address,
  NULL::text        AS place_id,
  NULL::timestamptz AS deleted_at,
  j.search_vector
FROM public.jobs j
WHERE j.status IN ('open', 'filled') AND j.deleted_at IS NULL;

GRANT SELECT ON public.jobs_public_browse TO anon, authenticated;

COMMIT;
