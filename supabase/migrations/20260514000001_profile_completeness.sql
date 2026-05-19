-- ============================================================
-- Migration: profile_completeness view + supporting columns
--
-- Why: drives the ProfileCompletenessBanner on /home. Calculated server-side
-- so BI dashboards and the future admin panel can show the same number the
-- mobile app does without re-implementing the rules.
--
-- Field list per role (locked by friction-reduction audit, T1):
--   builder → company_name · abn · service_suburb · phone_verified_at
--             (4 fields × 25%)
--   trade   → primary_trade · licence_url · base_suburb ·
--             phone_verified_at · ≥1 portfolio image
--             (5 fields × 20%)
--
-- Privacy / AU retention note: phone_verified_at is a verification timestamp,
-- not the phone number itself. Number lives on profiles.phone; this column
-- only records when it was confirmed. Retained for the life of the account
-- and purged with the cascade delete on auth.users.
--
-- Reads exclusively use the (id) PK index on profiles + user_roles +
-- builder_profiles + trade_profiles, plus verification_documents_trade_id_idx
-- for the trade-licence EXISTS subquery. No new indexes required.
-- ============================================================

-- ── New columns ───────────────────────────────────────────────────────────
-- Phone-verification timestamp on profiles (mirrors the eventual auth phone
-- confirm flow — added now so the view + banner can read it as soon as that
-- ships).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_verified_at timestamptz;

-- Trade licence storage URL. Populated by the verification upload flow when
-- it lands; NULL until then. The view treats NULL as "no licence on file".
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS licence_url text;

-- ── View ──────────────────────────────────────────────────────────────────
-- security_invoker = on so PostgREST queries inherit the underlying-table
-- RLS instead of running as the view owner. WHERE p.id = auth.uid() keeps
-- a non-admin caller scoped to their own row even if PostgREST exposes the
-- view broadly.
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
    WHEN 'trade' THEN (
      (tp.primary_trade IS NOT NULL AND tp.primary_trade <> '')::int +
      (tp.licence_url IS NOT NULL AND tp.licence_url <> '')::int +
      (tp.base_suburb IS NOT NULL AND tp.base_suburb <> '')::int +
      (p.phone_verified_at IS NOT NULL)::int +
      (COALESCE(array_length(tp.portfolio_urls, 1), 0) > 0)::int
    ) * 20
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
