-- Rollback for 20260610000006_trade_public_credentials.sql
-- Function-only migration — dropping it is safe and complete.
REVOKE EXECUTE ON FUNCTION public.get_trade_public_credentials(uuid) FROM authenticated;
DROP FUNCTION IF EXISTS public.get_trade_public_credentials(uuid);
