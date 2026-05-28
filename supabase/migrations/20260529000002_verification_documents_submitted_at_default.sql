-- 20260529000002_verification_documents_submitted_at_default
-- Root-cause fix for the admin verifications page TypeError:
--   `null: type 'Null' is not a subtype of type 'String'`
--
-- Background.
-- Migration 20260516000001 added `submitted_at`, `doc_type`, `file_path` as
-- nullable columns without defaults. The mobile upload datasource doesn't
-- include `submitted_at` in its insert payload (it expected a DB default),
-- so every row written through `verification_remote_datasource.uploadDocument`
-- lands with `submitted_at = NULL`. The mobile model fell back to
-- `created_at`; the admin web provider did not, and crashed the whole queue
-- on the first row read.
--
-- This migration:
--   1. backfills any existing NULL submitted_at from created_at (no data
--      loss; the column is purely a sort key for the admin queue).
--   2. installs a `DEFAULT now()` so future inserts cannot regress.
--   3. backfills NULL doc_type from the legacy `type` column where present
--      (rows that pre-date the reconciliation migration).
--   4. backfills NULL file_path from the legacy `url` column where present.
--
-- The admin provider was also hardened in the same commit to read the legacy
-- columns as fallbacks, so this migration is defence-in-depth — even if a
-- future insert path forgets `submitted_at`, the DB default catches it.

UPDATE public.verification_documents
SET submitted_at = COALESCE(submitted_at, created_at)
WHERE submitted_at IS NULL;

ALTER TABLE public.verification_documents
  ALTER COLUMN submitted_at SET DEFAULT now();

UPDATE public.verification_documents
SET doc_type = COALESCE(
      doc_type,
      CASE
        WHEN type IN (
          'trade_licence', 'public_liability', 'workers_compensation',
          'white_card', 'photo_id', 'abn_certificate', 'other'
        ) THEN type::public.document_doc_type
        ELSE 'other'::public.document_doc_type
      END
    )
WHERE doc_type IS NULL;

UPDATE public.verification_documents
SET file_path = COALESCE(file_path, url)
WHERE file_path IS NULL;
