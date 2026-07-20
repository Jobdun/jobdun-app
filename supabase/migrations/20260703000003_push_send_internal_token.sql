-- B1 — gate push-send on a shared internal token so ONLY the DB fan-out can trigger pushes.
-- OWASP API5 (Broken Function-Level Auth) + API2. See docs/SECURITY_AUDIT_2026-07-02.md.
--
-- The fan-out now presents the 'push_internal_token' Vault secret as an `x-internal-token`
-- header. push-send (deployed separately) rejects any caller lacking the matching
-- PUSH_INTERNAL_TOKEN edge secret — so the public anon key alone can no longer fire pushes.
--
-- DEPLOY ORDER: apply THIS migration FIRST (fan-out starts sending the token), THEN redeploy
-- push-send (starts requiring it). Doing it in this order means no push is ever rejected mid-way.
--
-- SAFETY: the Vault read and the HTTP post are each wrapped so this AFTER-INSERT trigger can
-- NEVER raise — worst case a push silently doesn't fire; the notification insert + app action
-- always succeed. The in-app notification is unaffected regardless.

CREATE OR REPLACE FUNCTION public.notifications_push_fanout() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_category text;
  v_enabled  boolean;
  v_token    text;
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

  -- Read the shared secret; if Vault is unavailable, degrade to no-push (never break the insert).
  BEGIN
    SELECT decrypted_secret INTO v_token
      FROM vault.decrypted_secrets WHERE name = 'push_internal_token';
  EXCEPTION WHEN OTHERS THEN
    v_token := NULL;
  END;

  BEGIN
    PERFORM net.http_post(
      url := 'https://zethpanvkfyijislxesn.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpldGhwYW52a2Z5aWppc2x4ZXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MjYyMzUsImV4cCI6MjA5MzQwMjIzNX0.YvW3jHql3SfiwGo7y2y_AwewMa3igyz7nNTbhNC9s5E',
        'Content-Type', 'application/json',
        'x-internal-token', COALESCE(v_token, '')
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

ALTER FUNCTION public.notifications_push_fanout() OWNER TO postgres;
