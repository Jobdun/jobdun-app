-- P1 (BACKEND_FULL_AUDIT_2026-06-11): close F-RLS-03 — the blanket
-- authenticated SELECT on trade_profiles / builder_profiles exposed every
-- column of every profile (legal names, exact home-base lat/lng, builder
-- phone, rates even when hidden) to any signed-in account.
--
-- Visibility model ("front of card / back of card"):
--   • PUBLIC (any authenticated user) → curated projection views
--     `trade_profiles_public` / `builder_profiles_public`: marketplace
--     storefront fields only. Coordinates rounded to 2 dp (~1.1 km) so map
--     pins work without disclosing a home address; rates NULLed when the
--     owner set hourly_rate_visible = false.
--   • RELATIONSHIP (an application / conversation / booking / quote request
--     between the two parties) → full row via relationship-scoped SELECT
--     policies on the base tables. Existing reads in the app that rely on
--     this (applicant detail, quote inbox) keep working unchanged.
--   • Discovery → `search_trades` becomes SECURITY DEFINER (it can no longer
--     piggyback on a blanket SELECT) and now sanitises its output: exact
--     coordinates rounded, place_id / formatted_address / licence_url
--     removed, rates gated by visibility. Distance filtering still uses the
--     true coordinates internally, so search quality is unchanged.
--
-- Views use owner (postgres) semantics deliberately — same pattern as
-- trade_public_credentials — so they can project over the now-locked tables.

BEGIN;

-- ── Public projections ────────────────────────────────────────────────────
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
  round(tp.base_latitude::numeric, 2)::double precision  AS base_latitude,
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
  tp.created_at
FROM public.trade_profiles tp
WHERE tp.deleted_at IS NULL;

CREATE OR REPLACE VIEW public.builder_profiles_public AS
SELECT
  bp.id,
  bp.company_name,
  bp.abn,            -- ABNs are public information in Australia (ABR lookup)
  bp.about,
  bp.website,
  bp.years_in_business,
  bp.service_suburb,
  bp.service_state,
  bp.service_postcode,
  round(bp.service_latitude::numeric, 2)::double precision  AS service_latitude,
  round(bp.service_longitude::numeric, 2)::double precision AS service_longitude,
  bp.average_rating,
  bp.rating_count,
  bp.created_at
FROM public.builder_profiles bp
WHERE bp.deleted_at IS NULL;

GRANT SELECT ON public.trade_profiles_public   TO authenticated;
GRANT SELECT ON public.builder_profiles_public TO authenticated;

-- ── Base tables: blanket SELECT → own + relationship ──────────────────────
-- (admin read policies are separate and untouched; the relationship tables'
-- own policies are party-scoped on builder_id/trade_id directly, so these
-- EXISTS subqueries cannot recurse back into profile policies.)
DROP POLICY IF EXISTS trade_profiles_select_authenticated ON public.trade_profiles;
CREATE POLICY trade_profiles_select_related ON public.trade_profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR EXISTS (SELECT 1 FROM public.applications a
                WHERE a.trade_id = trade_profiles.id AND a.builder_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.conversations c
                WHERE c.trade_id = trade_profiles.id AND c.builder_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.bookings b
                WHERE b.trade_id = trade_profiles.id AND b.builder_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.quote_requests q
                WHERE q.trade_id = trade_profiles.id AND q.builder_id = auth.uid())
  );

DROP POLICY IF EXISTS builder_profiles_select_authenticated ON public.builder_profiles;
CREATE POLICY builder_profiles_select_related ON public.builder_profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR EXISTS (SELECT 1 FROM public.applications a
                WHERE a.builder_id = builder_profiles.id AND a.trade_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.conversations c
                WHERE c.builder_id = builder_profiles.id AND c.trade_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.bookings b
                WHERE b.builder_id = builder_profiles.id AND b.trade_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.quote_requests q
                WHERE q.builder_id = builder_profiles.id AND q.trade_id = auth.uid())
  );

-- ── search_trades: definer + sanitised projection ─────────────────────────
-- Same signature (app model parses unchanged). Inner query keeps true
-- coordinates for the bounding box + haversine; only the RETURNED values
-- are sanitised.
CREATE OR REPLACE FUNCTION public.search_trades(
  p_lat double precision, p_lng double precision, p_radius_km integer,
  p_min_rating numeric DEFAULT NULL::numeric,
  p_available_only boolean DEFAULT false,
  p_query text DEFAULT NULL::text,
  p_limit integer DEFAULT 20, p_offset integer DEFAULT 0
) RETURNS TABLE(
  id uuid, full_name text, primary_trade text, crew_size integer,
  years_experience integer, hourly_rate_min numeric, hourly_rate_max numeric,
  hourly_rate_visible boolean, service_radius_km integer,
  base_suburb text, base_state text, base_postcode text,
  base_formatted_address text, base_place_id text,
  base_latitude double precision, base_longitude double precision,
  about text, trade_other text, licence_url text, portfolio_urls text[],
  is_verified boolean, average_rating numeric, rating_count integer,
  is_available boolean, available_from date, distance_km double precision
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    sub.id, sub.full_name, sub.primary_trade, sub.crew_size,
    sub.years_experience,
    CASE WHEN sub.hourly_rate_visible THEN sub.hourly_rate_min END,
    CASE WHEN sub.hourly_rate_visible THEN sub.hourly_rate_max END,
    sub.hourly_rate_visible, sub.service_radius_km,
    sub.base_suburb, sub.base_state, sub.base_postcode,
    NULL::text,  -- base_formatted_address: exact address never leaves the DB
    NULL::text,  -- base_place_id
    round(sub.base_latitude::numeric, 2)::double precision,
    round(sub.base_longitude::numeric, 2)::double precision,
    sub.about, sub.trade_other,
    NULL::text,  -- licence_url: private-docs pointer; badge = is_verified
    sub.portfolio_urls, sub.is_verified,
    sub.average_rating, sub.rating_count,
    sub.is_available, sub.available_from, sub.distance_km
  FROM (
    SELECT
      tp.*,
      (6371 * acos(least(1.0, greatest(-1.0,
        cos(radians(p_lat)) * cos(radians(tp.base_latitude)) *
        cos(radians(tp.base_longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(tp.base_latitude))
      )))) AS distance_km
    FROM public.trade_profiles tp
    WHERE tp.deleted_at IS NULL
      AND tp.base_latitude  IS NOT NULL
      AND tp.base_longitude IS NOT NULL
      AND tp.base_latitude  BETWEEN
            (p_lat - (p_radius_km / 111.0)) AND (p_lat + (p_radius_km / 111.0))
      AND tp.base_longitude BETWEEN
            (p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))) AND
            (p_lng + (p_radius_km / (111.0 * cos(radians(p_lat)))))
      AND (NOT p_available_only
           OR tp.is_available = true
           OR tp.available_from <= current_date)
      AND (p_min_rating IS NULL OR tp.average_rating >= p_min_rating)
      AND (p_query IS NULL OR p_query = ''
           OR tp.full_name     ILIKE '%' || p_query || '%'
           OR tp.primary_trade ILIKE '%' || p_query || '%'
           OR COALESCE(tp.trade_other, '') ILIKE '%' || p_query || '%')
  ) sub
  WHERE sub.distance_km <= p_radius_km
  ORDER BY sub.distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$;

COMMIT;
