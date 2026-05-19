-- ============================================================
-- Migration: portfolio_urls array helpers
--
-- Why: the trade portfolio uploader on /profile/edit lets users multi-add
-- images. A naive client-side read-modify-write loses entries if two
-- uploads complete near-simultaneously. These two SECURITY DEFINER RPCs
-- give the app an atomic append + remove against trade_profiles.portfolio_urls
-- without needing the service_role key.
--
-- auth.uid() guard inside each function so a caller can't tamper with
-- someone else's portfolio even though SECURITY DEFINER skips RLS.
-- ============================================================

CREATE OR REPLACE FUNCTION public.append_portfolio_url(
  user_id uuid,
  new_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM user_id THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF new_url IS NULL OR length(new_url) = 0 THEN
    RAISE EXCEPTION 'invalid url' USING ERRCODE = '22023';
  END IF;
  UPDATE public.trade_profiles
     SET portfolio_urls = COALESCE(portfolio_urls, ARRAY[]::text[]) || new_url
   WHERE id = user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_portfolio_url(
  user_id uuid,
  target_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM user_id THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  UPDATE public.trade_profiles
     SET portfolio_urls = array_remove(portfolio_urls, target_url)
   WHERE id = user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.append_portfolio_url(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_portfolio_url(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.append_portfolio_url(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_portfolio_url(uuid, text) TO authenticated;
