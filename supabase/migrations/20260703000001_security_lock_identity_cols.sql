-- Security fix — lock identity/FK columns on shared-row tables + cover the last unindexed FK.
-- Fixes B2 (conversation counterparty reassignment), F1 (message re-parenting / block-bypass),
--       F2/F4 (application/booking/quote/timesheet identity tampering), F8 (conversations.job_id FK).
-- OWASP: API1 (BOLA) + API3 (Broken Object Property Level Authorization).
-- See docs/SECURITY_AUDIT_2026-07-02.md. Rollback: supabase/rollbacks/20260703000001_*_down.sql
--
-- Ownership RLS already decides WHO may update a row; this stops a legitimate owner from
-- REASSIGNING the row to a different party. service_role (admin Edge Functions) is exempt.

CREATE OR REPLACE FUNCTION public.forbid_identity_col_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- Requests signed with the service-role key (admin Edge Functions / server jobs) bypass.
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'messages' THEN
    IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
       OR NEW.sender_id     IS DISTINCT FROM OLD.sender_id THEN
      RAISE EXCEPTION 'messages.conversation_id and sender_id are immutable'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    -- conversations, applications, bookings, quote_requests, timesheets
    -- (all carry builder_id / trade_id / job_id).
    IF NEW.builder_id IS DISTINCT FROM OLD.builder_id
       OR NEW.trade_id IS DISTINCT FROM OLD.trade_id
       OR NEW.job_id   IS DISTINCT FROM OLD.job_id THEN
      RAISE EXCEPTION '%.builder_id / trade_id / job_id are immutable from the client', TG_TABLE_NAME
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.forbid_identity_col_change() OWNER TO postgres;

CREATE TRIGGER trg_lock_identity_conversations
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

CREATE TRIGGER trg_lock_identity_messages
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

CREATE TRIGGER trg_lock_identity_applications
  BEFORE UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

CREATE TRIGGER trg_lock_identity_bookings
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

CREATE TRIGGER trg_lock_identity_quote_requests
  BEFORE UPDATE ON public.quote_requests
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

CREATE TRIGGER trg_lock_identity_timesheets
  BEFORE UPDATE ON public.timesheets
  FOR EACH ROW EXECUTE FUNCTION public.forbid_identity_col_change();

-- F8 — cover the one remaining unindexed FK (plain CREATE INDEX is fine inside the
-- migration transaction; use CONCURRENTLY in a separate txn-less migration only if the
-- table is large enough to matter for lock time).
CREATE INDEX IF NOT EXISTS idx_conversations_job_id ON public.conversations (job_id);
