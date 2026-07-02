-- ============================================================================
-- STAGED SECURITY FIX — DO NOT auto-apply.
-- Review, then `git mv` into supabase/migrations/<timestamp>_security_lock_identity_cols.sql
-- and run `supabase db push`. Keep the ROLLBACK block (bottom) in supabase/rollbacks/.
--
-- Fixes: B2 (conversation counterparty reassignment), F1 (message re-parenting /
--        block-bypass), F2 (application identity tampering), F4 (booking/quote/
--        timesheet identity tampering), F8 (conversations.job_id unindexed FK).
-- OWASP: API1 (BOLA) + API3 (Broken Object Property Level Authorization).
--
-- Approach: make the identity/foreign-key columns on shared-row tables IMMUTABLE
-- from the client. Ownership RLS already decides WHO may update a row; this stops
-- a legitimate owner from REASSIGNING the row to a different party. The service
-- role (admin Edge Functions / server jobs) is exempt so back-office flows work.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.forbid_identity_col_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- Server/admin paths (requests signed with the service-role key) bypass the guard.
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

-- F8 — cover the one remaining unindexed FK.
-- NOTE: for a zero-downtime add on a live table use CREATE INDEX CONCURRENTLY in a
-- SEPARATE migration WITHOUT a BEGIN/COMMIT wrapper (CONCURRENTLY can't run in a txn).
CREATE INDEX IF NOT EXISTS idx_conversations_job_id ON public.conversations (job_id);

-- ============================================================================
-- ROLLBACK  →  save as supabase/rollbacks/<timestamp>_security_lock_identity_cols_down.sql
-- ----------------------------------------------------------------------------
-- DROP INDEX IF EXISTS public.idx_conversations_job_id;
-- DROP TRIGGER IF EXISTS trg_lock_identity_timesheets     ON public.timesheets;
-- DROP TRIGGER IF EXISTS trg_lock_identity_quote_requests ON public.quote_requests;
-- DROP TRIGGER IF EXISTS trg_lock_identity_bookings       ON public.bookings;
-- DROP TRIGGER IF EXISTS trg_lock_identity_applications   ON public.applications;
-- DROP TRIGGER IF EXISTS trg_lock_identity_messages       ON public.messages;
-- DROP TRIGGER IF EXISTS trg_lock_identity_conversations  ON public.conversations;
-- DROP FUNCTION IF EXISTS public.forbid_identity_col_change();
-- ============================================================================

-- BEFORE APPLYING — verify these legit write paths still pass (they don't touch the
-- locked columns, so they should):
--   * editing a message body / marking read / mute / archive / pin
--   * builder shortlisting/rejecting an application; trade withdrawing
--   * updating a booking's scheduled_date / status; timesheet hours
-- If any legit flow DOES reassign builder_id/trade_id/job_id, route it through a
-- service-role Edge Function (which is exempt) instead of a direct client UPDATE.
