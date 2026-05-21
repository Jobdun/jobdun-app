-- Sprint P2 — Profile schema cleanup
-- Drops dormant columns surfaced by docs/PROFILE_IMPROVEMENT_PLAN.md §2.
-- Every column dropped here has zero read paths in lib/ after the
-- companion Dart changes that ship in the same PR.
--
-- Reversibility: NONE. ALTER TABLE DROP COLUMN destroys data. Take a
-- pg_dump of staging before applying:
--
--   pg_dump --table=public.profiles \
--           --table=public.builder_profiles \
--           --table=public.trade_profiles \
--           "$STAGING_DSN" > backup_p2_cleanup.sql
--
-- Then `supabase db push` to apply.

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS bio,
  DROP COLUMN IF EXISTS onboarding_completed_at;

ALTER TABLE public.builder_profiles
  DROP COLUMN IF EXISTS description,
  DROP COLUMN IF EXISTS logo_url;

ALTER TABLE public.trade_profiles
  DROP COLUMN IF EXISTS hourly_rate,
  DROP COLUMN IF EXISTS day_rate,
  DROP COLUMN IF EXISTS bio;
