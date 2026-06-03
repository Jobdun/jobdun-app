-- 20260604000002_jobs_require_verified_builder.sql
-- Soft-gate backstop: only ABN-verified builders ("Verified business") can
-- insert jobs. The mobile client routes unverified builders through the ~15s
-- ABN wizard before POST; this RLS check enforces the same rule even if the
-- client is bypassed. Tightens the original ownership-only jobs_insert_own.

CREATE OR REPLACE FUNCTION public.is_builder_abn_verified(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.verifications
    WHERE user_id = p_uid AND kind = 'abn' AND status = 'verified'
  );
$$;

DROP POLICY IF EXISTS "jobs_insert_own" ON public.jobs;
CREATE POLICY "jobs_insert_own"
  ON public.jobs FOR INSERT
  WITH CHECK (
    auth.uid() = builder_id
    AND public.is_builder_abn_verified(auth.uid())
  );
