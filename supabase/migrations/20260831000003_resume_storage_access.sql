-- supabase/migrations/20260831000003_resume_storage_access.sql
--
-- Apprentice resumes live at private-docs/{uid}/resume/{epoch}.{ext}.
--
-- The owner already has full CRUD via the private_docs_owner_* policies from
-- 20260511000006_rls.sql, which key on (storage.foldername(name))[1] =
-- auth.uid(). Nothing here changes that.
--
-- This ADDS a second SELECT policy so a builder can open the resume of an
-- apprentice who has applied to one of their jobs. Postgres OR-s policies, so
-- this only widens read; the owner-only rule stays intact.
--
-- Why no Edge Function: Supabase Storage RLS is plain RLS on storage.objects,
-- so the client can call createSignedUrl with the anon key and Postgres decides
-- whether it is allowed. A function would add a deploy surface and a
-- service-role key path for nothing.
--
-- A resume carries a home address, phone number, school and referees, and many
-- apprentices are minors. Relationship-gated is the floor here, not a nicety --
-- same posture as 20260611000004_pii_visibility_split.sql.
--
-- NOTE ON THE TABLE NAME: the applications table is `public.applications`, NOT
-- `job_applications` (CLAUDE.md's "Key database tables" list is wrong; verified
-- against both prod and staging on 2026-08-31). It denormalises builder_id
-- (NOT NULL, indexed by applications_builder_id_idx), so this needs no join to
-- jobs -- which also keeps the policy cheap, since it runs per storage object.
--
-- Reversibility: SAFE -- additive policy, no schema change.
-- Down: supabase/rollbacks/20260831000003_resume_storage_access_down.sql

DO $$ BEGIN
  CREATE POLICY "private_docs_resume_applied_builder_select"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'private-docs'
      AND (storage.foldername(name))[2] = 'resume'
      AND EXISTS (
        SELECT 1
        FROM public.applications a
        WHERE a.trade_id::text = (storage.foldername(name))[1]
          AND a.builder_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON POLICY "private_docs_resume_applied_builder_select" ON storage.objects IS
  'Lets a builder read an apprentice resume once that apprentice has applied to '
  'one of their jobs. Additive to private_docs_owner_select (policies are OR-ed).';
