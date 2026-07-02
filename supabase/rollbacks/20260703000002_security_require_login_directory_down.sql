-- Rollback for 20260703000002_security_require_login_directory.sql
-- Restores anonymous read access to the directory projections + search RPC.
GRANT ALL ON TABLE public.trade_profiles_public   TO anon;
GRANT ALL ON TABLE public.builder_profiles_public TO anon;
GRANT ALL ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text, integer, integer
) TO anon;
