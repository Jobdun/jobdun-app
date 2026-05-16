-- ============================================================
-- Migration: schema reconciliation (Sprint 1 / F-SCH-01,02,13 + perf/realtime)
-- Pre-launch, no data: additive ALTERs, idempotent, safe to replay.
-- Brings the schema up to the canonical Dart data-layer contract.
-- ============================================================

-- ---------- verification_documents (F-SCH-01) ----------

-- doc_type enum — exactly DocType.dbValue in verification_document.dart:16-22
DO $$ BEGIN
  CREATE TYPE public.document_doc_type AS ENUM (
    'trade_licence', 'public_liability', 'workers_compensation',
    'white_card', 'photo_id', 'abn_certificate', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- VerificationStatus has 4 values (verification_document.dart:50); enum has 3.
DO $$ BEGIN
  ALTER TYPE public.document_status ADD VALUE IF NOT EXISTS 'expired';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.verification_documents
  ADD COLUMN IF NOT EXISTS doc_type         public.document_doc_type,
  ADD COLUMN IF NOT EXISTS file_path        text,
  ADD COLUMN IF NOT EXISTS submitted_at     timestamptz,
  ADD COLUMN IF NOT EXISTS state            text,
  ADD COLUMN IF NOT EXISTS issuer           text,
  ADD COLUMN IF NOT EXISTS document_number  text,
  ADD COLUMN IF NOT EXISTS issued_date      date,
  ADD COLUMN IF NOT EXISTS expiry_date      date,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS review_notes     text,
  ADD COLUMN IF NOT EXISTS reviewed_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at      timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at       timestamptz;

-- THE GAP the audit's F-SCH-01 SQL missed: legacy type/url are NOT NULL but
-- the app's insert payload (verification_document_model.dart:49-61) never
-- sends them. Without this, every upload still fails a NOT NULL violation
-- after the columns exist. No data → straight DROP NOT NULL, no backfill.
ALTER TABLE public.verification_documents
  ALTER COLUMN type DROP NOT NULL,
  ALTER COLUMN url  DROP NOT NULL;

-- "expiring soon" path (F-SCH-06): partial index on live approved docs.
CREATE INDEX IF NOT EXISTS verification_documents_expiry_idx
  ON public.verification_documents (expiry_date)
  WHERE status = 'approved' AND deleted_at IS NULL AND expiry_date IS NOT NULL;

-- ---------- messages (F-SCH-02 + realtime F-RT) ----------
-- message_model.dart:23-28 reads deleted_at AND edited_at; neither exists.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS edited_at  timestamptz;

-- Sender may soft-delete / edit their own message.
DO $$ BEGIN
  CREATE POLICY "messages_modify_own"
    ON public.messages FOR UPDATE
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Realtime thread feed: newest-first within a thread, tombstones excluded.
CREATE INDEX IF NOT EXISTS messages_thread_feed_idx
  ON public.messages (conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- ---------- conversations (F-SCH-13 + realtime F-RT-01) ----------
DO $$ BEGIN
  CREATE TYPE public.conversation_status AS ENUM ('active','archived','blocked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS status                 public.conversation_status NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS builder_unread_count   int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS trade_unread_count     int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_message_preview   text,
  ADD COLUMN IF NOT EXISTS last_message_sender_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- F-SCH-13: NULL job_id makes the UNIQUE(job_id,builder_id,trade_id) constraint
-- non-deduping (NULLs are distinct). Replace with two partial unique indexes.
ALTER TABLE public.conversations
  DROP CONSTRAINT IF EXISTS conversations_job_id_builder_id_trade_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_with_job
  ON public.conversations (job_id, builder_id, trade_id)
  WHERE job_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS conversations_uniq_no_job
  ON public.conversations (builder_id, trade_id)
  WHERE job_id IS NULL;

-- ---------- profiles_public (realtime F-RT-01 inbox embed) ----------
-- Minimal counterparty card for the messaging inbox. Display fields only;
-- NO contact_phone / location PII (that scoping is F-RLS-03, separate task).
CREATE OR REPLACE VIEW public.profiles_public
  WITH (security_invoker = on) AS
  SELECT id, display_name, avatar_url
  FROM public.profiles;

GRANT SELECT ON public.profiles_public TO authenticated;

-- ---------- jobs.search_vector (F-PERF-01) ----------
-- websearch_to_tsquery target for job_remote_datasource.dart:41.
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(title,'') || ' ' || coalesce(description,''))
  ) STORED;

CREATE INDEX IF NOT EXISTS jobs_search_vector_idx
  ON public.jobs USING gin (search_vector);

-- ---------- applications.status_changed_at (F-SCH / app contract) ----------
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS status_changed_at timestamptz;

-- ---------- profiles (auth/profile feature contract) ----------
-- profile_remote_datasource.dart:36 selects phone + bio. The completeness
-- migration comment claims "Number lives on profiles.phone" but the column
-- was never added. (email is intentionally NOT added — canonical in
-- auth.users; the offending .select() is corrected in Task 6C.)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS bio   text;
