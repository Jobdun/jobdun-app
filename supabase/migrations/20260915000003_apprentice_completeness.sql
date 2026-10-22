-- Apprentice credibility slots match ProfileState.completenessPct.
BEGIN;
CREATE OR REPLACE VIEW public.profile_completeness
WITH (security_invoker = on) AS
SELECT
  p.id,
  ur.role,
  CASE ur.role
    WHEN 'builder' THEN (
      (bp.company_name IS NOT NULL AND bp.company_name <> '')::int +
      (bp.abn IS NOT NULL AND bp.abn <> '')::int +
      (bp.service_suburb IS NOT NULL AND bp.service_suburb <> '')::int +
      (p.phone_verified_at IS NOT NULL)::int
    ) * 25
    WHEN 'trade' THEN CASE WHEN tp.is_apprentice THEN (
      (COALESCE(tp.primary_trade, '') <> '')::int +
      (btrim(COALESCE(tp.about, '')) <> '')::int +
      (COALESCE(tp.resume_path, '') <> '')::int +
      (COALESCE(array_length(tp.portfolio_urls, 1), 0) > 0)::int +
      (COALESCE(tp.base_suburb, '') <> '')::int
    ) * 20 ELSE (
      (tp.primary_trade IS NOT NULL AND tp.primary_trade <> '')::int +
      (tp.licence_url IS NOT NULL AND tp.licence_url <> '')::int +
      (tp.base_suburb IS NOT NULL AND tp.base_suburb <> '')::int +
      (p.phone_verified_at IS NOT NULL)::int +
      (COALESCE(array_length(tp.portfolio_urls, 1), 0) > 0)::int
    ) * 20 END
    ELSE NULL
  END AS completeness_pct
FROM public.profiles p
LEFT JOIN public.user_roles ur       ON ur.user_id = p.id
LEFT JOIN public.builder_profiles bp ON bp.id      = p.id
LEFT JOIN public.trade_profiles   tp ON tp.id      = p.id
WHERE p.id = auth.uid();

-- Anon should never read this view — only an authed session has a meaningful
-- auth.uid(). authenticated gets SELECT; PostgREST exposes it via /rest/v1.
REVOKE ALL ON public.profile_completeness FROM PUBLIC;
GRANT SELECT ON public.profile_completeness TO authenticated;

COMMENT ON VIEW public.profile_completeness IS
  'Per-user profile completeness % (0–100). Scoped to auth.uid() at view '
  'level; safe to expose via PostgREST. Drives ProfileCompletenessBanner '
  'on /home and is the source of truth for completeness in BI dashboards.';

COMMIT;
