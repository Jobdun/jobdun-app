-- supabase/migrations/20260531000001_verification_documents_trade_class.sql
--
-- AUDIT FIX A3 — capture trade_class on a manually-uploaded licence document.
--
-- Today the manual upload sheet never captures the licence trade class, so an
-- approved manual licence row lands with verifications.licence_trade_class =
-- NULL. The counterparty projection (get_builder_public_verification) then
-- renders a blank licence_class. The auto licence step already collects a
-- trade class; the manual path should too.
--
-- This is the storage seam: the mobile manual-upload form writes the captured
-- class here, and review_verification_document (next migration) copies it onto
-- the verified verifications row at approval time. Additive, nullable, no
-- backfill needed (existing rows simply stay NULL, matching today's behaviour).
-- Reversibility: SAFE — see DOWN block.

ALTER TABLE public.verification_documents
  ADD COLUMN IF NOT EXISTS trade_class text;

COMMENT ON COLUMN public.verification_documents.trade_class IS
  'Trade class captured at manual licence upload (e.g. "Carpentry", '
  '"Electrical"). Copied onto verifications.licence_trade_class when the '
  'document is approved so the counterparty badge can render the class.';

-- ============================================================================
-- DOWN MIGRATION (reversible)
-- ============================================================================
-- ALTER TABLE public.verification_documents DROP COLUMN IF EXISTS trade_class;
-- ============================================================================
