-- 20260610000004_timesheets.sql
-- #16 timesheets: a hired trade clocks on/off a job, capturing the time and
-- (optionally) GPS coordinates at each end. The builder can see the entries for
-- their jobs. Feeds the (future, payments-gated) earnings dashboard.

CREATE TABLE IF NOT EXISTS public.timesheets (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        uuid NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  builder_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trade_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  check_in_at   timestamptz NOT NULL DEFAULT now(),
  check_out_at  timestamptz,
  check_in_lat  double precision,
  check_in_lng  double precision,
  check_out_lat double precision,
  check_out_lng double precision,
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS timesheets_trade_idx ON public.timesheets (trade_id);
CREATE INDEX IF NOT EXISTS timesheets_job_idx ON public.timesheets (job_id);

ALTER TABLE public.timesheets ENABLE ROW LEVEL SECURITY;

-- The trade owns their own timesheets: clock on (insert), clock off (update),
-- read. Only their own rows.
DROP POLICY IF EXISTS timesheets_trade_all ON public.timesheets;
CREATE POLICY timesheets_trade_all ON public.timesheets
  FOR ALL TO authenticated
  USING (trade_id = auth.uid())
  WITH CHECK (trade_id = auth.uid());

-- The builder can read timesheets logged against their jobs.
DROP POLICY IF EXISTS timesheets_builder_select ON public.timesheets;
CREATE POLICY timesheets_builder_select ON public.timesheets
  FOR SELECT TO authenticated USING (builder_id = auth.uid());

COMMENT ON TABLE public.timesheets IS
  '#16 timesheets: trade clock-on/off per job with optional GPS. Trade owns '
  'their rows; builder reads entries on their jobs. Feeds future earnings.';
