-- 20260604000001_trade_search.sql
-- M1 slice 1: trade availability + denormalised rating + geo search RPC.

-- 1. Availability columns + denormalised rating columns.
--    average_rating / rating_count fix an existing drift: TradeProfileModel
--    already reads them, but they were never created (ratings live in reviews).
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_available   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS available_from date,
  ADD COLUMN IF NOT EXISTS average_rating numeric(3,2),
  ADD COLUMN IF NOT EXISTS rating_count   int NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS trade_profiles_is_available_idx
  ON public.trade_profiles (is_available);
CREATE INDEX IF NOT EXISTS trade_profiles_average_rating_idx
  ON public.trade_profiles (average_rating);

-- 2. Rating denormalisation: recompute one trade's average from reviews.
--    SECURITY DEFINER so the reviews trigger (fired by the reviewer, not the
--    trade owner) can update trade_profiles despite owner-only update RLS.
CREATE OR REPLACE FUNCTION public.recompute_trade_rating(p_trade_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.trade_profiles tp
  SET average_rating = sub.avg_rating,
      rating_count   = sub.cnt
  FROM (
    SELECT round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS cnt
    FROM public.reviews
    WHERE reviewee_id = p_trade_id
  ) sub
  WHERE tp.id = p_trade_id;
$$;

CREATE OR REPLACE FUNCTION public.reviews_sync_trade_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    RETURN OLD;
  END IF;
  PERFORM public.recompute_trade_rating(NEW.reviewee_id);
  IF (TG_OP = 'UPDATE' AND OLD.reviewee_id <> NEW.reviewee_id) THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reviews_sync_trade_rating_trg ON public.reviews;
CREATE TRIGGER reviews_sync_trade_rating_trg
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.reviews_sync_trade_rating();

-- One-time backfill of existing reviews (no-op for builder reviewees).
UPDATE public.trade_profiles tp
SET average_rating = sub.avg_rating, rating_count = sub.cnt
FROM (
  SELECT reviewee_id,
         round(avg(rating)::numeric, 2) AS avg_rating,
         count(*)::int AS cnt
  FROM public.reviews
  GROUP BY reviewee_id
) sub
WHERE tp.id = sub.reviewee_id;

-- 3. Geo search RPC. Bounding-box prefilter (uses the existing
--    (base_latitude, base_longitude) btree) then haversine for exact distance.
--    SECURITY INVOKER -> trade_profiles_select_authenticated RLS applies.
CREATE OR REPLACE FUNCTION public.search_trades(
  p_lat            double precision,
  p_lng            double precision,
  p_radius_km      int,
  p_min_rating     numeric DEFAULT NULL,
  p_available_only boolean DEFAULT false,
  p_query          text    DEFAULT NULL,
  p_limit          int     DEFAULT 20,
  p_offset         int     DEFAULT 0
)
RETURNS TABLE (
  id uuid, full_name text, primary_trade text, crew_size int,
  years_experience int, hourly_rate_min numeric, hourly_rate_max numeric,
  hourly_rate_visible boolean, service_radius_km int,
  base_suburb text, base_state text, base_postcode text,
  base_formatted_address text, base_place_id text,
  base_latitude double precision, base_longitude double precision,
  about text, trade_other text, licence_url text, portfolio_urls text[],
  is_verified boolean, verified_at timestamptz,
  average_rating numeric, rating_count int,
  is_available boolean, available_from date,
  distance_km double precision
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT * FROM (
    SELECT
      tp.id, tp.full_name, tp.primary_trade, tp.crew_size,
      tp.years_experience, tp.hourly_rate_min, tp.hourly_rate_max,
      tp.hourly_rate_visible, tp.service_radius_km,
      tp.base_suburb, tp.base_state, tp.base_postcode,
      tp.base_formatted_address, tp.base_place_id,
      tp.base_latitude, tp.base_longitude,
      tp.about, tp.trade_other, tp.licence_url, tp.portfolio_urls,
      tp.is_verified, tp.verified_at,
      tp.average_rating, tp.rating_count,
      tp.is_available, tp.available_from,
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

GRANT EXECUTE ON FUNCTION public.search_trades(
  double precision, double precision, int, numeric, boolean, text, int, int
) TO authenticated;
