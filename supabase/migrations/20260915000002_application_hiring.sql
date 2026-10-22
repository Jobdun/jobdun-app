-- Validate participant actions and assign a single vacancy atomically on hire.
BEGIN;
CREATE OR REPLACE FUNCTION public.guard_application_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid();
  vacancy public.jobs%ROWTYPE;
BEGIN
  -- Administrative maintenance retains its existing privileged path.
  IF auth.role() = 'service_role' THEN RETURN NEW; END IF;
  IF actor IS NULL THEN
    RAISE EXCEPTION 'Sign in to manage applications' USING ERRCODE='42501';
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT * INTO vacancy FROM public.jobs WHERE id=NEW.job_id FOR UPDATE;
    IF actor IS DISTINCT FROM NEW.trade_id OR NEW.status <> 'pending'
       OR NEW.builder_id IS DISTINCT FROM vacancy.builder_id
       OR actor = vacancy.builder_id
       OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=actor AND role='trade') THEN
      RAISE EXCEPTION 'Invalid application owner or initial status' USING ERRCODE='42501';
    END IF;
    IF vacancy.id IS NULL OR vacancy.status <> 'open' OR vacancy.deleted_at IS NOT NULL THEN
      RAISE EXCEPTION 'This job is no longer accepting applications' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  IF actor = OLD.builder_id THEN
    IF OLD.status NOT IN ('pending','shortlisted') OR NEW.status NOT IN ('shortlisted','rejected','hired') THEN
      RAISE EXCEPTION 'This application can no longer be changed' USING ERRCODE='23514';
    END IF;
  ELSIF actor = OLD.trade_id THEN
    IF NOT ((OLD.status IN ('pending','shortlisted') AND NEW.status='withdrawn')
       OR (OLD.status='hired' AND NEW.status='declined_by_trade')) THEN
      RAISE EXCEPTION 'Applicants may only withdraw or decline their application' USING ERRCODE='42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'Not a participant in this application' USING ERRCODE='42501';
  END IF;
  IF NEW.status='hired' THEN
    -- The job row lock serialises two concurrent hires for the same vacancy.
    SELECT * INTO vacancy FROM public.jobs WHERE id=NEW.job_id FOR UPDATE;
    IF vacancy.status <> 'open' OR vacancy.deleted_at IS NOT NULL
       OR vacancy.hired_trade_id IS NOT NULL
       OR EXISTS (SELECT 1 FROM public.applications
                  WHERE job_id=NEW.job_id AND status='hired' AND id<>NEW.id) THEN
      RAISE EXCEPTION 'This job is no longer available to hire' USING ERRCODE='23514';
    END IF;
    UPDATE public.jobs SET status='filled', hired_trade_id=NEW.trade_id WHERE id=NEW.job_id;
  ELSIF NEW.status='declined_by_trade' THEN
    UPDATE public.jobs SET status='open', hired_trade_id=NULL
      WHERE id=NEW.job_id AND hired_trade_id=NEW.trade_id AND status='filled' AND deleted_at IS NULL;
  END IF;
  NEW.status_changed_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_application_lifecycle() FROM PUBLIC;
CREATE TRIGGER application_lifecycle_guard BEFORE INSERT OR UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.guard_application_lifecycle();
COMMIT;
