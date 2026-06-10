-- supabase/migrations/20260611000001_delete_my_account.sql
--
-- Play-policy account deletion (BLOCKER #3 in the 2026-06-10 Play review
-- audit): apps with account creation MUST offer in-app deletion. This is the
-- server half — a SECURITY DEFINER function the mobile app calls from
-- Settings → DELETE ACCOUNT (after an explicit confirm sheet).
--
-- Deleting the auth.users row cascades through the public schema via the
-- existing ON DELETE CASCADE FKs (profiles → builder/trade_profiles, jobs,
-- applications, messages, verification rows). Tables that intentionally
-- RESTRICT will abort the whole transaction — the app surfaces that as a
-- support-contact error rather than half-deleting.
--
-- Why SECURITY DEFINER: the anon/authenticated roles cannot touch auth.users;
-- the function runs as its owner (postgres) and is bounded to auth.uid() —
-- a user can only ever delete THEMSELVES. Mirrors the controlled-seam pattern
-- of get_trade_public_credentials / review_verification_document.
--
-- Reversibility: function-only, no schema change. Rollback in
-- supabase/rollbacks/20260611000001_delete_my_account_down.sql.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
