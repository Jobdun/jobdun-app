-- 20260609000007_central_push_trigger.sql
-- Push program — foundation 2/2: ONE trigger turns every notification row into a
-- push. Producers (features + admin) just insert a notification; delivery is
-- uniform and gated by notification_preferences. Replaces the per-feature push
-- bolted into notify_trades_on_new_job (which reverts to insert-only here).
--
-- AUTH NOTE (carried from 20260609000005): calls push-send with the PUBLIC anon
-- key. Harden before prod with a Supabase Database Webhook (service-role) on
-- notifications INSERT — see docs/PUSH_NOTIFICATIONS_SETUP.md.

-- Central fan-out: each new notification → push, if the user hasn't opted out of
-- that category. Best-effort + async; never blocks the insert.
CREATE OR REPLACE FUNCTION public.notifications_push_fanout()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_category text;
  v_enabled  boolean;
BEGIN
  v_category := public.notification_category(NEW.type);

  SELECT push_enabled INTO v_enabled
    FROM public.notification_preferences
   WHERE user_id = NEW.user_id AND category = v_category;
  IF v_enabled IS NULL THEN
    v_enabled := true;  -- no row = default on
  END IF;
  IF NOT v_enabled THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := 'https://zethpanvkfyijislxesn.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpldGhwYW52a2Z5aWppc2x4ZXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MjYyMzUsImV4cCI6MjA5MzQwMjIzNX0.YvW3jHql3SfiwGo7y2y_AwewMa3igyz7nNTbhNC9s5E',
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(NEW.user_id),
        'title', NEW.title,
        'body', NEW.body,
        'data', COALESCE(NEW.data, '{}'::jsonb)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_push_fanout_trg ON public.notifications;
CREATE TRIGGER notifications_push_fanout_trg
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notifications_push_fanout();

-- Revert notify_trades_on_new_job to INSERT-ONLY: the central trigger above now
-- delivers the push for each inserted new_job row.
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
