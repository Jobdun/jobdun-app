-- Sprint Places-1 — MapTiler geocoding columns
--
-- Adds structured-place metadata returned by MapTiler Geocoding (used via
-- JPlaceField on profile-edit, job-create, and the jobs-search chip) to the
-- three location-bearing tables.
--
-- * jobs already has latitude/longitude; this migration only adds the
--   formatted_address + place_id sidecar pair.
-- * trade_profiles and builder_profiles previously stored ONLY the text
--   triplet (suburb, state, postcode). They now also carry lat/lng so the
--   home map can plot tradies + builders, and the new sidecar pair so
--   re-saves are idempotent without re-querying MapTiler.
--
-- Reversibility: SAFE. Every column is NULL-able and defaults to NULL — the
-- forward path is purely additive, and ALTER TABLE DROP COLUMN restores the
-- previous shape. No data is destroyed.
--
-- Verification:
--   supabase db push
--   psql "$SUPABASE_DB_URL" -c "\d public.trade_profiles"   -- should show base_latitude, base_longitude, base_formatted_address, base_place_id
--   psql "$SUPABASE_DB_URL" -c "\d public.builder_profiles" -- should show the service_* equivalents
--   psql "$SUPABASE_DB_URL" -c "\d public.jobs"             -- should show formatted_address, place_id

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS formatted_address text,
  ADD COLUMN IF NOT EXISTS place_id          text;

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS base_formatted_address text,
  ADD COLUMN IF NOT EXISTS base_place_id          text,
  ADD COLUMN IF NOT EXISTS base_latitude          double precision,
  ADD COLUMN IF NOT EXISTS base_longitude         double precision;

ALTER TABLE public.builder_profiles
  ADD COLUMN IF NOT EXISTS service_formatted_address text,
  ADD COLUMN IF NOT EXISTS service_place_id          text,
  ADD COLUMN IF NOT EXISTS service_latitude          double precision,
  ADD COLUMN IF NOT EXISTS service_longitude         double precision;

-- Lat/lng indexes — used by the home map's "tradies/builders near me" query
-- (haversine on (lat, lng) — no PostGIS needed at our scale). Composite so a
-- single index serves both the latitude and longitude predicates.
CREATE INDEX IF NOT EXISTS idx_trade_profiles_base_latlng
  ON public.trade_profiles (base_latitude, base_longitude);

CREATE INDEX IF NOT EXISTS idx_builder_profiles_service_latlng
  ON public.builder_profiles (service_latitude, service_longitude);
