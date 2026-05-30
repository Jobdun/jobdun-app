-- supabase/migrations/20260530000001_verifications_display_projection.sql
--
-- STEP 6 — Capture & display verified builder details (see
-- docs/STEP6_VERIFIED_BUILDER_DETAILS.md).
--
-- Two things:
--   1. Three curated DISPLAY columns on `verifications`. The RAW regulator
--      payload stays in verification_events.raw_response (the receipt); these
--      columns are the readable projection both the owner and admin SEE.
--        gst_registered     — whether the ABN is registered for GST (ABR Gst).
--        register_source    — which register produced this row: 'ABR' for ABN,
--                             'admin_manual' for an admin-approved licence, or a
--                             regulator code (e.g. 'NSW_FT') once auto-licence lands.
--        detail_captured_at — the "as at" timestamp. ALWAYS rendered next to a
--                             verified badge, because a business can be cancelled
--                             the day after a check — "Verified" alone would lie.
--
--   2. A minimized, register-derived projection for COUNTERPARTIES (a trade
--      viewing a builder, or vice-versa) exposed as a SECURITY DEFINER function.
--      Why a function and not a security_invoker view: `verifications` RLS is
--      owner-read + admin-read only, so a security_invoker view would re-apply
--      that and a counterparty could never see another user's row. A SECURITY
--      DEFINER function bounded to a handful of already-public register fields is
--      the controlled seam — it never exposes the raw blob, the ABN/licence
--      number, failure reasons, or any internal status.
--
-- RLS: no change to verifications' own policies (owner+admin read, no client
-- write) — the new columns are covered by the existing table-level policies.
-- Reversibility: SAFE — see DOWN block. New columns are NULLable.

-- 1. Curated display columns -------------------------------------------------
ALTER TABLE public.verifications
  ADD COLUMN IF NOT EXISTS gst_registered     boolean,
  ADD COLUMN IF NOT EXISTS register_source    text,
  ADD COLUMN IF NOT EXISTS detail_captured_at timestamptz;

COMMENT ON COLUMN public.verifications.gst_registered IS
  'Whether the ABN is registered for GST (from ABR Gst field). NULL until an '
  'ABN verify runs. Register-derived, public per ABR.';

COMMENT ON COLUMN public.verifications.register_source IS
  'Which register produced this row: ''ABR'' (ABN), ''admin_manual'' (admin-'
  'approved licence), or a regulator code for future auto-licence adapters.';

COMMENT ON COLUMN public.verifications.detail_captured_at IS
  'The "as at" timestamp for the captured details. ALWAYS shown next to a '
  'verified badge so a stale snapshot can never read as a bare "Verified".';

-- Composite index for the admin queue + the projection function's filter.
CREATE INDEX IF NOT EXISTS verifications_kind_status_idx
  ON public.verifications (kind, status);

-- 2. Counterparty projection (minimized, register-derived) -------------------
-- Returns 0..N rows (one per VERIFIED credential the user holds). Presence of a
-- row == verified. Soft-deleted users (builder/trade profile) are excluded.
CREATE OR REPLACE FUNCTION public.get_builder_public_verification(p_user_id uuid)
RETURNS TABLE (
  user_id             uuid,
  kind                text,
  verified_legal_name text,
  gst_registered      boolean,
  licence_class       text,
  licence_status      text,
  detail_captured_at  timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    v.user_id,
    v.kind,
    v.abn_entity_name                                          AS verified_legal_name,
    v.gst_registered,
    v.licence_trade_class                                      AS licence_class,
    CASE WHEN v.expires_at IS NULL OR v.expires_at > now()
         THEN 'current' ELSE 'expired' END                    AS licence_status,
    v.detail_captured_at
  FROM public.verifications v
  LEFT JOIN public.builder_profiles bp ON bp.id = v.user_id
  LEFT JOIN public.trade_profiles   tp ON tp.id = v.user_id
  WHERE v.user_id = p_user_id
    AND v.status  = 'verified'
    AND bp.deleted_at IS NULL   -- NULL when no builder profile (LEFT JOIN) — still passes
    AND tp.deleted_at IS NULL;  -- NULL when no trade profile  — still passes
$$;

COMMENT ON FUNCTION public.get_builder_public_verification(uuid) IS
  'Minimized, register-derived verification projection for counterparty display '
  '(trust badge). SECURITY DEFINER on purpose: exposes ONLY already-public '
  'register fields, never the raw payload / ABN number / failure reasons.';

GRANT EXECUTE ON FUNCTION public.get_builder_public_verification(uuid) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.get_builder_public_verification(uuid) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.get_builder_public_verification(uuid);
-- DROP INDEX IF EXISTS public.verifications_kind_status_idx;
-- ALTER TABLE public.verifications
--   DROP COLUMN IF EXISTS detail_captured_at,
--   DROP COLUMN IF EXISTS register_source,
--   DROP COLUMN IF EXISTS gst_registered;
-- ============================================================================
