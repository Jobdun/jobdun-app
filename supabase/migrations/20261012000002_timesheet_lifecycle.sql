-- Clock-in is limited to the hired trade; client updates only finish a shift.
-- No legacy rows are changed. A duplicate-active preflight aborts deployment
-- rather than guessing which historical entry should be retained.
-- Rollback: supabase/rollbacks/20261012000002_timesheet_lifecycle_down.sql
BEGIN;
SET LOCAL lock_timeout = '5s';

-- Serialize installation with writers; both preflight and index see the same
-- set of entries. An oversized/busy deployment should retry during quiet time.
LOCK TABLE public.timesheets IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM public.timesheets WHERE check_out_at IS NULL
    GROUP BY job_id, trade_id HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate active timesheets require reviewed maintenance before deployment'
      USING ERRCODE = '23505';
  END IF;
END; $$;

-- A uniqueness constraint also covers races and privileged imports. Closed
-- entries remain unlimited. service_role can repair data, but cannot introduce
-- two active shifts for the same pair.
CREATE UNIQUE INDEX timesheets_one_active_job_trade
  ON public.timesheets (job_id, trade_id) WHERE check_out_at IS NULL;

CREATE FUNCTION public.guard_timesheet_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid();
  vacancy public.jobs%ROWTYPE;
BEGIN
  IF auth.role() = 'service_role' THEN RETURN NEW; END IF;
  IF actor IS NULL OR actor IS DISTINCT FROM NEW.trade_id THEN
    RAISE EXCEPTION 'Only the trade may manage their timesheet' USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Hold the vacancy stable through this transaction. Concurrent closure,
    -- deletion or hired-trade reassignment must serialize with clock-in.
    SELECT * INTO vacancy FROM public.jobs WHERE id = NEW.job_id FOR SHARE;
    IF vacancy.id IS NULL THEN
      RAISE EXCEPTION 'This job is not available for check-in' USING ERRCODE = '23514';
    END IF;
    IF NEW.builder_id IS DISTINCT FROM vacancy.builder_id
       OR actor = vacancy.builder_id
       OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = actor AND role = 'trade') THEN
      RAISE EXCEPTION 'Invalid timesheet owner or builder' USING ERRCODE = '42501';
    END IF;
    IF vacancy.status <> 'filled' OR vacancy.deleted_at IS NOT NULL
       OR vacancy.hired_trade_id IS DISTINCT FROM actor
       OR NOT EXISTS (
         SELECT 1 FROM public.applications
         WHERE job_id = NEW.job_id AND trade_id = actor
           AND builder_id = vacancy.builder_id AND status = 'hired'
       ) THEN
      RAISE EXCEPTION 'Only the hired trade may check in to an active job' USING ERRCODE = '23514';
    END IF;
    IF NEW.check_out_at IS NOT NULL OR NEW.check_out_lat IS NOT NULL OR NEW.check_out_lng IS NOT NULL THEN
      RAISE EXCEPTION 'A new timesheet must start with check-in only' USING ERRCODE = '23514';
    END IF;
    -- The app omits these fields. Override submitted values too, so a client
    -- cannot fabricate an earlier start or a different creation timestamp.
    NEW.check_in_at := statement_timestamp();
    NEW.created_at := NEW.check_in_at;
    RETURN NEW;
  END IF;

  IF OLD.check_out_at IS NOT NULL THEN
    RAISE EXCEPTION 'A completed timesheet cannot be changed' USING ERRCODE = '23514';
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.job_id IS DISTINCT FROM OLD.job_id
     OR NEW.builder_id IS DISTINCT FROM OLD.builder_id
     OR NEW.trade_id IS DISTINCT FROM OLD.trade_id
     OR NEW.check_in_at IS DISTINCT FROM OLD.check_in_at
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.check_in_lat IS DISTINCT FROM OLD.check_in_lat
     OR NEW.check_in_lng IS DISTINCT FROM OLD.check_in_lng
     OR NEW.note IS DISTINCT FROM OLD.note THEN
    RAISE EXCEPTION 'Timesheet identity and check-in details are immutable' USING ERRCODE = '42501';
  END IF;
  IF NEW.check_out_at IS NULL OR NOT isfinite(NEW.check_out_at)
     OR NEW.check_out_at < OLD.check_in_at
     OR statement_timestamp() < OLD.check_in_at THEN
    RAISE EXCEPTION 'Check-out must be a finite time at or after check-in' USING ERRCODE = '23514';
  END IF;
  -- Keep rejecting malformed or out-of-order input, but never let a client's
  -- clock determine shift duration. Privileged historical maintenance already
  -- returned above and retains its submitted timestamps.
  NEW.check_out_at := statement_timestamp();
  -- Do not recheck job/hire eligibility here: closing, deleting or reassigning
  -- a job must not strand its trade with an existing open entry.
  RETURN NEW;
END; $$;
ALTER FUNCTION public.guard_timesheet_lifecycle() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.guard_timesheet_lifecycle() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER timesheet_lifecycle_guard BEFORE INSERT OR UPDATE ON public.timesheets
  FOR EACH ROW EXECUTE FUNCTION public.guard_timesheet_lifecycle();

DROP POLICY timesheets_trade_all ON public.timesheets;
CREATE POLICY timesheets_trade_select ON public.timesheets
  FOR SELECT TO authenticated USING (trade_id = auth.uid());
CREATE POLICY timesheets_trade_insert ON public.timesheets
  FOR INSERT TO authenticated WITH CHECK (trade_id = auth.uid());
CREATE POLICY timesheets_trade_update ON public.timesheets
  FOR UPDATE TO authenticated USING (trade_id = auth.uid()) WITH CHECK (trade_id = auth.uid());
-- Keep the existing builder SELECT policy and service_role maintenance grants.
-- TRUNCATE bypasses RLS, so it must also be denied explicitly.
REVOKE DELETE, TRUNCATE ON public.timesheets FROM anon, authenticated;
COMMIT;
