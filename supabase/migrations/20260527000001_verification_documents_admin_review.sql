-- Admin review surface for verification_documents.
--
-- Today the table has owner-only RLS — every trade can see their own docs,
-- nobody else can. The admin web app's verification queue needs SELECT to
-- list pending documents and UPDATE to flip status/reviewed_by/reviewed_at.
--
-- Pattern mirrors legal_acceptances (20260512000001) and role_audit_log
-- (20260520000002). Admin role lives in public.user_roles.role; it is
-- non-self-assignable (see 20260516000002_forbid_self_admin.sql), so an
-- admin RLS policy is a safe trust boundary.

-- ── verification_documents ────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE POLICY "verification_documents_admin_select"
    ON public.verification_documents FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "verification_documents_admin_update"
    ON public.verification_documents FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── storage: private-docs bucket — admin SELECT so reviewers can fetch ───────
-- the image / PDF that backs each verification_documents row.
DO $$ BEGIN
  CREATE POLICY "private_docs_admin_select"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'private-docs'
      AND EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
