-- Security fix — require login to browse the trade/builder directory (F3).
-- OWASP: API3 (Excessive Data Exposure) + API1. See docs/SECURITY_AUDIT_2026-07-02.md.
-- Product decision (2026-07-03): the directory is NOT public — logged-out visitors must
-- not enumerate tradies/builders (name + approximate location). Revoke the anon grants on
-- the two public projections and the search RPC; authenticated access is unchanged.
--
-- ⚠ PRE-APPLY CHECK: confirm the public marketing site (jobdun.com.au) does NOT read these
--    via the anon key. The Flutter app calls them only when authenticated, so the app is safe.
--    If the marketing site DOES show a public directory, do NOT push this until that is reworked.

REVOKE ALL ON TABLE public.trade_profiles_public   FROM anon;
REVOKE ALL ON TABLE public.builder_profiles_public FROM anon;
REVOKE ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text, integer, integer
) FROM anon;

-- (Authenticated retains its existing grants — verify with:
--    SELECT grantee, privilege_type FROM information_schema.role_table_grants
--    WHERE table_name IN ('trade_profiles_public','builder_profiles_public');  )
--
-- FURTHER HARDENING (not applied — separate decision): make the two views
-- `security_invoker = true` so they also respect RLS for authenticated callers, and revoke
-- the broad `GRANT ALL … TO anon` on base tables (audit finding F5).
