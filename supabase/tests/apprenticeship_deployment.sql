-- Read-only verification safe for the linked production database.
BEGIN;
SELECT column_name FROM information_schema.columns
 WHERE table_schema='public' AND table_name='jobs' AND column_name='job_kind';
SELECT conname FROM pg_constraint WHERE conrelid='public.jobs'::regclass
 AND conname IN ('jobs_kind_valid','jobs_apprenticeship_terms');
SELECT tgname,tgenabled FROM pg_trigger WHERE tgrelid='public.applications'::regclass
 AND tgname='application_lifecycle_guard';
SET LOCAL ROLE anon;
SELECT id, job_kind, open_to_apprentices, budget_amount, pricing_unit,
 requires_public_liability, start_date FROM public.jobs_public_browse
 WHERE job_kind='apprenticeship' AND open_to_apprentices LIMIT 0;
ROLLBACK;
