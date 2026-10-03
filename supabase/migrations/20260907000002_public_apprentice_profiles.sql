-- Apprentice storefronts deserialize from trade_profiles_public, not the base
-- table. Without these fields every public apprentice silently looks like a
-- qualified trade with no site tickets. Append only public identity fields.
-- Keep resume paths private: applicant detail reads the relationship-scoped
-- base row and Storage independently gates document access.
-- Additive, compatible with older clients; retain on an app rollback.

BEGIN;

CREATE OR REPLACE VIEW public.trade_profiles_public AS
SELECT
  tp.id,
  tp.full_name,
  tp.primary_trade,
  tp.trade_other,
  tp.about,
  tp.base_suburb,
  tp.base_state,
  tp.base_postcode,
  round(tp.base_latitude::numeric, 2)::double precision AS base_latitude,
  round(tp.base_longitude::numeric, 2)::double precision AS base_longitude,
  tp.crew_size,
  tp.years_experience,
  tp.service_radius_km,
  tp.portfolio_urls,
  tp.is_verified,
  tp.is_available,
  tp.available_from,
  CASE WHEN tp.hourly_rate_visible THEN tp.hourly_rate_min END AS hourly_rate_min,
  CASE WHEN tp.hourly_rate_visible THEN tp.hourly_rate_max END AS hourly_rate_max,
  tp.hourly_rate_visible,
  tp.average_rating,
  tp.rating_count,
  tp.created_at,
  tp.is_apprentice,
  tp.apprenticeship_stage,
  tp.site_tickets
FROM public.trade_profiles tp
WHERE tp.deleted_at IS NULL;

-- Preserve authenticated access and the existing anonymous-directory ban.
GRANT SELECT ON public.trade_profiles_public TO authenticated;

COMMIT;
