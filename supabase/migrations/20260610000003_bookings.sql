-- 20260610000003_bookings.sql
-- #15 scheduling: once a builder hires a trade for a job, they schedule the
-- work on a date. Both parties see their bookings on a calendar. Distinct from
-- the job lifecycle (a job can have a booking once someone is hired).

DO $$ BEGIN
  CREATE TYPE public.booking_status AS ENUM
    ('scheduled', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.bookings (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id         uuid NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  builder_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trade_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scheduled_date date NOT NULL,
  note           text,
  status         public.booking_status NOT NULL DEFAULT 'scheduled',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bookings_builder_idx ON public.bookings (builder_id);
CREATE INDEX IF NOT EXISTS bookings_trade_idx ON public.bookings (trade_id);
CREATE INDEX IF NOT EXISTS bookings_date_idx ON public.bookings (scheduled_date);

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Builder (job owner) creates / edits / cancels; must own the job.
DROP POLICY IF EXISTS bookings_builder_all ON public.bookings;
CREATE POLICY bookings_builder_all ON public.bookings
  FOR ALL TO authenticated
  USING (builder_id = auth.uid())
  WITH CHECK (
    builder_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.jobs j
      WHERE j.id = job_id AND j.builder_id = auth.uid()
    )
  );

-- Trade can see bookings made for them and mark progress (update status).
DROP POLICY IF EXISTS bookings_trade_select ON public.bookings;
CREATE POLICY bookings_trade_select ON public.bookings
  FOR SELECT TO authenticated USING (trade_id = auth.uid());

DROP POLICY IF EXISTS bookings_trade_update ON public.bookings;
CREATE POLICY bookings_trade_update ON public.bookings
  FOR UPDATE TO authenticated
  USING (trade_id = auth.uid())
  WITH CHECK (trade_id = auth.uid());

CREATE OR REPLACE FUNCTION public.bookings_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS bookings_touch_updated_at_trg ON public.bookings;
CREATE TRIGGER bookings_touch_updated_at_trg
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.bookings_touch_updated_at();

COMMENT ON TABLE public.bookings IS
  '#15 scheduling: a builder schedules a hired trade for a job on a date. '
  'Builder owns + must own the job; trade reads + can update status.';
