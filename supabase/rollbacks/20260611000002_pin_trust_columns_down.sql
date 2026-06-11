-- DOWN for 20260611000002_pin_trust_columns.sql — restores the pre-pin
-- (insecure) table-level grants. Run manually only; never placed in
-- supabase/migrations/ (the CLI would replay it forward — see
-- docs gotcha on down migrations).

BEGIN;

DROP TRIGGER IF EXISTS builder_profiles_pin_verified_abn_trg ON public.builder_profiles;
DROP FUNCTION IF EXISTS public.builder_profiles_pin_verified_abn();

REVOKE INSERT, UPDATE ON public.trade_profiles FROM authenticated;
GRANT INSERT, UPDATE ON public.trade_profiles TO authenticated;

REVOKE INSERT, UPDATE ON public.builder_profiles FROM authenticated;
GRANT INSERT, UPDATE ON public.builder_profiles TO authenticated;

REVOKE UPDATE ON public.verification_documents FROM authenticated;
GRANT UPDATE ON public.verification_documents TO authenticated;

COMMIT;
