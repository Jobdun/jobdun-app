-- Read-only projection/privacy regression check.
-- supabase db query --linked -f supabase/tests/public_apprentice_profile.sql
BEGIN;
SET LOCAL ROLE authenticated;

SELECT id, is_apprentice, apprenticeship_stage, site_tickets
FROM public.trade_profiles_public
LIMIT 0;

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.trade_profiles_public', 'SELECT') THEN
    RAISE EXCEPTION 'Anonymous users must not enumerate trade profiles';
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trade_profiles_public'
      AND column_name IN ('resume_path', 'resume_uploaded_at', 'licence_url',
                          'base_formatted_address', 'base_place_id')
  ) THEN
    RAISE EXCEPTION 'Storefront view must not expose private document/address fields';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.trade_profiles_public
    WHERE (NOT hourly_rate_visible AND
           (hourly_rate_min IS NOT NULL OR hourly_rate_max IS NOT NULL))
       OR base_latitude IS DISTINCT FROM
          round(base_latitude::numeric, 2)::double precision
       OR base_longitude IS DISTINCT FROM
          round(base_longitude::numeric, 2)::double precision
  ) THEN
    RAISE EXCEPTION 'Storefront view must mask hidden rates and precise coordinates';
  END IF;
END $$;

ROLLBACK;
