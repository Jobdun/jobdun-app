BEGIN;
DROP TRIGGER IF EXISTS application_lifecycle_guard ON public.applications;
DROP FUNCTION IF EXISTS public.guard_application_lifecycle();
-- Existing assignments are retained. Removing the guard restores the previous
-- client-driven application behavior; use only with a reviewed replacement.
COMMIT;
