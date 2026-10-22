-- Application history outlives public job visibility. Keep jobs RLS unchanged
-- and expose only these summary fields to a participant in an application.
BEGIN;

CREATE VIEW public.application_job_summaries
WITH (security_barrier = true, security_invoker = false) AS
SELECT
  j.id,
  j.title,
  j.suburb,
  j.state,
  j.status,
  j.budget_amount,
  j.pricing_unit,
  j.pricing_type,
  j.job_kind,
  j.open_to_apprentices
FROM public.jobs AS j
WHERE (SELECT auth.uid()) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.applications AS a
    WHERE a.job_id = j.id
      AND (SELECT auth.uid()) IN (a.builder_id, a.trade_id)
  );

-- Owner execution is intentional: jobs RLS hides historical listings from
-- applicants. The explicit participant predicate above is the access gate;
-- the barrier prevents caller predicates from inspecting excluded rows.
ALTER VIEW public.application_job_summaries OWNER TO postgres;
REVOKE ALL ON public.application_job_summaries
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.application_job_summaries TO authenticated;
COMMENT ON VIEW public.application_job_summaries IS
  'Read-only job summaries for application participants, including closed, cancelled and soft-deleted jobs. Excludes description, precise location and contact details; does not expand jobs RLS.';

NOTIFY pgrst, 'reload schema';
COMMIT;
