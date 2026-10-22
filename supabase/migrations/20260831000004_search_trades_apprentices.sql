-- supabase/migrations/20260831000004_search_trades_apprentices.sql
--
-- Adds apprentice filtering + projection to search_trades so Discovery can
-- offer a TRADES / APPRENTICES toggle.
--
-- DROP + CREATE, not CREATE OR REPLACE: Postgres refuses to replace a function
-- whose RETURNS TABLE shape changes, and this adds three columns.
--
-- ⚠ SECURITY -- the reason this migration is longer than it looks.
-- A fresh CREATE FUNCTION grants EXECUTE to PUBLIC by default, and PUBLIC
-- includes anon. 20260703000002_security_require_login_directory.sql
-- deliberately revoked anon's access so logged-out visitors cannot enumerate
-- tradies (audit finding F3, OWASP API3). A naive DROP + CREATE would silently
-- reopen the directory. The REVOKE ... FROM PUBLIC below is therefore load
-- bearing, not boilerplate -- do not remove it, and keep it BEFORE the GRANT.
--
-- p_apprentice defaults to FALSE, which filters to is_apprentice = false. That
-- preserves today's Discovery result set exactly: existing callers pass nothing
-- and must keep seeing only qualified trades, never a suddenly-mixed list.
--
-- Reversibility: SAFE -- the down script restores the 8-arg signature verbatim.
-- Down: supabase/rollbacks/20260831000004_search_trades_apprentices_down.sql

BEGIN;

DROP FUNCTION IF EXISTS public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer
);

CREATE FUNCTION public.search_trades(
  p_lat double precision, p_lng double precision, p_radius_km integer,
  p_min_rating numeric DEFAULT NULL::numeric,
  p_available_only boolean DEFAULT false,
  p_query text DEFAULT NULL::text,
  p_limit integer DEFAULT 20, p_offset integer DEFAULT 0,
  p_apprentice boolean DEFAULT false
) RETURNS TABLE(
  id uuid, full_name text, primary_trade text, crew_size integer,
  years_experience integer, hourly_rate_min numeric, hourly_rate_max numeric,
  hourly_rate_visible boolean, service_radius_km integer,
  base_suburb text, base_state text, base_postcode text,
  base_formatted_address text, base_place_id text,
  base_latitude double precision, base_longitude double precision,
  about text, trade_other text, licence_url text, portfolio_urls text[],
  is_verified boolean, average_rating numeric, rating_count integer,
  is_available boolean, available_from date, distance_km double precision,
  is_apprentice boolean, apprenticeship_stage text, site_tickets text[]
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
    sub.is_available, sub.available_from, sub.distance_km,
    -- Apprentice projection. site_tickets is SELF-DECLARED: the caller must
    -- render it as a distinct, weaker tier than is_verified. Never merge them.
    sub.is_apprentice, sub.apprenticeship_stage, sub.site_tickets
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
      -- The one new predicate. coalesce so an explicit NULL from a client
      -- behaves as "qualified trades", never as "everyone".
      AND tp.is_apprentice = coalesce(p_apprentice, false)
  ) sub
  WHERE sub.distance_km <= p_radius_km
  ORDER BY sub.distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$;

-- Close the default PUBLIC grant BEFORE granting, so anon never holds EXECUTE
-- even momentarily. See the security note at the top of this file.
REVOKE ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer, boolean
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer, boolean
) FROM anon;

GRANT EXECUTE ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer, boolean
) TO authenticated;

COMMIT;
