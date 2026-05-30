-- supabase/migrations/20260530000003_review_verification_document.sql
--
-- STEP 6 — admin review of a manual verification document, atomically.
--
-- The bug this closes: today the admin web app flips
-- verification_documents.status='approved' and nothing downstream changes,
-- because the whole app reads "is this user verified?" from `verifications` —
-- which never gets a row. So an approved licence stays invisible: no profile
-- badge, no counterparty trust signal, no admin reflection.
--
-- This SECURITY DEFINER RPC does the review in one transaction:
--   1. updates the document (status / reviewed_by / reviewed_at / notes)
--   2. on APPROVAL of a core credential doc, UPSERTS the verified
--      `verifications` row (manual path — works for ALL 8 states, no per-state
--      adapter; register_source='admin_manual', detail_captured_at=now()).
--      verifications is service-role-write-only, so this must be SECURITY
--      DEFINER — an admin's anon-key UPDATE can't reach it.
--   3. writes an admin_actions audit row.
--
-- The existing trade_is_verified_sync trigger then mirrors a verified licence
-- into trade_profiles.is_verified automatically.
--
-- No UNIQUE(user_id, kind) exists on verifications (the invariant is enforced
-- in app code), so we select-then-upsert rather than ON CONFLICT.
-- Reversibility: SAFE — see DOWN block.

CREATE OR REPLACE FUNCTION public.review_verification_document(
  p_document_id uuid,
  p_status      text,
  p_notes       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_doc      public.verification_documents%ROWTYPE;
  v_kind     text;
  v_existing uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'invalid_status: %', p_status;
  END IF;

  UPDATE public.verification_documents
     SET status       = p_status,
         reviewed_at  = now(),
         reviewed_by  = auth.uid(),
         review_notes = COALESCE(NULLIF(btrim(p_notes), ''), review_notes)
   WHERE id = p_document_id
   RETURNING * INTO v_doc;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'document_not_found';
  END IF;

  -- On approval of a CORE credential doc, promote to a verified verifications
  -- row so the status is visible everywhere. Supplementary docs (public
  -- liability, white card, photo id, …) approve but do not create a row.
  IF p_status = 'approved' THEN
    v_kind := CASE v_doc.doc_type
                WHEN 'trade_licence'   THEN 'licence'
                WHEN 'abn_certificate' THEN 'abn'
                ELSE NULL
              END;

    IF v_kind IS NOT NULL THEN
      SELECT id INTO v_existing
        FROM public.verifications
       WHERE user_id = v_doc.trade_id AND kind = v_kind
       ORDER BY updated_at DESC
       LIMIT 1;

      IF v_existing IS NULL THEN
        INSERT INTO public.verifications (
          user_id, kind, status,
          licence_number, licence_state,
          register_source, detail_captured_at, verified_at, expires_at,
          manual_fallback_allowed, last_checked_at, failure_reason
        ) VALUES (
          v_doc.trade_id, v_kind, 'verified',
          CASE WHEN v_kind = 'licence' THEN v_doc.document_number END,
          CASE WHEN v_kind = 'licence' THEN v_doc.state END,
          'admin_manual', now(), now(), v_doc.expiry_date,
          false, now(), NULL
        );
      ELSE
        UPDATE public.verifications
           SET status                  = 'verified',
               licence_number          = CASE WHEN v_kind = 'licence' THEN v_doc.document_number ELSE licence_number END,
               licence_state           = CASE WHEN v_kind = 'licence' THEN v_doc.state ELSE licence_state END,
               register_source         = 'admin_manual',
               detail_captured_at      = now(),
               verified_at             = now(),
               expires_at              = v_doc.expiry_date,
               failure_reason          = NULL,
               manual_fallback_allowed = false,
               last_checked_at         = now(),
               updated_at              = now()
         WHERE id = v_existing;
      END IF;
    END IF;
  END IF;

  PERFORM public.log_admin_action(
    'review_verification_document',
    'verification_documents',
    p_document_id,
    jsonb_build_object('status', p_status, 'promoted_kind', v_kind)
  );
END;
$$;

COMMENT ON FUNCTION public.review_verification_document(uuid, text, text) IS
  'Admin reviews a manual verification doc atomically: updates the doc, and on '
  'approval of a licence/abn doc upserts the verified verifications row '
  '(manual path, all states). Audited via log_admin_action.';

GRANT EXECUTE ON FUNCTION public.review_verification_document(uuid, text, text) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.review_verification_document(uuid, text, text) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.review_verification_document(uuid, text, text);
-- ============================================================================
