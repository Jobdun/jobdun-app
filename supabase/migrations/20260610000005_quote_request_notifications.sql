-- 20260610000005_quote_request_notifications.sql
-- #18 follow-up — push/notification producer for standalone quote requests
-- (table from 20260610000002). Mirrors the application producers
-- (20260609000010): each event just inserts a public.notifications row; the
-- central notifications_push_fanout trigger (20260609000007) delivers the push.
-- No app code.
--
--   (a) builder creates a request   -> notify the TRADE    (type 'quote_requested')
--   (b) trade responds quoted/declined -> notify the BUILDER (type 'quote_responded')
--
-- Each notifies the COUNTERPARTY (never the actor — anti-goal: don't push your
-- own action). SECURITY DEFINER + search_path='' so the insert reaches the
-- counterparty's row despite owner-only RLS, mirroring the other producers.

-- Extend the category mapper so quote_* notifications gate on the recipient's
-- existing 'applications' push preference (they're part of the hiring dealings,
-- same bucket as application notifications — a togglable, high-value category).
CREATE OR REPLACE FUNCTION public.notification_category(p_type text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_type = 'new_job'                 THEN 'jobs'
    WHEN p_type LIKE 'application%'          THEN 'applications'
    WHEN p_type LIKE 'quote%'                THEN 'applications'
    WHEN p_type LIKE 'message%'              THEN 'messages'
    WHEN p_type LIKE 'review%'               THEN 'reviews'
    WHEN p_type LIKE '%verif%'
      OR p_type LIKE 'document_%'            THEN 'verification'
    WHEN p_type = 'announcement'             THEN 'announcements'
    ELSE 'other'
  END;
$$;

-- ---------- (a) new quote request -> notify the trade ----------
CREATE OR REPLACE FUNCTION public.notify_trade_on_quote_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job_title    text;
  v_builder_name text;
BEGIN
  SELECT j.title INTO v_job_title
    FROM public.jobs j WHERE j.id = NEW.job_id;

  SELECT p.display_name INTO v_builder_name
    FROM public.profiles p WHERE p.id = NEW.builder_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.trade_id,
    'quote_requested',
    'Quote requested',
    COALESCE(NULLIF(v_builder_name, ''), 'A builder')
      || ' asked you to quote "'
      || COALESCE(NULLIF(v_job_title, ''), 'a job')
      || '".',
    jsonb_build_object('job_id', NEW.job_id, 'quote_request_id', NEW.id)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_trade_on_quote_request_trg ON public.quote_requests;
CREATE TRIGGER notify_trade_on_quote_request_trg
  AFTER INSERT ON public.quote_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_trade_on_quote_request();

COMMENT ON FUNCTION public.notify_trade_on_quote_request() IS
  '#18 producer: on a new quote_requests row, notifies the trade '
  '(quote_requested). Central push fanout delivers it.';

-- ---------- (b) response (quoted / declined) -> notify the builder ----------
CREATE OR REPLACE FUNCTION public.notify_builder_on_quote_response()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job_title  text;
  v_trade_name text;
  v_title      text;
  v_body       text;
BEGIN
  SELECT j.title INTO v_job_title
    FROM public.jobs j WHERE j.id = NEW.job_id;
  v_job_title := COALESCE(NULLIF(v_job_title, ''), 'a job');

  SELECT p.display_name INTO v_trade_name
    FROM public.profiles p WHERE p.id = NEW.trade_id;
  v_trade_name := COALESCE(NULLIF(v_trade_name, ''), 'A tradie');

  CASE NEW.status
    WHEN 'quoted' THEN
      v_title := 'Quote received';
      v_body  := v_trade_name || ' sent a quote for "' || v_job_title || '".';
    WHEN 'declined' THEN
      v_title := 'Quote declined';
      v_body  := v_trade_name || ' declined to quote "' || v_job_title || '".';
    ELSE
      RETURN NEW;  -- other transitions don't notify the builder.
  END CASE;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.builder_id,
    'quote_responded',
    v_title,
    v_body,
    jsonb_build_object(
      'job_id',           NEW.job_id,
      'quote_request_id', NEW.id,
      'status',           NEW.status::text
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_builder_on_quote_response_trg ON public.quote_requests;
CREATE TRIGGER notify_builder_on_quote_response_trg
  AFTER UPDATE OF status ON public.quote_requests
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    AND NEW.status IN ('quoted', 'declined')
  )
  EXECUTE FUNCTION public.notify_builder_on_quote_response();

COMMENT ON FUNCTION public.notify_builder_on_quote_response() IS
  '#18 producer: when a quote_requests row moves to quoted/declined, notifies '
  'the builder (quote_responded). Central push fanout delivers it.';

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- DROP TRIGGER IF EXISTS notify_builder_on_quote_response_trg ON public.quote_requests;
-- DROP TRIGGER IF EXISTS notify_trade_on_quote_request_trg   ON public.quote_requests;
-- DROP FUNCTION IF EXISTS public.notify_builder_on_quote_response();
-- DROP FUNCTION IF EXISTS public.notify_trade_on_quote_request();
-- (notification_category keeps the quote mapping — harmless; revert to the
--  20260609000006 body if you must fully roll back.)
-- ============================================================================
