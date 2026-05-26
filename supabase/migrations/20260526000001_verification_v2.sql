-- supabase/migrations/20260526000001_verification_v2.sql
-- v2 pivot: verification becomes an OPTIONAL receipts model, not a gate.
-- See docs/VERIFICATION_USER_FLOWS.md and the v2 spec captured in conversation.
--
-- Adds:
--   - builder_unverified_acknowledgements (one-time "include unverified" consent)
--   - applications.verification_snapshot_at_hire jsonb (stamped on accept)
--   - reviews.reviewee_verification_snapshot jsonb   (copied at review write)

-- =========================================================================
-- builder_unverified_acknowledgements
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.builder_unverified_acknowledgements (
  builder_id      uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  acknowledged_at timestamptz NOT NULL DEFAULT now(),
  app_version     text
);

COMMENT ON TABLE public.builder_unverified_acknowledgements IS
  'One-time consent that the builder understands the risk of including '
  'unverified workers in their applicant filter. Immutable record per builder.';

-- =========================================================================
-- applications.verification_snapshot_at_hire (hire-time stamp)
-- =========================================================================
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS verification_snapshot_at_hire jsonb;

COMMENT ON COLUMN public.applications.verification_snapshot_at_hire IS
  'Captured at the moment status flips to ''accepted''. Shape: '
  '{"abn":"verified|none|expired","licence":"verified|none|expired|cancelled|suspended",'
  '"licence_state":"NSW|VIC|...","as_of":"<iso>"}. Immutable in practice.';

-- =========================================================================
-- reviews.reviewee_verification_snapshot (copied from application at write time)
-- =========================================================================
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS reviewee_verification_snapshot jsonb;

COMMENT ON COLUMN public.reviews.reviewee_verification_snapshot IS
  'Copied from applications.verification_snapshot_at_hire at review-write time. '
  'Surfaces "verified at hire" / "not verified at hire" subtitle in the review UI.';

-- =========================================================================
-- RLS for builder_unverified_acknowledgements
-- =========================================================================
ALTER TABLE public.builder_unverified_acknowledgements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "buak_owner_read"
    ON public.builder_unverified_acknowledgements FOR SELECT
    USING (auth.uid() = builder_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "buak_owner_insert"
    ON public.builder_unverified_acknowledgements FOR INSERT
    WITH CHECK (auth.uid() = builder_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "buak_admin_read"
    ON public.builder_unverified_acknowledgements FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- No UPDATE / DELETE policies — consent is immutable.
