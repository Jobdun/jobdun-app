-- supabase/migrations/20260531000002_review_verification_document_v2.sql
--
-- AUDIT FIXES A2, A3, B2 — admin review captures the confirmed identifier +
-- trade class, and ALWAYS notifies the trade on approve/reject.
--
-- The original 3-arg review_verification_document (20260530000003) trusted the
-- user-TYPED licence/ABN number (A2) and never captured a trade class (A3), and
-- emitted no notification at all (B2) — so an approved OR rejected trade got
-- zero signal that their status changed.
--
-- This migration REPLACES it with a 5-arg version. Because adding the two new
-- DEFAULT NULL params changes the function signature, we DROP the 3-arg form
-- first (a CREATE OR REPLACE can't widen the arg list without an explicit drop)
-- and CREATE the 5-arg form. All existing behaviour is preserved:
--   * admin gate via user_roles
--   * status IN ('approved','rejected')
--   * doc row update (status / reviewed_by / reviewed_at / review_notes)
--   * on approval of a trade_licence/abn_certificate doc, select-then-upsert
--     the verified verifications row (manual path, all states)
--   * log_admin_action audit row
-- CHANGES:
--   * The verified LICENCE row now prefers the reviewer-confirmed number and
--     trade class (p_confirmed_number / p_trade_class) over the typed values,
--     falling back to the document's own fields when blank.
--   * The verified ABN row prefers the reviewer-confirmed ABN.
--   * On BOTH approve and reject we insert a notification the app already
--     understands ('verification_approved' / 'verification_rejected').
--
-- The trade_is_verified_sync trigger still mirrors a verified licence into
-- trade_profiles.is_verified automatically on the upsert.
-- Reversibility: SAFE — DOWN drops the 5-arg and recreates the 3-arg verbatim.

-- A CREATE OR REPLACE cannot add parameters to an existing function, so drop
-- the old signature explicitly before creating the new one.
DROP FUNCTION IF EXISTS public.review_verification_document(uuid, text, text);

CREATE FUNCTION public.review_verification_document(
  p_document_id      uuid,
  p_status           text,
  p_notes            text DEFAULT NULL,
  p_confirmed_number text DEFAULT NULL,
  p_trade_class      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_doc       public.verification_documents%ROWTYPE;
  v_kind      text;
  v_existing  uuid;
  v_doc_label text;
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
          abn, licence_number, licence_state, licence_trade_class,
          register_source, detail_captured_at, verified_at, expires_at,
          manual_fallback_allowed, last_checked_at, failure_reason
        ) VALUES (
          v_doc.trade_id, v_kind, 'verified',
          -- abn: reviewer-confirmed value wins, else the typed document number.
          CASE WHEN v_kind = 'abn'
               THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
          END,
          -- licence_number: reviewer-confirmed value wins, else typed number.
          CASE WHEN v_kind = 'licence'
               THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
          END,
          CASE WHEN v_kind = 'licence' THEN v_doc.state END,
          -- licence_trade_class: reviewer-confirmed class wins, else the class
          -- captured on the document at upload time.
          CASE WHEN v_kind = 'licence'
               THEN COALESCE(NULLIF(btrim(p_trade_class), ''), v_doc.trade_class)
          END,
          'admin_manual', now(), now(), v_doc.expiry_date,
          false, now(), NULL
        );
      ELSE
        UPDATE public.verifications
           SET status                  = 'verified',
               abn                     = CASE WHEN v_kind = 'abn'
                                              THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
                                              ELSE abn END,
               licence_number          = CASE WHEN v_kind = 'licence'
                                              THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
                                              ELSE licence_number END,
               licence_state           = CASE WHEN v_kind = 'licence' THEN v_doc.state ELSE licence_state END,
               licence_trade_class     = CASE WHEN v_kind = 'licence'
                                              THEN COALESCE(NULLIF(btrim(p_trade_class), ''), v_doc.trade_class)
                                              ELSE licence_trade_class END,
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

  -- ALWAYS notify the trade — approve OR reject. The app already understands
  -- these type strings ('verification_approved' / 'verification_rejected') and
  -- routes the tap to the receipts / re-upload surface. Without this, an
  -- approved or rejected trade gets no signal that their status changed (B2).
  v_doc_label := CASE v_doc.doc_type
                   WHEN 'trade_licence'        THEN 'trade licence'
                   WHEN 'abn_certificate'      THEN 'ABN certificate'
                   WHEN 'public_liability'     THEN 'public liability cover'
                   WHEN 'workers_compensation' THEN 'workers compensation cover'
                   WHEN 'white_card'           THEN 'white card'
                   WHEN 'photo_id'             THEN 'photo ID'
                   ELSE 'document'
                 END;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_doc.trade_id,
    CASE WHEN p_status = 'approved' THEN 'verification_approved' ELSE 'verification_rejected' END,
    CASE WHEN p_status = 'approved'
         THEN 'You''re verified'
         ELSE 'Verification needs another look' END,
    CASE WHEN p_status = 'approved'
         THEN 'Your ' || v_doc_label || ' was approved.'
         ELSE 'Your ' || v_doc_label || ' wasn''t approved — tap to re-upload.' END,
    jsonb_build_object(
      'doc_type',    v_doc.doc_type,
      'kind',        v_kind,
      'document_id', p_document_id
    )
  );

  PERFORM public.log_admin_action(
    'review_verification_document',
    'verification_documents',
    p_document_id,
    jsonb_build_object('status', p_status, 'promoted_kind', v_kind)
  );
