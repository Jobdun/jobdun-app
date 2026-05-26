-- supabase/migrations/20260525000001_verifications.sql
-- Phase 1 of the API-first verification rollout.
-- See docs/VERIFICATION_AUDIT.md and docs/VERIFICATION_USER_FLOWS.md.
--
-- Adds:
--   - verification_status enum
--   - verifications              (state machine, one row per (user_id, kind))
--   - verification_events        (append-only audit trail, raw regulator JSONB)
--   - verification_funnel_events (product analytics, user-writable)
--   - manual_verification_requests (replaces "email support" punt)
--   - verification_rate_limits   (per-user / per-IP sliding window)
--   - regulator_circuit_state    (per-regulator circuit breaker state)
--   - applications.applied_when_verified_at  (in-flight semantics, Hole 5)

-- =========================================================================
-- ENUM
-- =========================================================================
DO $$ BEGIN
  CREATE TYPE verification_status AS ENUM (
    'pending', 'verified', 'failed', 'expired', 'suspended', 'manual_review'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================================
-- verifications
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.verifications (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  kind                     text NOT NULL CHECK (kind IN ('abn', 'licence')),

  -- abn fields
  abn                      text,
  abn_entity_name          text,

  -- licence fields
  licence_number           text,
  licence_state            text CHECK (licence_state IN ('NSW','VIC','QLD','SA','WA','TAS','ACT','NT')),
  licence_trade_class      text,

  status                   verification_status NOT NULL DEFAULT 'pending',
  verified_at              timestamptz,
  expires_at               timestamptz,
  last_checked_at          timestamptz,
  failure_reason           text,
  manual_fallback_allowed  boolean NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS verifications_user_idx
  ON public.verifications(user_id);
CREATE INDEX IF NOT EXISTS verifications_status_idx
  ON public.verifications(status) WHERE status IN ('pending','manual_review');
CREATE INDEX IF NOT EXISTS verifications_expiring_idx
  ON public.verifications(expires_at) WHERE status = 'verified';
CREATE INDEX IF NOT EXISTS verifications_recheck_idx
  ON public.verifications(last_checked_at) WHERE status = 'verified';

DROP TRIGGER IF EXISTS verifications_updated_at ON public.verifications;
CREATE TRIGGER verifications_updated_at
  BEFORE UPDATE ON public.verifications
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.verifications IS
  'API-first verification state machine. One row per (user_id, kind). '
  'kind=abn for builders and trades; kind=licence for trades only.';
COMMENT ON COLUMN public.verifications.manual_fallback_allowed IS
  'True only when failure_reason is recoverable (not_found / unknown / timeout). '
  'False for cancelled/suspended — those cannot be overridden by a doc upload.';
COMMENT ON COLUMN public.verifications.abn_entity_name IS
  'Registered entity name from ABR. Stored alongside the user-entered trading '
  'name (builder_profiles.company_name) so both are visible on the badge.';

-- =========================================================================
-- verification_events (audit trail)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.verification_events (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id  uuid NOT NULL REFERENCES public.verifications(id) ON DELETE CASCADE,
  event_type       text NOT NULL CHECK (event_type IN ('api_call','status_change','manual_override')),
  raw_response     jsonb,
  actor_id         uuid REFERENCES public.profiles(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS verification_events_vid_idx
  ON public.verification_events(verification_id, created_at DESC);

COMMENT ON TABLE public.verification_events IS
  'Append-only audit trail. Raw regulator JSONB responses retained for disputes.';

-- =========================================================================
-- verification_funnel_events (product analytics — user-writable)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.verification_funnel_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  step        text NOT NULL,
  metadata    jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS verification_funnel_step_idx
  ON public.verification_funnel_events(step, created_at DESC);

COMMENT ON TABLE public.verification_funnel_events IS
  'Wizard funnel telemetry — wizard_open, abn_entered, abn_verified, licence_entered, '
  'licence_verified, result_failed, result_manual, continue_tap.';

-- =========================================================================
-- manual_verification_requests (replaces "email support" punt)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.manual_verification_requests (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  verification_id  uuid REFERENCES public.verifications(id) ON DELETE SET NULL,
  reason           text NOT NULL,
  status           text NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open','in_progress','resolved','rejected')),
  notes            text,
  resolved_by      uuid REFERENCES public.profiles(id),
  resolved_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS manual_verif_requests_open_idx
  ON public.manual_verification_requests(created_at DESC) WHERE status = 'open';

COMMENT ON TABLE public.manual_verification_requests IS
  'Queue for failures the API path cannot recover from automatically — '
  'builder ABN issues, regulator outages, circuit-breaker-open routes.';

-- =========================================================================
-- verification_rate_limits (per-user + per-IP sliding window)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.verification_rate_limits (
  bucket_key    text NOT NULL,
  endpoint      text NOT NULL CHECK (endpoint IN ('verify-abn','verify-licence')),
  window_start  timestamptz NOT NULL,
  attempt_count int NOT NULL DEFAULT 1,
  PRIMARY KEY (bucket_key, endpoint, window_start)
);

CREATE INDEX IF NOT EXISTS rate_limits_lookup_idx
  ON public.verification_rate_limits(bucket_key, endpoint, window_start DESC);

COMMENT ON TABLE public.verification_rate_limits IS
  'bucket_key is "user:<uuid>" or "ip:<addr>". Service-role-only writes.';

-- =========================================================================
-- regulator_circuit_state (per-regulator circuit breaker)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.regulator_circuit_state (
  regulator        text PRIMARY KEY,
  state            text NOT NULL DEFAULT 'closed'
                     CHECK (state IN ('closed','open','half_open')),
  failure_count    int NOT NULL DEFAULT 0,
  success_count    int NOT NULL DEFAULT 0,
  window_started_at timestamptz NOT NULL DEFAULT now(),
  opened_at        timestamptz,
  last_attempt_at  timestamptz,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.regulator_circuit_state IS
  'One row per regulator (ABR, NSW, VIC, ...). state=open routes new requests '
  'straight to manual_review without calling the regulator.';

-- Seed one row per regulator so increment/decrement is always an UPDATE.
INSERT INTO public.regulator_circuit_state (regulator)
VALUES ('ABR'), ('NSW'), ('VIC'), ('QLD'), ('SA'), ('WA'), ('TAS'), ('ACT'), ('NT')
ON CONFLICT (regulator) DO NOTHING;

-- =========================================================================
-- applications additive column (Hole 5)
-- =========================================================================
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS applied_when_verified_at timestamptz;

COMMENT ON COLUMN public.applications.applied_when_verified_at IS
  'Stamp captured at submit-time. Non-null means the trade''s verification was '
  'currently active when they applied — kept even if the licence later expires.';

-- =========================================================================
-- RLS
-- =========================================================================
ALTER TABLE public.verifications                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_events          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_funnel_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.manual_verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_rate_limits     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.regulator_circuit_state      ENABLE ROW LEVEL SECURITY;

-- verifications -----------------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "verifications_owner_read"
    ON public.verifications FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verifications_admin_read"
    ON public.verifications FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- No client writes — service-role Edge Functions only.
DO $$ BEGIN
  CREATE POLICY "verifications_no_client_insert"
    ON public.verifications FOR INSERT
    WITH CHECK (false);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verifications_no_client_update"
    ON public.verifications FOR UPDATE
    USING (false);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verifications_no_client_delete"
    ON public.verifications FOR DELETE
    USING (false);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- verification_events -----------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "verification_events_owner_read"
    ON public.verification_events FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.verifications v
      WHERE v.id = verification_events.verification_id
        AND v.user_id = auth.uid()
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verification_events_admin_read"
    ON public.verification_events FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verification_events_no_client_insert"
    ON public.verification_events FOR INSERT
    WITH CHECK (false);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- verification_funnel_events: clients CAN insert their own rows (product analytics)
DO $$ BEGIN
  CREATE POLICY "verification_funnel_insert_own"
    ON public.verification_funnel_events FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "verification_funnel_admin_read"
    ON public.verification_funnel_events FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- manual_verification_requests -------------------------------------------
DO $$ BEGIN
  CREATE POLICY "mvr_owner_read"
    ON public.manual_verification_requests FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "mvr_admin_read"
    ON public.manual_verification_requests FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "mvr_no_client_insert"
    ON public.manual_verification_requests FOR INSERT
    WITH CHECK (false);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- verification_rate_limits and regulator_circuit_state: service-role only.
-- No SELECT/INSERT/UPDATE policies for authenticated callers — RLS is enabled
-- and no policies means default-deny for non-service-role.
