-- ============================================================
-- Migration 5: Notifications, verification documents, reviews
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       text NOT NULL,        -- 'application_received' | 'shortlisted' | 'hired' | etc.
  title      text NOT NULL,
  body       text NOT NULL,
  data       jsonb,                -- arbitrary payload (job_id, application_id, etc.)
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_at_idx ON public.notifications(user_id, read_at)
  WHERE read_at IS NULL;

-- -------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE public.document_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.verification_documents (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type       text NOT NULL,        -- 'white_card' | 'public_liability' | 'trade_licence' | etc.
  url        text NOT NULL,        -- storage path in private-docs bucket
  status     public.document_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS verification_documents_trade_id_idx ON public.verification_documents(trade_id);

DROP TRIGGER IF EXISTS verification_documents_updated_at ON public.verification_documents;
CREATE TRIGGER verification_documents_updated_at
  BEFORE UPDATE ON public.verification_documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.reviews (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id       uuid NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  reviewer_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reviewee_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating       smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment      text,
  created_at   timestamptz NOT NULL DEFAULT now(),

  UNIQUE (job_id, reviewer_id)   -- one review per reviewer per job
);

CREATE INDEX IF NOT EXISTS reviews_reviewee_id_idx ON public.reviews(reviewee_id);
