-- M1 (BACKEND_FULL_AUDIT_2026-06-11 · P0): close F-RLS-02's remaining surface.
--
-- The `verifications` source table is already client-write-locked, but the
-- columns *synced from it* were not: `trade_profiles_update_own` /
-- `builder_profiles_update_own` allow every column, so a signed-in user could
-- set their own `is_verified = true` or overwrite the trigger-maintained
-- rating aggregates via PostgREST. Same class: a trade could UPDATE
-- `verification_documents.status` on their own rows (self-approve).
--
-- Mechanism: column-level privileges (allowlist GRANT after table REVOKE)
-- instead of pin triggers — no trigger-ordering interplay, and every sync
-- path that legitimately writes these columns is SECURITY DEFINER
-- (verified 2026-06-11: reviews_sync_trade_rating, recompute_*_rating,
-- sync_trade_is_verified all DEFINER; admin review goes through the
-- review_verification_document RPCs; service_role keeps its own grants).
--
-- Client write inventory verified before choosing the allowlists:
--   role_resolver.dart        upsert {id}, update {full_name|contact_name}
--   profile_remote_datasource patch upserts (allowlisted cols only),
--                             is_available, unavailable_dates, licence_url
--   verification_remote_ds    insert docs; UPDATE only {deleted_at} (soft delete)
-- The legacy full-row writer that serialised is_verified/average_rating was
-- deleted the same day (quick-edit sheets, partial saves).

BEGIN;

-- ── trade_profiles ────────────────────────────────────────────────────────
-- Pinned (server-only): is_verified, average_rating, rating_count,
-- created_at, updated_at, deleted_at.
REVOKE INSERT, UPDATE ON public.trade_profiles FROM authenticated;
GRANT INSERT (
  id, full_name, primary_trade, trade_other, about,
  base_suburb, base_state, base_postcode,
  base_formatted_address, base_place_id, base_latitude, base_longitude,
  licence_url, crew_size, years_experience,
  hourly_rate_min, hourly_rate_max, hourly_rate_visible,
  service_radius_km, portfolio_urls,
  is_available, available_from, unavailable_dates
) ON public.trade_profiles TO authenticated;
-- `id` stays in the UPDATE grant: PostgREST upserts SET every supplied
-- column (including the conflict key); RLS WITH CHECK (auth.uid() = id)
-- still forbids re-pointing the row at someone else.
GRANT UPDATE (
  id, full_name, primary_trade, trade_other, about,
  base_suburb, base_state, base_postcode,
  base_formatted_address, base_place_id, base_latitude, base_longitude,
  licence_url, crew_size, years_experience,
  hourly_rate_min, hourly_rate_max, hourly_rate_visible,
  service_radius_km, portfolio_urls,
  is_available, available_from, unavailable_dates
) ON public.trade_profiles TO authenticated;

-- ── builder_profiles ──────────────────────────────────────────────────────
-- Pinned: average_rating, rating_count, created_at, updated_at, deleted_at.
REVOKE INSERT, UPDATE ON public.builder_profiles FROM authenticated;
GRANT INSERT (
  id, company_name, abn, contact_name, contact_phone, about, website,
  years_in_business, service_suburb, service_state, service_postcode,
  service_formatted_address, service_place_id, service_latitude,
  service_longitude
) ON public.builder_profiles TO authenticated;
GRANT UPDATE (
  id, company_name, abn, contact_name, contact_phone, about, website,
  years_in_business, service_suburb, service_state, service_postcode,
  service_formatted_address, service_place_id, service_latitude,
  service_longitude
) ON public.builder_profiles TO authenticated;

-- ── verification_documents ────────────────────────────────────────────────
-- Owner UPDATE shrinks to the soft-delete column the app actually uses;
-- status / reviewed_by / reviewed_at become unreachable from clients.
-- Admin review is unaffected (SECURITY DEFINER RPCs). INSERT untouched —
-- uploads keep working; a forged `status` on INSERT only lies to the
-- uploader's own chip list, the badge reads the locked `verifications` table.
REVOKE UPDATE ON public.verification_documents FROM authenticated;
GRANT UPDATE (deleted_at) ON public.verification_documents TO authenticated;

-- ── ABN pin-once-verified (needs row context → small trigger) ─────────────
-- A builder may type/correct their ABN freely *until* an ABR-verified
-- verification exists; after that the column is locked for the owner so the
-- edit UI's verified-lock can't be bypassed. Service role (ABR backfill,
-- auth.uid() IS NULL) and admins keep write access by construction.
CREATE OR REPLACE FUNCTION public.builder_profiles_pin_verified_abn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() = new.id
     AND new.abn IS DISTINCT FROM old.abn
     AND EXISTS (
       SELECT 1 FROM public.verifications v
        WHERE v.user_id = new.id
          AND v.kind = 'abn'
          AND v.status = 'verified'
     )
  THEN
    RAISE EXCEPTION 'ABN is locked after ABR verification. Contact support to change.'
      USING ERRCODE = '42501';
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS builder_profiles_pin_verified_abn_trg
  ON public.builder_profiles;
CREATE TRIGGER builder_profiles_pin_verified_abn_trg
  BEFORE UPDATE ON public.builder_profiles
  FOR EACH ROW EXECUTE FUNCTION public.builder_profiles_pin_verified_abn();

COMMIT;
