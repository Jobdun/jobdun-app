-- Rollback for 20260703000001_security_lock_identity_cols.sql
-- Run manually against the DB if the identity-lock needs to be reverted.
DROP INDEX  IF EXISTS public.idx_conversations_job_id;
DROP TRIGGER IF EXISTS trg_lock_identity_timesheets     ON public.timesheets;
DROP TRIGGER IF EXISTS trg_lock_identity_quote_requests ON public.quote_requests;
DROP TRIGGER IF EXISTS trg_lock_identity_bookings       ON public.bookings;
DROP TRIGGER IF EXISTS trg_lock_identity_applications   ON public.applications;
DROP TRIGGER IF EXISTS trg_lock_identity_messages       ON public.messages;
DROP TRIGGER IF EXISTS trg_lock_identity_conversations  ON public.conversations;
DROP FUNCTION IF EXISTS public.forbid_identity_col_change();
