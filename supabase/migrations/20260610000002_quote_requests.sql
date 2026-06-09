-- 20260610000002_quote_requests.sql
-- #18 standalone quote requests: a BUILDER-initiated request to a specific
-- trade for a job, distinct from the trade's quote_amount on an application
-- (which is trade-initiated, attached to an application). The builder asks; the
-- trade responds with a price + note, or declines. "Accept → invoice" rides
-- with the payments rail (Rail C) — not part of this migration.

DO $$ BEGIN
  CREATE TYPE public.quote_request_status AS ENUM
    ('requested', 'quoted', 'declined', 'accepted', 'withdrawn');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.quote_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        uuid NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  builder_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trade_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status        public.quote_request_status NOT NULL DEFAULT 'requested',
  request_note  text,
  quote_amount  numeric,
  response_note text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  responded_at  timestamptz,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (job_id, trade_id)
);

CREATE INDEX IF NOT EXISTS quote_requests_trade_idx
  ON public.quote_requests (trade_id);
CREATE INDEX IF NOT EXISTS quote_requests_builder_idx
  ON public.quote_requests (builder_id);

ALTER TABLE public.quote_requests ENABLE ROW LEVEL SECURITY;

-- Builder (requester) owns the row: insert / read / withdraw. The WITH CHECK
-- also confirms the builder owns the job being quoted, so a builder can't
-- request quotes against someone else's listing.
DROP POLICY IF EXISTS quote_requests_builder_all ON public.quote_requests;
CREATE POLICY quote_requests_builder_all ON public.quote_requests
  FOR ALL TO authenticated
  USING (builder_id = auth.uid())
  WITH CHECK (
    builder_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.jobs j
      WHERE j.id = job_id AND j.builder_id = auth.uid()
    )
  );

-- Trade (recipient) can read requests addressed to them and respond (update).
DROP POLICY IF EXISTS quote_requests_trade_select ON public.quote_requests;
CREATE POLICY quote_requests_trade_select ON public.quote_requests
  FOR SELECT TO authenticated USING (trade_id = auth.uid());

DROP POLICY IF EXISTS quote_requests_trade_update ON public.quote_requests;
CREATE POLICY quote_requests_trade_update ON public.quote_requests
  FOR UPDATE TO authenticated
  USING (trade_id = auth.uid())
  WITH CHECK (trade_id = auth.uid());

-- Keep updated_at fresh (reuses the project's set_updated_at() convention if
-- present; defined inline here so this migration is self-contained).
CREATE OR REPLACE FUNCTION public.quote_requests_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS quote_requests_touch_updated_at_trg ON public.quote_requests;
CREATE TRIGGER quote_requests_touch_updated_at_trg
  BEFORE UPDATE ON public.quote_requests
  FOR EACH ROW EXECUTE FUNCTION public.quote_requests_touch_updated_at();

COMMENT ON TABLE public.quote_requests IS
  '#18 builder-initiated quote requests to a specific trade for a job. '
  'Builder owns the row + must own the job; trade reads + responds. '
  'Notification fan-out + accept→invoice (payments) are follow-ups.';
