-- supabase/migrations/20260527000002_trade_is_verified_sync.sql
--
-- Sync `trade_profiles.is_verified` from `public.verifications`.
--
-- Background. v2.1's API-first wizard writes to `public.verifications` (a
-- state machine over (user_id, kind)) via service-role Edge Functions.
-- `public.verifications` has owner-only SELECT RLS, so a builder browsing
-- applicants cannot read another trade's verification rows directly. The
-- legacy `trade_profiles.is_verified` column is the existing cross-user
-- channel for "is this tradie verified?" — applicant lists, search results,
-- tradie cards all read it. Until v2.1 it was set only by the old admin
-- upload flow.
--
-- This trigger mirrors any verified licence row into `is_verified` so
-- cross-user surfaces stay accurate without exposing the verifications
-- table to non-owners.
--
-- Why a trigger, not a view: tradie cards and applicant lists project
-- through `trade_profiles` directly. Keeping the column truthful means no
-- view rewrites and no RLS changes are needed elsewhere.
--
-- Scope: trade licence only. Builder ABN verification stays owner-only and
-- is surfaced via the receipts panel (`VerificationReceipts`) — no
-- equivalent legacy column exists on `builder_profiles`.

CREATE OR REPLACE FUNCTION public.sync_trade_is_verified()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected_user uuid;
  has_verified  boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    affected_user := OLD.user_id;
    IF OLD.kind <> 'licence' THEN
      RETURN OLD;
    END IF;
  ELSE
    affected_user := NEW.user_id;
    -- Skip rows that don't touch the licence channel. Cheap fast-path so
    -- the ABR (kind='abn') hot path isn't taxed.
    IF NEW.kind <> 'licence'
       AND (TG_OP = 'INSERT' OR OLD.kind <> 'licence') THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Truthy if ANY licence row is currently verified — handles multi-state
  -- holders correctly (e.g. dual NSW + VIC where one is suspended).
  SELECT EXISTS (
    SELECT 1
    FROM public.verifications
    WHERE user_id = affected_user
      AND kind    = 'licence'
      AND status  = 'verified'
  ) INTO has_verified;

  -- Only write when the flag actually changes — keeps `updated_at` from
  -- thrashing on every regulator re-check.
  UPDATE public.trade_profiles
     SET is_verified = has_verified,
         updated_at  = now()
   WHERE id           = affected_user
     AND is_verified IS DISTINCT FROM has_verified;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.sync_trade_is_verified() IS
  'Trigger fn — mirrors verified-licence state into trade_profiles.is_verified '
  'so cross-user surfaces (applicant lists, tradie cards) stay in sync with '
  'the v2.1 verifications state machine without RLS changes.';

DROP TRIGGER IF EXISTS verifications_sync_trade_is_verified
  ON public.verifications;

CREATE TRIGGER verifications_sync_trade_is_verified
  AFTER INSERT OR UPDATE OR DELETE ON public.verifications
  FOR EACH ROW EXECUTE FUNCTION public.sync_trade_is_verified();

-- Backfill: any existing verified licence rows that pre-date this trigger.
-- Idempotent — only flips rows whose flag actually disagrees.
UPDATE public.trade_profiles tp
   SET is_verified = TRUE,
       updated_at  = now()
 WHERE is_verified = FALSE
   AND EXISTS (
     SELECT 1
     FROM public.verifications v
     WHERE v.user_id = tp.id
       AND v.kind    = 'licence'
       AND v.status  = 'verified'
   );

-- Reverse-direction backfill: clear stale TRUE flags whose verified row
-- has since expired / been revoked. Cheap one-shot at install time so the
-- column matches the state machine even for users who fell out of verified
-- before this trigger existed.
UPDATE public.trade_profiles tp
   SET is_verified = FALSE,
       updated_at  = now()
 WHERE is_verified = TRUE
   AND NOT EXISTS (
     SELECT 1
     FROM public.verifications v
     WHERE v.user_id = tp.id
       AND v.kind    = 'licence'
       AND v.status  = 'verified'
   );
