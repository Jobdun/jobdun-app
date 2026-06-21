-- DOWN for 20260612000001. Run manually only.
BEGIN;
ALTER TABLE public.blocks  DROP CONSTRAINT IF EXISTS blocks_no_self_block;
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_no_self_report;
DROP INDEX IF EXISTS public.reports_one_pending_per_conversation;
DROP POLICY IF EXISTS "reports_insert_own" ON public.reports;
CREATE POLICY "reports_insert_own" ON public.reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);
COMMIT;
