-- 20260609000005_new_job_push_delivery.sql
-- #8 send side wired: extend the new-job fan-out so that, after creating the
-- in-app notifications, it also fires an FCM push to the matching trades' devices
-- via the push-send edge fn (async, best-effort, never blocks the insert).
--
-- AUTH NOTE: calls push-send with the *public* anon key (verify-jwt). This is the
-- standard Supabase function exposure. push-send does its DB read with its own
-- service-role env. ⚠ For production, gate push-send on the caller (service_role
-- only) via a Supabase Database Webhook, or add a shared-secret header — so the
-- endpoint can't be used to send arbitrary pushes. Tracked in
-- docs/PUSH_NOTIFICATIONS_SETUP.md.

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.notify_trades_on_new_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_ids uuid[];
  v_title    text;
BEGIN
  IF NEW.status <> 'open' THEN
    RETURN NEW;
  END IF;

  -- Matching available trades (case-insensitive trade-type match).
  SELECT array_agg(tp.id)
    INTO v_user_ids
    FROM public.trade_profiles tp
   WHERE tp.deleted_at IS NULL
     AND tp.is_available
     AND NEW.trade_type_required <> ''
     AND lower(tp.primary_trade) = lower(NEW.trade_type_required)
     AND tp.id <> NEW.builder_id;

  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  v_title := COALESCE(NULLIF(NEW.title, ''), 'A new job')
             || ' — ' || COALESCE(NULLIF(NEW.trade_type_required, ''), 'trade');

  -- In-app notifications (unchanged behaviour).
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT uid, 'new_job', 'New job near you', v_title,
         jsonb_build_object('job_id', NEW.id, 'trade', NEW.trade_type_required)
    FROM unnest(v_user_ids) AS uid;

  -- Push delivery (best-effort, async via pg_net). Failures never block the job.
  BEGIN
    PERFORM net.http_post(
      url := 'https://zethpanvkfyijislxesn.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpldGhwYW52a2Z5aWppc2x4ZXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MjYyMzUsImV4cCI6MjA5MzQwMjIzNX0.YvW3jHql3SfiwGo7y2y_AwewMa3igyz7nNTbhNC9s5E',
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_ids', to_jsonb(v_user_ids),
        'title', 'New job near you',
        'body', v_title,
        'data', jsonb_build_object('job_id', NEW.id)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;