END;
$$;

COMMENT ON FUNCTION public.review_verification_document(uuid, text, text, text, text) IS
  'Admin reviews a manual verification doc atomically: updates the doc, and on '
  'approval of a licence/abn doc upserts the verified verifications row '
  '(manual path, all states) using the reviewer-confirmed number/class when '
  'supplied. ALWAYS notifies the trade on approve/reject. Audited via '
  'log_admin_action.';

GRANT EXECUTE ON FUNCTION public.review_verification_document(uuid, text, text, text, text) TO authenticated;

-- ============================================================================
-- DOWN MIGRATION (reversible) — drops the 5-arg form and recreates the
-- original 3-arg version verbatim (copied from 20260530000003).
-- ============================================================================
-- REVOKE EXECUTE ON FUNCTION public.review_verification_document(uuid, text, text, text, text) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.review_verification_document(uuid, text, text, text, text);
--
-- CREATE OR REPLACE FUNCTION public.review_verification_document(
--   p_document_id uuid,
--   p_status      text,
--   p_notes       text DEFAULT NULL
-- )
-- RETURNS void
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = ''
-- AS $$
-- DECLARE
--   v_doc      public.verification_documents%ROWTYPE;
--   v_kind     text;
--   v_existing uuid;
-- BEGIN
--   IF NOT EXISTS (
--     SELECT 1 FROM public.user_roles
--     WHERE user_id = auth.uid() AND role = 'admin'
--   ) THEN
--     RAISE EXCEPTION 'not_admin' USING errcode = '42501';
--   END IF;
--
--   IF p_status NOT IN ('approved', 'rejected') THEN
--     RAISE EXCEPTION 'invalid_status: %', p_status;
--   END IF;
--
--   UPDATE public.verification_documents
--      SET status       = p_status,
--          reviewed_at  = now(),
--          reviewed_by  = auth.uid(),
--          review_notes = COALESCE(NULLIF(btrim(p_notes), ''), review_notes)
--    WHERE id = p_document_id
--    RETURNING * INTO v_doc;
--
--   IF v_doc.id IS NULL THEN
--     RAISE EXCEPTION 'document_not_found';
--   END IF;
--
--   IF p_status = 'approved' THEN
--     v_kind := CASE v_doc.doc_type
--                 WHEN 'trade_licence'   THEN 'licence'
--                 WHEN 'abn_certificate' THEN 'abn'
--                 ELSE NULL
--               END;
--
--     IF v_kind IS NOT NULL THEN
--       SELECT id INTO v_existing
--         FROM public.verifications
--        WHERE user_id = v_doc.trade_id AND kind = v_kind
--        ORDER BY updated_at DESC
--        LIMIT 1;
--
--       IF v_existing IS NULL THEN
--         INSERT INTO public.verifications (
--           user_id, kind, status,
--           licence_number, licence_state,
--           register_source, detail_captured_at, verified_at, expires_at,
--           manual_fallback_allowed, last_checked_at, failure_reason
--         ) VALUES (
--           v_doc.trade_id, v_kind, 'verified',
--           CASE WHEN v_kind = 'licence' THEN v_doc.document_number END,
--           CASE WHEN v_kind = 'licence' THEN v_doc.state END,
--           'admin_manual', now(), now(), v_doc.expiry_date,
--           false, now(), NULL
--         );
--       ELSE
--         UPDATE public.verifications
--            SET status                  = 'verified',
--                licence_number          = CASE WHEN v_kind = 'licence' THEN v_doc.document_number ELSE licence_number END,
--                licence_state           = CASE WHEN v_kind = 'licence' THEN v_doc.state ELSE licence_state END,
--                register_source         = 'admin_manual',
--                detail_captured_at      = now(),
--                verified_at             = now(),
--                expires_at              = v_doc.expiry_date,
--                failure_reason          = NULL,
--                manual_fallback_allowed = false,
--                last_checked_at         = now(),
--                updated_at              = now()
--          WHERE id = v_existing;
--       END IF;
--     END IF;
--   END IF;
--
--   PERFORM public.log_admin_action(
--     'review_verification_document',
--     'verification_documents',
--     p_document_id,
--     jsonb_build_object('status', p_status, 'promoted_kind', v_kind)
--   );
-- END;
-- $$;
--
-- COMMENT ON FUNCTION public.review_verification_document(uuid, text, text) IS
--   'Admin reviews a manual verification doc atomically: updates the doc, and on '
--   'approval of a licence/abn doc upserts the verified verifications row '
--   '(manual path, all states). Audited via log_admin_action.';
--
-- GRANT EXECUTE ON FUNCTION public.review_verification_document(uuid, text, text) TO authenticated;
-- ============================================================================
