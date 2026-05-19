-- legal_acceptances: audit trail of every time a user accepts a legal document version.
-- Immutable by design — no UPDATE or DELETE for users — preserves legal defensibility.

CREATE TABLE IF NOT EXISTS public.legal_acceptances (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  document_type TEXT        NOT NULL CHECK (document_type IN ('terms_of_service', 'privacy_policy')),
  document_version TEXT     NOT NULL,
  accepted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  app_version   TEXT,
  UNIQUE (user_id, document_type, document_version)
);

CREATE INDEX IF NOT EXISTS idx_legal_acceptances_user
  ON public.legal_acceptances (user_id, document_type);

-- RLS: users can read their own; insert their own; nobody modifies or deletes.
ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Users read own acceptances"
    ON public.legal_acceptances FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Users insert own acceptances"
    ON public.legal_acceptances FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Admins can read all rows (needed for legal disputes).
-- NOTE: role lives in public.user_roles — profiles has no role column.
DO $$ BEGIN
  CREATE POLICY "Admins read all acceptances"
    ON public.legal_acceptances FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
