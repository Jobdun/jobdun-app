-- supabase/migrations/20260531000004_expire_stale_verifications.sql
--
-- AUDIT FIX C1 — nothing ever writes status='expired'.
--
-- The 'expired' enum value and the verifications_expiring_idx partial index
-- (20260525000001) have always existed, but no job/trigger/cron uses them, so a
-- licence past its expires_at stays 'verified' forever: owner banner, receipts,
-- and applicant lists all keep showing verified. This function is the missing
-- writer — flip every verified licence whose expires_at is in the past to
-- 'expired', notify the holder, and return how many were swept.
--
-- The trade_is_verified_sync trigger recomputes trade_profiles.is_verified on
-- each UPDATE, so cross-user surfaces correct themselves automatically.
--
-- SCHEDULING. This is meant to run on a schedule (hourly is plenty). pg_cron is
-- NOT installed in this repo, so it is NOT wired to a schedule here. Ops must
-- either enable pg_cron and uncomment the cron.schedule line below, or invoke
-- this via a scheduled edge function (service-role key). EXECUTE is granted to
-- service_role ONLY — never to authenticated — because a sweep is an operator
-- action, not a user action.
--
--   -- Once pg_cron is enabled (CREATE EXTENSION pg_cron;), schedule hourly:
--   -- select cron.schedule(
--   --   'expire-verifications',
--   --   '0 * * * *',
--   --   $$select public.expire_stale_verifications()$$
--   -- );
--
-- Reversibility: SAFE — see DOWN block.

CREATE OR REPLACE FUNCTION public.expire_stale_verifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_count   integer := 0;
BEGIN
  FOR v_user_id IN
    UPDATE public.verifications
       SET status     = 'expired',
           updated_at = now()
     WHERE kind        = 'licence'
       AND status      = 'verified'
       AND expires_at IS NOT NULL
       AND expires_at  < now()
    RETURNING user_id
  LOOP
    v_count := v_count + 1;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_user_id,
      'document_expired',
      'Licence expired',
      'Your trade licence has expired — re-verify to stay verified.',
      jsonb_build_object('kind', 'licence')
    );
  END LOOP;

  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.expire_stale_verifications() IS
  'Maintenance sweep: flips verified licence rows past expires_at to expired, '
  'notifies each holder (document_expired), returns the count. service_role '
  'only; meant to run on a schedule (pg_cron or a scheduled edge function).';

GRANT EXECUTE ON FUNCTION public.expire_stale_verifications() TO service_role;

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.expire_stale_verifications() FROM service_role;
-- DROP FUNCTION IF EXISTS public.expire_stale_verifications();
-- ============================================================================
