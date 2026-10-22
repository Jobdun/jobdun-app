-- Advisor hardening (2026-08-14): lock down SECURITY DEFINER function EXECUTE
-- grants flagged by `supabase db advisors`, and pin search_path on the 7
-- functions that lacked one. Idempotent — safe to re-run.
--
-- Three tiers:
--   1. trigger/cron/internal functions → no client role needs EXECUTE at all
--      (Postgres checks trigger-fn EXECUTE at CREATE TRIGGER time, not fire
--      time; pg_cron runs as the job owner). supabase_auth_admin keeps EXECUTE
--      on the two auth.users trigger fns as belt-and-braces.
--   2. authenticated-only RPCs (app + admin console) → revoke anon.
--   3. public storefront fns (search_trades, get_builder_public_verification,
--      get_trade_public_credentials, is_builder_abn_verified) → untouched by
--      design (guest browse / sanitized definer reads, see 2026-06-11 audit).

DO $$
DECLARE r record;
BEGIN
  -- Tier 1: internal-only (triggers, cron, helpers called inside definer fns)
  FOR r IN
    SELECT p.oid::regprocedure AS sig, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = ANY (ARRAY[
      'handle_new_user','sync_phone_verified_at',
      'builder_profiles_pin_verified_abn','forbid_role_mutation',
      'log_role_event','notifications_push_fanout',
      'notify_builder_on_new_application','notify_builder_on_quote_response',
      'notify_on_new_message','notify_on_new_review',
      'notify_trade_on_application_status','notify_trade_on_quote_request',
      'notify_trades_on_new_job','reviews_sync_trade_rating',
      'sync_job_application_count','sync_trade_is_verified',
      'expire_stale_verifications','notify_expiring_verifications',
      'recompute_builder_rating','recompute_trade_rating'])
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    IF r.proname IN ('handle_new_user','sync_phone_verified_at') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO supabase_auth_admin', r.sig);
    END IF;
  END LOOP;

  -- Tier 2: authenticated-only RPCs — anon has no business calling these
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = ANY (ARRAY[
      'delete_my_account','get_inbox','get_or_create_conversation',
      'append_portfolio_url','remove_portfolio_url',
      'admin_broadcast','admin_set_job_status','admin_set_user_status',
      'admin_view_verification_raw','review_verification_document',
      'revoke_verification','log_admin_action'])
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', r.sig);
  END LOOP;

  -- Pin search_path on the 7 advisor-flagged functions (all live in public)
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = ANY (ARRAY[
      'set_updated_at','update_conversation_last_message','forbid_self_admin',
      'applications_protect_quote','notification_category',
      'quote_requests_touch_updated_at','bookings_touch_updated_at'])
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', r.sig);
  END LOOP;
END $$;
