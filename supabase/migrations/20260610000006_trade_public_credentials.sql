-- supabase/migrations/20260610000006_trade_public_credentials.sql
--
-- Trade trust-layer — counterparty projection for APPROVED supplementary
-- credentials (White Card, public liability).
--
-- White Card and public liability live in `verification_documents` (owner-only
-- RLS) and, unlike a trade licence / ABN, are deliberately NOT promoted to a
-- `verifications` row on approval (see review_verification_document v2:
-- "Supplementary docs … approve but do not create a row"). So a builder has no
-- way to see that a tradie holds them.
--
-- This adds a minimized, counterparty-safe projection exposed as a SECURITY
-- DEFINER function — the same controlled seam as get_builder_public_verification.
-- Why DEFINER and not a security_invoker view: verification_documents RLS is
-- owner-read only, so a counterparty could never read another user's rows. The
-- function is bounded to: which credential, whether it has lapsed, and the
-- "as at" approval date. It NEVER exposes the storage url, the card/policy
-- number, the insurer, the state, or any review notes.
--
-- Marketplace posture: these are TRUST SIGNALS (badges), never gates — nothing
-- here blocks apply/hire. Manual review only; no regulator check is implied.
--
-- Reversibility: SAFE — function-only, no schema change. See the DOWN block /
-- supabase/rollbacks/20260610000006_trade_public_credentials_down.sql.

CREATE OR REPLACE FUNCTION public.get_trade_public_credentials(p_user_id uuid)
RETURNS TABLE (
  user_id           uuid,
  doc_type          text,
  expires_at        date,
  credential_status text,
  captured_at       timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    vd.trade_id    AS user_id,
    vd.doc_type,
    vd.expiry_date AS expires_at,
    CASE WHEN vd.expiry_date IS NULL OR vd.expiry_date >= current_date
         THEN 'current' ELSE 'expired' END AS credential_status,
    vd.reviewed_at AS captured_at
  FROM public.verification_documents vd
  LEFT JOIN public.trade_profiles tp ON tp.id = vd.trade_id
  WHERE vd.trade_id = p_user_id
    AND vd.status   = 'approved'
    AND vd.doc_type IN ('white_card', 'public_liability')
    AND tp.deleted_at IS NULL;  -- NULL when no trade profile — still passes
$$;

COMMENT ON FUNCTION public.get_trade_public_credentials(uuid) IS
  'Minimized counterparty projection of a tradie''s APPROVED supplementary '
  'credentials (white_card, public_liability). SECURITY DEFINER on purpose: '
  'exposes ONLY the credential type, lapsed-or-not, and the as-at approval '
  'date — never the document url, number, insurer, state, or review notes.';

GRANT EXECUTE ON FUNCTION public.get_trade_public_credentials(uuid) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible — keep in sync if the UP changes)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.get_trade_public_credentials(uuid) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.get_trade_public_credentials(uuid);
-- ============================================================================
