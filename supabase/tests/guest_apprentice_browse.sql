-- Read-only production regression check. Run with:
-- supabase db query --linked -f supabase/tests/guest_apprentice_browse.sql
BEGIN;
SET LOCAL ROLE anon;

-- The actual mobile feed projection must compile against the guest view.
SELECT id, builder_id, title, description, suburb, state, postcode,
       trade_type_required, budget_amount, pricing_unit, pricing_type, urgency,
       requires_verified, requires_white_card, open_to_apprentices,
       application_count, view_count, status, published_at, created_at,
       updated_at, latitude, longitude, formatted_address, place_id
FROM public.jobs_public_browse
WHERE deleted_at IS NULL
LIMIT 0;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.jobs_public_browse
    WHERE status NOT IN ('open', 'filled')
       OR deleted_at IS NOT NULL
       OR place_id IS NOT NULL
       OR latitude IS DISTINCT FROM round(latitude::numeric, 2)::double precision
       OR longitude IS DISTINCT FROM round(longitude::numeric, 2)::double precision
       OR formatted_address IS DISTINCT FROM
          NULLIF(concat_ws(', ', NULLIF(suburb, ''), NULLIF(state, '')), '')
  ) THEN
    RAISE EXCEPTION 'Guest browse exposes private location or unpublished jobs';
  END IF;
END $$;

ROLLBACK;
