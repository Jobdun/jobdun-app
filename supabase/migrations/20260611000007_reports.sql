-- Phase D CP-1 §Migration 3 — reports table (admin reviews via service_role)
CREATE TABLE IF NOT EXISTS public.reports (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id  uuid        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  message_id       uuid                 REFERENCES public.messages(id)      ON DELETE SET NULL,
  reason           text        NOT NULL CHECK (reason IN (
                                 'harassment', 'spam_or_scam', 'fake_profile',
                                 'inappropriate_content', 'other'
                               )),
  details          text                 CHECK (char_length(details) <= 500),
  status           text        NOT NULL DEFAULT 'pending'
                                        CHECK (status IN (
                                          'pending', 'reviewed', 'actioned', 'dismissed'
                                        )),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_reporter_id_idx    ON public.reports (reporter_id);
CREATE INDEX IF NOT EXISTS reports_reported_id_idx    ON public.reports (reported_id);
CREATE INDEX IF NOT EXISTS reports_conversation_id_idx ON public.reports (conversation_id);
CREATE INDEX IF NOT EXISTS reports_status_created_idx ON public.reports (status, created_at DESC);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Reporters can see their own submissions.
DO $$ BEGIN
  CREATE POLICY "reports_select_own"
    ON public.reports FOR SELECT
    USING (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reports_insert_own"
    ON public.reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- No UPDATE / DELETE for users. Admin reviews via service_role.
