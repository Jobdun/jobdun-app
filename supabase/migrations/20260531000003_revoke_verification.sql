-- supabase/migrations/20260531000003_revoke_verification.sql
--
-- AUDIT FIX B4 — admin "revoke verification" action.
--
-- Today a wrongly-verified ABN (A1) or wrong licence (A2) cannot be cleared
-- from the app: verifications is service-role-write-only (RLS forbids client
-- insert/update/delete), and there is no privileged un-verify path. This RPC
-- gives Trust & Safety a reversible way to mark a verified row failed.
--
-- It flips the latest verified row for (user, kind) to status='failed' with a
-- machine-readable failure_reason ('admin_revoked: <reason>') and re-opens the
-- manual fallback so the user can re-submit. The trade_is_verified_sync trigger
-- recomputes trade_profiles.is_verified automatically on the UPDATE, so every
-- cross-user surface corrects itself. The user is notified via the existing
-- 'verification_rejected' channel, and the action is audited.
--
-- Admin gate mirrors review_verification_document / log_admin_action.
-- Reversibility: SAFE — see DOWN block.

CREATE OR REPLACE FUNCTION public.revoke_verification(
  p_user_id uuid,
  p_kind    text,
  p_reason  text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  IF p_kind NOT IN ('abn', 'licence') THEN
    RAISE EXCEPTION 'invalid_kind: %', p_kind;
  END IF;

  -- Latest verified row for this (user, kind). "Latest" matches the
  -- select-then-upsert convention used elsewhere (no UNIQUE(user_id, kind)).
  SELECT id INTO v_id
    FROM public.verifications
   WHERE user_id = p_user_id
     AND kind    = p_kind
     AND status  = 'verified'
   ORDER BY updated_at DESC
   LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'no_verified_row';
  END IF;

  UPDATE public.verifications
     SET status                  = 'failed',
         failure_reason          = 'admin_revoked: ' || COALESCE(p_reason, ''),
         manual_fallback_allowed = true,
         updated_at              = now()
   WHERE id = v_id;

  -- Reuse the 'verification_rejected' channel the app already understands so
  -- the revoked user is told and pointed back at the re-upload surface.
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_user_id,
    'verification_rejected',
    'Verification revoked',
    'Your ' || p_kind || ' verification was revoked'
      || CASE WHEN COALESCE(btrim(p_reason), '') <> ''
              THEN ': ' || btrim(p_reason)
              ELSE '.' END
      || ' Tap to re-verify.',
    jsonb_build_object('kind', p_kind, 'reason', p_reason)
  );

  PERFORM public.log_admin_action(
    'revoke_verification',
    'verifications',
    v_id,
    jsonb_build_object('kind', p_kind, 'reason', p_reason)
  );
END;
$$;

COMMENT ON FUNCTION public.revoke_verification(uuid, text, text) IS
  'Admin un-verify: flips the latest verified (user, kind) row to failed with '
  'failure_reason "admin_revoked: <reason>" and re-opens manual fallback. '
  'Notifies the user and audits via log_admin_action. The is_verified trigger '
  'recomputes cross-user surfaces automatically.';

GRANT EXECUTE ON FUNCTION public.revoke_verification(uuid, text, text) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.revoke_verification(uuid, text, text) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.revoke_verification(uuid, text, text);
-- ============================================================================
