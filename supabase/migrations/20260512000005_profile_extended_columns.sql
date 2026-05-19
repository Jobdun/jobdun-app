-- ============================================================
-- Migration: extended profile columns
--
-- Why: /profile/edit collects suburb, state, contact phone, about-text for
-- both Builder and Trade roles. The model layer reads these as `about`,
-- `service_suburb`, `service_state`, `contact_phone` (builder) and
-- `base_suburb`, `base_state`, `about` (trade) but the initial schema
-- didn't include them. T2.6 wires real saves through the profile provider
-- which needs the columns to exist or upserts will fail.
--
-- All adds are nullable + IF NOT EXISTS so this is safe on a populated DB
-- and idempotent if re-applied.
-- ============================================================

ALTER TABLE public.builder_profiles
  ADD COLUMN IF NOT EXISTS contact_name     text,
  ADD COLUMN IF NOT EXISTS contact_phone    text,
  ADD COLUMN IF NOT EXISTS about            text,
  ADD COLUMN IF NOT EXISTS website          text,
  ADD COLUMN IF NOT EXISTS years_in_business int,
  ADD COLUMN IF NOT EXISTS service_suburb   text,
  ADD COLUMN IF NOT EXISTS service_state    text,
  ADD COLUMN IF NOT EXISTS service_postcode text;

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS about         text,
  ADD COLUMN IF NOT EXISTS base_suburb   text,
  ADD COLUMN IF NOT EXISTS base_state    text,
  ADD COLUMN IF NOT EXISTS base_postcode text;
