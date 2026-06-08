-- 20260609000006_notification_preferences.sql
-- Push program — foundation 1/2: per-user, per-category notification preferences
-- + a category mapper used by the central push trigger (next migration) and the
-- mobile settings UI. Default: everything on (a missing row = enabled).

-- Maps a notification.type to a user-facing category (what the prefs toggle).
CREATE OR REPLACE FUNCTION public.notification_category(p_type text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_type = 'new_job'                 THEN 'jobs'
    WHEN p_type LIKE 'application%'          THEN 'applications'
    WHEN p_type LIKE 'message%'              THEN 'messages'
    WHEN p_type LIKE 'review%'               THEN 'reviews'
    WHEN p_type LIKE '%verif%'
      OR p_type LIKE 'document_%'            THEN 'verification'
    WHEN p_type = 'announcement'             THEN 'announcements'
    ELSE 'other'
  END;
$$;

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id        uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category       text    NOT NULL,
  push_enabled   boolean NOT NULL DEFAULT true,
  in_app_enabled boolean NOT NULL DEFAULT true,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notification_preferences_owner ON public.notification_preferences;
CREATE POLICY notification_preferences_owner ON public.notification_preferences
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.notification_preferences IS
  'Per-user push/in-app opt-out by category. Missing row = enabled (default on). '
  'Read by notifications_push_fanout() and the mobile /settings/notifications UI.';
