-- 20260609000004_new_job_notifications.sql
-- #8 — the UNBLOCKED half: when a job is posted (open), fan out an in-app
-- notification to trades whose primary trade matches, via the existing
-- notifications centre. The audit's gap was "nothing inserts a notification
-- when a job is posted" — this closes that. FCM *push delivery* is the separate,
-- Firebase-blocked half (device_tokens below + a push-send edge fn) — see
-- docs/PUSH_NOTIFICATIONS_SETUP.md.

-- 1. device_tokens — where FCM/APNs tokens land once the push rail is wired.
--    Owner-only RLS (a user manages only their own tokens).
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token      text NOT NULL,
  platform   text NOT NULL DEFAULT 'android',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS device_tokens_owner ON public.device_tokens;
CREATE POLICY device_tokens_owner ON public.device_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 2. Fan-out: in-app notification to matching trades on a new open job. Matches
--    on trade type (case-insensitive); geo radius is a follow-up refinement.
--    SECURITY DEFINER so the insert reaches other users' notifications despite
--    owner-only RLS. Skips draft inserts (createJob inserts as 'open').
CREATE OR REPLACE FUNCTION public.notify_trades_on_new_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status <> 'open' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT tp.id,
         'new_job',
         'New job near you',
         COALESCE(NULLIF(NEW.title, ''), 'A new job')
           || ' — ' || COALESCE(NULLIF(NEW.trade_type_required, ''), 'trade'),
         jsonb_build_object('job_id', NEW.id, 'trade', NEW.trade_type_required)
    FROM public.trade_profiles tp
   WHERE tp.deleted_at IS NULL
     AND tp.is_available
     AND NEW.trade_type_required <> ''
     AND lower(tp.primary_trade) = lower(NEW.trade_type_required)
     AND tp.id <> NEW.builder_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_trades_on_new_job_trg ON public.jobs;
CREATE TRIGGER notify_trades_on_new_job_trg
  AFTER INSERT ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.notify_trades_on_new_job();

COMMENT ON FUNCTION public.notify_trades_on_new_job() IS
  '#8 in-app fan-out: notifies matching available trades when a job is posted. '
  'Trade-type match (geo is a follow-up). FCM push delivery is separate.';
