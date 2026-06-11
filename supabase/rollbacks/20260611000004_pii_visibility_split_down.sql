-- DOWN for 20260611000004_pii_visibility_split.sql — restores the blanket
-- (PII-exposing) SELECT policies and the invoker search_trades. Run manually
-- only; never place in supabase/migrations/.

BEGIN;

DROP VIEW IF EXISTS public.trade_profiles_public;
DROP VIEW IF EXISTS public.builder_profiles_public;

DROP POLICY IF EXISTS trade_profiles_select_related ON public.trade_profiles;
CREATE POLICY trade_profiles_select_authenticated ON public.trade_profiles
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
                  WHERE ur.user_id = trade_profiles.id AND ur.role = 'trade'));

DROP POLICY IF EXISTS builder_profiles_select_related ON public.builder_profiles;
CREATE POLICY builder_profiles_select_authenticated ON public.builder_profiles
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur
                  WHERE ur.user_id = builder_profiles.id AND ur.role = 'builder'));

-- search_trades: re-apply the projection from
-- supabase/migrations/20260604000001 (invoker, unsanitised) if a full revert
-- is ever required — kept by reference rather than duplicated here.

COMMIT;
