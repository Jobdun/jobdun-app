-- Down for 20260831000004_search_trades_apprentices.sql
--
-- Restores the 8-arg signature from 20260611000004_pii_visibility_split.sql
-- verbatim, then re-applies the F3 anon revoke (20260703000002) because a fresh
-- CREATE FUNCTION grants EXECUTE to PUBLIC by default.

BEGIN;

DROP FUNCTION IF EXISTS public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer, boolean
);

CREATE FUNCTION public.search_trades(
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
    NULL::text, NULL::text,
    round(sub.base_latitude::numeric, 2)::double precision,
    round(sub.base_longitude::numeric, 2)::double precision,
    sub.about, sub.trade_other,
    NULL::text,
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

REVOKE ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer
) FROM anon;
GRANT EXECUTE ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer
) TO authenticated;

COMMIT;
