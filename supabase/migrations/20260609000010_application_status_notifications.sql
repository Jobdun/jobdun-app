-- 20260609000010_application_status_notifications.sql
-- Push program — Stream B (use-case producers), 2/2: application lifecycle
-- notifications. Two P1 "did I get it?" moments from spec §2:
--
--   (a) A tradie applies  -> notify the job's BUILDER  (type 'application_received')
--   (b) The builder moves an application to shortlisted / hired / rejected
--                          -> notify the TRADIE         (type 'application_status')
--
-- Each just inserts a public.notifications row; the central
-- notifications_push_fanout trigger (20260609000007) delivers the push. No app
-- code. notification_category('application_received' | 'application_status') =
-- 'applications' (LIKE 'application%'), so both are gated on the recipient's
-- 'applications' push preference.
--
-- Schema (verified against 20260511000003_applications.sql + 20260511000002_jobs.sql):
--   applications(id, job_id, trade_id, builder_id, status, ...)
--     status enum public.application_status:
--       'pending' | 'shortlisted' | 'rejected' | 'withdrawn'
--       | 'hired' | 'declined_by_trade'
--   jobs(id, builder_id, title, ...)          -- builder_id is the job owner
--   profiles(id, display_name, ...)           -- universal applicant display name
--
-- We notify only on transitions the OTHER party drives and cares about:
--   shortlisted / hired / rejected. 'withdrawn' and 'declined_by_trade' are the
--   tradie's own actions (anti-goal: don't push your own actions), so skipped.
--
-- SECURITY DEFINER + search_path='' so each insert reaches the counterparty's
-- notifications row despite owner-only RLS, mirroring notify_trades_on_new_job.

-- ---------- (a) new application -> notify the job's builder ----------
CREATE OR REPLACE FUNCTION public.notify_builder_on_new_application()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_builder_id   uuid;
  v_job_title    text;
  v_trade_name   text;
BEGIN
  -- The job is the source of truth for who owns it.
  SELECT j.builder_id, j.title
    INTO v_builder_id, v_job_title
    FROM public.jobs j
   WHERE j.id = NEW.job_id;

  IF v_builder_id IS NULL THEN
    RETURN NEW;  -- orphan application; nothing to notify.
  END IF;

  SELECT p.display_name INTO v_trade_name
    FROM public.profiles p
   WHERE p.id = NEW.trade_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_builder_id,
    'application_received',
    'New applicant',
    COALESCE(NULLIF(v_trade_name, ''), 'A tradie')
      || ' applied for "'
      || COALESCE(NULLIF(v_job_title, ''), 'your job')
      || '"',
    jsonb_build_object(
      'job_id',         NEW.job_id,
      'application_id', NEW.id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_builder_on_new_application_trg ON public.applications;
CREATE TRIGGER notify_builder_on_new_application_trg
  AFTER INSERT ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_builder_on_new_application();

COMMENT ON FUNCTION public.notify_builder_on_new_application() IS
  'Stream B producer: on a new application, inserts an application_received '
  'notification for the job''s builder (looked up from jobs.builder_id). Central '
  'push fanout delivers it.';

-- ---------- (b) status change -> notify the tradie ----------
CREATE OR REPLACE FUNCTION public.notify_trade_on_application_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job_title text;
  v_title     text;
  v_body      text;
BEGIN
  -- Only act on a real status transition into a builder-driven outcome state.
  -- (The WHEN clause on the trigger also guards this; belt and braces.)
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT j.title INTO v_job_title
    FROM public.jobs j
   WHERE j.id = NEW.job_id;

  v_job_title := COALESCE(NULLIF(v_job_title, ''), 'a job');

  CASE NEW.status
    WHEN 'shortlisted' THEN
      v_title := 'You were shortlisted';
      v_body  := 'You''ve been shortlisted for "' || v_job_title || '".';
    WHEN 'hired' THEN
      v_title := 'You got the job';
      v_body  := 'You''ve been hired for "' || v_job_title || '". Congratulations!';
    WHEN 'rejected' THEN
      v_title := 'Application update';
      v_body  := 'Your application for "' || v_job_title || '" was not successful.';
    ELSE
      RETURN NEW;  -- not a state we notify on (e.g. withdrawn / declined_by_trade).
  END CASE;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.trade_id,
    'application_status',
    v_title,
    v_body,
    jsonb_build_object(
      'job_id',         NEW.job_id,
      'application_id', NEW.id,
      'status',         NEW.status::text
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_trade_on_application_status_trg ON public.applications;
CREATE TRIGGER notify_trade_on_application_status_trg
  AFTER UPDATE OF status ON public.applications
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status IN ('shortlisted', 'hired', 'rejected')
  )
  EXECUTE FUNCTION public.notify_trade_on_application_status();

COMMENT ON FUNCTION public.notify_trade_on_application_status() IS
  'Stream B producer: when an application moves to shortlisted/hired/rejected, '
  'inserts an application_status notification for the tradie (applications.trade_id). '
  'Central push fanout delivers it. Tradie-driven states (withdrawn/declined) are skipped.';

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- DROP TRIGGER IF EXISTS notify_trade_on_application_status_trg ON public.applications;
-- DROP TRIGGER IF EXISTS notify_builder_on_new_application_trg  ON public.applications;
-- DROP FUNCTION IF EXISTS public.notify_trade_on_application_status();
-- DROP FUNCTION IF EXISTS public.notify_builder_on_new_application();
-- ============================================================================
