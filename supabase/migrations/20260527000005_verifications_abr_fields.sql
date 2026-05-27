-- supabase/migrations/20260527000005_verifications_abr_fields.sql
--
-- Expands the verifications row to carry the additional facts ABR returns
-- alongside the basic ABN status. These are kept on `verifications` (not
-- `builder_profiles`) on purpose: they are regulator-sourced facts, not
-- user-entered profile data. Keeping the trust surface clean means a UI
-- reader can tell at a glance "this came from ABR" vs "the user typed this".
--
-- Columns added:
--   entity_type        — ABR's EntityTypeName, e.g.
--                        "Individual/Sole Trader", "Australian Private Company"
--   abn_registered_at  — ABR's AbnStatusFromDate; the date the current
--                        AbnStatus took effect (i.e., when the ABN went Active
--                        if it's currently active, or when it was Cancelled)
--   abr_state          — ABR's AddressState (NSW/VIC/etc.); the state listed
--                        on the registered business address
--   abr_postcode       — ABR's AddressPostcode; ditto, postcode portion
--
-- RLS: no change needed. Existing policies cover all columns by table grant.
-- Owner SELECT + admin SELECT + service-role write are already configured.

ALTER TABLE public.verifications
  ADD COLUMN IF NOT EXISTS entity_type       text,
  ADD COLUMN IF NOT EXISTS abn_registered_at date,
  ADD COLUMN IF NOT EXISTS abr_state         text,
  ADD COLUMN IF NOT EXISTS abr_postcode      text;

COMMENT ON COLUMN public.verifications.entity_type IS
  'ABR EntityTypeName, e.g. "Individual/Sole Trader". Replaces the hardcoded '
  '"Company" label on the profile COMPANY DETAILS card.';

COMMENT ON COLUMN public.verifications.abn_registered_at IS
  'ABR AbnStatusFromDate — the date the current AbnStatus took effect. '
  'Used to render "In business since YYYY" on profiles.';

COMMENT ON COLUMN public.verifications.abr_state IS
  'AU state where the business is registered (from ABR AddressState). '
  'Distinct from builder_profiles.service_state (where they actually work).';

COMMENT ON COLUMN public.verifications.abr_postcode IS
  'Postcode of the registered business address (from ABR AddressPostcode). '
  'Public information per ABR; storing per Privacy Act exempt-business-info.';
