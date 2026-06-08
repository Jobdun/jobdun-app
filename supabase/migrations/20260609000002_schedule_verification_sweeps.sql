-- 20260609000002_schedule_verification_sweeps.sql
-- Rail A (#22): enable pg_cron and actually schedule the expiry sweep that
-- 20260531000004 deliberately left manual, plus an advance "expiring soon"
-- warning so a tradie hears about it BEFORE the verified badge drops — not only
-- the morning after.

create extension if not exists pg_cron;

-- Advance warning: notify holders whose verified licence expires within p_days.
-- Deduped by a time window on notifications.created_at (no per-row marker column
-- assumed) so a holder gets at most one warning per fortnight rather than one
-- every nightly run for the whole window.
create or replace function public.notify_expiring_verifications(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT v.user_id,
         'verification_expiring',
         'Licence expiring soon',
         'Your trade licence expires on '
           || to_char(v.expires_at, 'DD Mon YYYY')
           || ' — re-verify to keep your verified badge.',
         jsonb_build_object('kind', 'licence')
    FROM public.verifications v
   WHERE v.kind       = 'licence'
     AND v.status     = 'verified'
     AND v.expires_at IS NOT NULL
     AND v.expires_at >= now()
     AND v.expires_at <  now() + make_interval(days => p_days)
     AND NOT EXISTS (
       SELECT 1
         FROM public.notifications n
        WHERE n.user_id    = v.user_id
          AND n.type       = 'verification_expiring'
          AND n.created_at >= now() - interval '14 days'
     );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.notify_expiring_verifications(integer) IS
  'Advance-warning sweep: notifies holders whose verified licence expires within '
  'N days (default 30), deduped to ~once per fortnight. service_role only; runs '
  'on a schedule alongside expire_stale_verifications().';

REVOKE ALL ON FUNCTION public.notify_expiring_verifications(integer) FROM public;
GRANT EXECUTE ON FUNCTION public.notify_expiring_verifications(integer) TO service_role;

-- Schedule both daily at 02:00 UTC. cron.schedule upserts by jobname, so a
-- re-run of this migration just refreshes the existing schedule (no duplicate).
SELECT cron.schedule(
  'expire-verifications-daily',
  '0 2 * * *',
  $$SELECT public.expire_stale_verifications();$$
);
SELECT cron.schedule(
  'notify-expiring-verifications-daily',
  '0 2 * * *',
  $$SELECT public.notify_expiring_verifications(30);$$
);
