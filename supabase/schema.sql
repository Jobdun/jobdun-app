


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."application_status" AS ENUM (
    'pending',
    'shortlisted',
    'rejected',
    'withdrawn',
    'hired',
    'declined_by_trade'
);


ALTER TYPE "public"."application_status" OWNER TO "postgres";


CREATE TYPE "public"."booking_status" AS ENUM (
    'scheduled',
    'completed',
    'cancelled'
);


ALTER TYPE "public"."booking_status" OWNER TO "postgres";


CREATE TYPE "public"."budget_type" AS ENUM (
    'hourly',
    'daily',
    'fixed',
    'negotiable'
);


ALTER TYPE "public"."budget_type" OWNER TO "postgres";


CREATE TYPE "public"."conversation_status" AS ENUM (
    'active',
    'archived',
    'blocked'
);


ALTER TYPE "public"."conversation_status" OWNER TO "postgres";


CREATE TYPE "public"."document_doc_type" AS ENUM (
    'trade_licence',
    'public_liability',
    'workers_compensation',
    'white_card',
    'photo_id',
    'abn_certificate',
    'other'
);


ALTER TYPE "public"."document_doc_type" OWNER TO "postgres";


CREATE TYPE "public"."document_status" AS ENUM (
    'pending',
    'approved',
    'rejected',
    'expired'
);


ALTER TYPE "public"."document_status" OWNER TO "postgres";


CREATE TYPE "public"."job_pricing_type" AS ENUM (
    'builder_set',
    'request_quote'
);


ALTER TYPE "public"."job_pricing_type" OWNER TO "postgres";


CREATE TYPE "public"."job_pricing_unit" AS ENUM (
    'hourly',
    'sqm',
    'lm',
    'per_job'
);


ALTER TYPE "public"."job_pricing_unit" OWNER TO "postgres";


CREATE TYPE "public"."job_status" AS ENUM (
    'draft',
    'open',
    'filled',
    'closed',
    'cancelled'
);


ALTER TYPE "public"."job_status" OWNER TO "postgres";


CREATE TYPE "public"."job_urgency" AS ENUM (
    'standard',
    'urgent'
);


ALTER TYPE "public"."job_urgency" OWNER TO "postgres";


CREATE TYPE "public"."quote_request_status" AS ENUM (
    'requested',
    'quoted',
    'declined',
    'accepted',
    'withdrawn'
);


ALTER TYPE "public"."quote_request_status" OWNER TO "postgres";


CREATE TYPE "public"."user_status" AS ENUM (
    'active',
    'suspended',
    'banned'
);


ALTER TYPE "public"."user_status" OWNER TO "postgres";


CREATE TYPE "public"."verification_status" AS ENUM (
    'pending',
    'verified',
    'failed',
    'expired',
    'suspended',
    'manual_review'
);


ALTER TYPE "public"."verification_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT t.id, 'announcement', p_title, p_body, COALESCE(p_data, '{}'::jsonb)
  FROM (
    SELECT p.id
    FROM public.profiles p
    WHERE p_audience = 'all'

    UNION

    SELECT ur.user_id AS id
    FROM public.user_roles ur
    WHERE (p_audience = 'builders' AND ur.role = 'builder')
       OR (p_audience = 'trades'   AND ur.role = 'trade')

    UNION

    SELECT p.id
    FROM public.profiles p
    WHERE p_audience NOT IN ('all', 'builders', 'trades')
      AND p.id = p_audience::uuid
  ) AS t;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM public.log_admin_action(
    'broadcast', 'notifications', NULL,
    jsonb_build_object('audience', p_audience, 'count', v_count)
  );

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") IS 'Push program (Stream A): admin sends an announcement to All / builders / trades / a single user. Admin-only; inserts type=announcement notification rows (auto-pushed by notifications_push_fanout); audited via log_admin_action. Returns the recipient count.';



CREATE OR REPLACE FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  UPDATE public.jobs
     SET status = p_status::public.job_status
   WHERE id = p_job_id;

  PERFORM public.log_admin_action(
    'set_job_status', 'jobs', p_job_id,
    jsonb_build_object('status', p_status)
  );
END;
$$;


ALTER FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") IS '#21a admin moderation: set a job status (e.g. closed). Admin-only; audited.';



CREATE OR REPLACE FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  UPDATE public.profiles
     SET user_status   = p_status::public.user_status,
         status_reason = p_reason
   WHERE id = p_user_id;

  PERFORM public.log_admin_action(
    'set_user_status', 'profiles', p_user_id,
    jsonb_build_object('status', p_status, 'reason', p_reason)
  );
END;
$$;


ALTER FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") IS '#21a admin moderation: set a user active/suspended/banned. Admin-only; audited via log_admin_action. Enforcement (blocking suspended users) is a follow-up RLS concern.';



CREATE OR REPLACE FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_raw jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  PERFORM public.log_admin_action(
    'view_verification_raw',
    'verification_events',
    p_verification_id,
    '{}'::jsonb
  );

  SELECT raw_response INTO v_raw
    FROM public.verification_events
   WHERE verification_id = p_verification_id
     AND event_type = 'api_call'
   ORDER BY created_at DESC
   LIMIT 1;

  RETURN v_raw;
END;
$$;


ALTER FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") IS 'Audited admin read of verification_events.raw_response. Admin-only; writes an admin_actions row before returning the latest api_call payload.';



CREATE OR REPLACE FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."applications_protect_quote"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.quote_amount IS DISTINCT FROM OLD.quote_amount
     AND auth.uid() IS NOT NULL
     AND auth.uid() <> OLD.trade_id THEN
    RAISE EXCEPTION 'quote_amount can only be changed by the applicant';
  END IF;
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."applications_protect_quote"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bookings_touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."bookings_touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."builder_profiles_pin_verified_abn"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF auth.uid() = new.id
     AND new.abn IS DISTINCT FROM old.abn
     AND EXISTS (
       SELECT 1 FROM public.verifications v
        WHERE v.user_id = new.id
          AND v.kind = 'abn'
          AND v.status = 'verified'
     )
  THEN
    RAISE EXCEPTION 'ABN is locked after ABR verification. Contact support to change.'
      USING ERRCODE = '42501';
  END IF;
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."builder_profiles_pin_verified_abn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."custom_access_token"("event" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id  uuid;
  v_role     text;
  v_claims   jsonb;
BEGIN
  v_user_id := (event->>'user_id')::uuid;
  v_claims  := event->'claims';

  SELECT role INTO v_role
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

  -- Only inject the claim when a role row actually exists. If null, the
  -- Flutter client sees no user_role claim and prompts via RoleSelectionSheet.
  IF v_role IS NOT NULL THEN
    v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role));
  END IF;

  RETURN jsonb_set(event, '{claims}', v_claims);
END;
$$;


ALTER FUNCTION "public"."custom_access_token"("event" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_my_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."delete_my_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expire_stale_verifications"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
  v_count   integer := 0;
BEGIN
  FOR v_user_id IN
    UPDATE public.verifications
       SET status     = 'expired',
           updated_at = now()
     WHERE kind        = 'licence'
       AND status      = 'verified'
       AND expires_at IS NOT NULL
       AND expires_at  < now()
    RETURNING user_id
  LOOP
    v_count := v_count + 1;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      v_user_id,
      'document_expired',
      'Licence expired',
      'Your trade licence has expired — re-verify to stay verified.',
      jsonb_build_object('kind', 'licence')
    );
  END LOOP;

  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."expire_stale_verifications"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."expire_stale_verifications"() IS 'Maintenance sweep: flips verified licence rows past expires_at to expired, notifies each holder (document_expired), returns the count. service_role only; meant to run on a schedule (pg_cron or a scheduled edge function).';



CREATE OR REPLACE FUNCTION "public"."forbid_role_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- Allow non-role column updates (e.g. created_at backfill, never used today
  -- but future-proof). Only block when the role itself changed.
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    -- auth.role() returns 'service_role' when the request is signed with the
    -- service-role key, 'authenticated' for end-users, 'anon' for unauthed.
    IF auth.role() <> 'service_role' THEN
      RAISE EXCEPTION 'user_roles.role is immutable from client; role changes must go through an admin Edge Function (service_role)'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."forbid_role_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."forbid_self_admin"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.role = 'admin' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."forbid_self_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "kind" "text", "verified_legal_name" "text", "gst_registered" boolean, "licence_class" "text", "licence_status" "text", "detail_captured_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  SELECT
    v.user_id,
    v.kind,
    v.abn_entity_name                                          AS verified_legal_name,
    v.gst_registered,
    v.licence_trade_class                                      AS licence_class,
    CASE WHEN v.expires_at IS NULL OR v.expires_at > now()
         THEN 'current' ELSE 'expired' END                    AS licence_status,
    v.detail_captured_at
  FROM public.verifications v
  LEFT JOIN public.builder_profiles bp ON bp.id = v.user_id
  LEFT JOIN public.trade_profiles   tp ON tp.id = v.user_id
  WHERE v.user_id = p_user_id
    AND v.status  = 'verified'
    AND bp.deleted_at IS NULL   -- NULL when no builder profile (LEFT JOIN) — still passes
    AND tp.deleted_at IS NULL;  -- NULL when no trade profile  — still passes
$$;


ALTER FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") IS 'Minimized, register-derived verification projection for counterparty display (trust badge). SECURITY DEFINER on purpose: exposes ONLY already-public register fields, never the raw payload / ABN number / failure reasons.';



CREATE OR REPLACE FUNCTION "public"."get_inbox"("p_user" "uuid") RETURNS TABLE("id" "uuid", "job_id" "uuid", "builder_id" "uuid", "trade_id" "uuid", "last_message_at" timestamp with time zone, "last_message_preview" "text", "last_message_sender_id" "uuid", "status" "text", "created_at" timestamp with time zone, "my_unread_count" integer, "other_display_name" "text", "other_avatar_url" "text", "job_title" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                      AS my_unread_count,
         CASE
           WHEN c.builder_id <> p_user   -- counterparty is the builder (a business)
             THEN COALESCE(NULLIF(btrim(bp.company_name), ''), other.display_name)
           ELSE other.display_name        -- counterparty is the trade (a person)
         END                                                     AS other_display_name,
         other.avatar_url                                        AS other_avatar_url,
         j.title                                                 AS job_title
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
    LEFT JOIN public.builder_profiles bp ON bp.id = c.builder_id
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY c.last_message_at DESC NULLS LAST;
$$;


ALTER FUNCTION "public"."get_inbox"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() NOT IN (p_builder, p_trade) THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  SELECT id INTO v_id FROM public.conversations
   WHERE builder_id = p_builder AND trade_id = p_trade
     AND ((p_job IS NULL AND job_id IS NULL) OR job_id = p_job)
   LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.conversations (builder_id, trade_id, job_id)
    VALUES (p_builder, p_trade, p_job)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "doc_type" "text", "expires_at" "date", "credential_status" "text", "captured_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  SELECT
    vd.trade_id    AS user_id,
    vd.doc_type,
    vd.expiry_date AS expires_at,
    CASE WHEN vd.expiry_date IS NULL OR vd.expiry_date >= current_date
         THEN 'current' ELSE 'expired' END AS credential_status,
    vd.reviewed_at AS captured_at
  FROM public.verification_documents vd
  LEFT JOIN public.trade_profiles tp ON tp.id = vd.trade_id
  WHERE vd.trade_id = p_user_id
    AND vd.status   = 'approved'
    AND vd.doc_type IN ('white_card', 'public_liability')
    AND tp.deleted_at IS NULL;  -- NULL when no trade profile — still passes
$$;


ALTER FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") IS 'Minimized counterparty projection of a tradie''s APPROVED supplementary credentials (white_card, public_liability). SECURITY DEFINER on purpose: exposes ONLY the credential type, lapsed-or-not, and the as-at approval date — never the document url, number, insurer, state, or review notes.';



CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_display_name text;
  v_avatar_url   text;
  v_role         text;
  v_meta         jsonb := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
BEGIN
  -- Display name: try every key the four signup paths actually populate,
  -- in priority order. NULLIF + trim handles whitespace-only entries.
  v_display_name := COALESCE(
    NULLIF(trim(v_meta->>'full_name'), ''),
    NULLIF(trim(v_meta->>'name'), ''),
    NULLIF(trim(
      coalesce(v_meta->>'given_name', '') || ' ' ||
      coalesce(v_meta->>'family_name', '')
    ), ''),
    -- Apple sends {"name":{"firstName":"...","lastName":"..."}} on first
    -- signin only. The string "null null" can arise if both inner fields
    -- are missing — guard against it explicitly.
    NULLIF(trim(
      coalesce(v_meta->'name'->>'firstName', '') || ' ' ||
      coalesce(v_meta->'name'->>'lastName', '')
    ), ''),
    null
  );

  -- Avatar URL: only Google supplies one (via the OIDC `picture` claim,
  -- which Supabase maps to either `picture` or `avatar_url` depending on
  -- version). Apple + phone leave this NULL.
  v_avatar_url := COALESCE(
    NULLIF(v_meta->>'avatar_url', ''),
    NULLIF(v_meta->>'picture', ''),
    null
  );

  v_role := v_meta->>'role';

  INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (NEW.id, v_display_name, v_avatar_url)
    ON CONFLICT (id) DO NOTHING;

  -- admin role intentionally NOT accepted from client metadata
  -- (see 20260516000002_forbid_self_admin.sql — F-RLS-01 lockdown).
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id)
        VALUES (NEW.id)
        ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name)
        ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_new_user"() IS 'Fires on auth.users INSERT. Mirrors display_name + avatar_url from the provider-specific metadata keys (Google: name/picture, Apple: nested name.firstName/lastName, email: full_name). Phone signups leave both NULL — the unified onboarding completion sheet collects them post-auth.';



CREATE OR REPLACE FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.verifications
    WHERE user_id = p_uid AND kind = 'abn' AND status = 'verified'
  );
$$;


ALTER FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text" DEFAULT NULL::"text", "p_target_id" "uuid" DEFAULT NULL::"uuid", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  INSERT INTO public.admin_actions (actor_id, action, target_table, target_id, metadata)
  VALUES (auth.uid(), p_action, p_target_table, p_target_id, COALESCE(p_metadata, '{}'::jsonb))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") IS 'Append-only admin audit seam. Admin-only; attributes the row to auth.uid(). First caller: verification "view raw" action.';



CREATE OR REPLACE FUNCTION "public"."log_role_event"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_reason text;
  v_old    text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_reason := 'signup';
    v_old    := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    -- 20260520000001's trigger ensures only service_role can land here
    -- with a changed role. Anything else got an exception before this
    -- AFTER trigger could fire.
    IF OLD.role IS NOT DISTINCT FROM NEW.role THEN
      RETURN NEW; -- no-op update; nothing to log
    END IF;
    v_reason := 'admin_change';
    v_old    := OLD.role;
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.user_role_events (
    user_id, old_role, new_role, changed_by, reason
  ) VALUES (
    NEW.user_id, v_old, NEW.role, auth.uid(), v_reason
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_role_event"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notification_category"("p_type" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_type = 'new_job'                 THEN 'jobs'
    WHEN p_type LIKE 'application%'          THEN 'applications'
    WHEN p_type LIKE 'quote%'                THEN 'applications'
    WHEN p_type LIKE 'message%'              THEN 'messages'
    WHEN p_type LIKE 'review%'               THEN 'reviews'
    WHEN p_type LIKE '%verif%'
      OR p_type LIKE 'document_%'            THEN 'verification'
    WHEN p_type = 'announcement'             THEN 'announcements'
    ELSE 'other'
  END;
$$;


ALTER FUNCTION "public"."notification_category"("p_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notifications_push_fanout"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_category text;
  v_enabled  boolean;
BEGIN
  v_category := public.notification_category(NEW.type);

  SELECT push_enabled INTO v_enabled
    FROM public.notification_preferences
   WHERE user_id = NEW.user_id AND category = v_category;
  IF v_enabled IS NULL THEN
    v_enabled := true;  -- no row = default on
  END IF;
  IF NOT v_enabled THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := 'https://zethpanvkfyijislxesn.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpldGhwYW52a2Z5aWppc2x4ZXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MjYyMzUsImV4cCI6MjA5MzQwMjIzNX0.YvW3jHql3SfiwGo7y2y_AwewMa3igyz7nNTbhNC9s5E',
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(NEW.user_id),
        'title', NEW.title,
        'body', NEW.body,
        'data', COALESCE(NEW.data, '{}'::jsonb)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notifications_push_fanout"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_builder_on_new_application"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_builder_id   uuid;
  v_job_title    text;
  v_trade_name   text;
BEGIN
  -- The job is the source of truth for who owns it.
  SELECT j.builder_id, j.title
    INTO v_builder_id, v_job_title
    FROM public.jobs j
   WHERE j.id = NEW.job_id;

  IF v_builder_id IS NULL THEN
    RETURN NEW;  -- orphan application; nothing to notify.
  END IF;

  SELECT p.display_name INTO v_trade_name
    FROM public.profiles p
   WHERE p.id = NEW.trade_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_builder_id,
    'application_received',
    'New applicant',
    COALESCE(NULLIF(v_trade_name, ''), 'A tradie')
      || ' applied for "'
      || COALESCE(NULLIF(v_job_title, ''), 'your job')
      || '"',
    jsonb_build_object(
      'job_id',         NEW.job_id,
      'application_id', NEW.id
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_builder_on_new_application"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_builder_on_new_application"() IS 'Stream B producer: on a new application, inserts an application_received notification for the job''s builder (looked up from jobs.builder_id). Central push fanout delivers it.';



CREATE OR REPLACE FUNCTION "public"."notify_builder_on_quote_response"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_job_title  text;
  v_trade_name text;
  v_title      text;
  v_body       text;
BEGIN
  SELECT j.title INTO v_job_title
    FROM public.jobs j WHERE j.id = NEW.job_id;
  v_job_title := COALESCE(NULLIF(v_job_title, ''), 'a job');

  SELECT p.display_name INTO v_trade_name
    FROM public.profiles p WHERE p.id = NEW.trade_id;
  v_trade_name := COALESCE(NULLIF(v_trade_name, ''), 'A tradie');

  CASE NEW.status
    WHEN 'quoted' THEN
      v_title := 'Quote received';
      v_body  := v_trade_name || ' sent a quote for "' || v_job_title || '".';
    WHEN 'declined' THEN
      v_title := 'Quote declined';
      v_body  := v_trade_name || ' declined to quote "' || v_job_title || '".';
    ELSE
      RETURN NEW;  -- other transitions don't notify the builder.
  END CASE;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.builder_id,
    'quote_responded',
    v_title,
    v_body,
    jsonb_build_object(
      'job_id',           NEW.job_id,
      'quote_request_id', NEW.id,
      'status',           NEW.status::text
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_builder_on_quote_response"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_builder_on_quote_response"() IS '#18 producer: when a quote_requests row moves to quoted/declined, notifies the builder (quote_responded). Central push fanout delivers it.';



CREATE OR REPLACE FUNCTION "public"."notify_expiring_verifications"("p_days" integer DEFAULT 30) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT v.user_id,
         'verification_expiring',
         'Licence expiring soon',
         'Your trade licence expires on '
           || to_char(v.expires_at, 'DD Mon YYYY')
           || ' — re-verify to keep your verified badge.',
         jsonb_build_object('kind', 'licence')
    FROM public.verifications v
   WHERE v.kind       = 'licence'
     AND v.status     = 'verified'
     AND v.expires_at IS NOT NULL
     AND v.expires_at >= now()
     AND v.expires_at <  now() + make_interval(days => p_days)
     AND NOT EXISTS (
       SELECT 1
         FROM public.notifications n
        WHERE n.user_id    = v.user_id
          AND n.type       = 'verification_expiring'
          AND n.created_at >= now() - interval '14 days'
     );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."notify_expiring_verifications"("p_days" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) IS 'Advance-warning sweep: notifies holders whose verified licence expires within N days (default 30), deduped to ~once per fortnight. service_role only; runs on a schedule alongside expire_stale_verifications().';



CREATE OR REPLACE FUNCTION "public"."notify_on_new_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipient_id  uuid;
  v_sender_name   text;
BEGIN
  -- Resolve the OTHER participant: whichever of (builder_id, trade_id) is not
  -- the sender. Returns NULL if the conversation is gone (defensive).
  SELECT CASE
           WHEN c.builder_id = NEW.sender_id THEN c.trade_id
           ELSE c.builder_id
         END
    INTO v_recipient_id
    FROM public.conversations c
   WHERE c.id = NEW.conversation_id;

  -- Skip if no recipient resolved, or sender == recipient (self-conversation /
  -- data anomaly) — never notify the sender about their own message.
  IF v_recipient_id IS NULL OR v_recipient_id = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  SELECT p.display_name INTO v_sender_name
    FROM public.profiles p
   WHERE p.id = NEW.sender_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_recipient_id,
    'message_received',
    'New message',
    'New message from ' || COALESCE(NULLIF(v_sender_name, ''), 'someone'),
    jsonb_build_object('conversation_id', NEW.conversation_id)
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_on_new_message"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_on_new_message"() IS 'Stream B producer: on a new message, inserts a message_received notification for the OTHER conversation participant (never the sender). Central push fanout delivers it. Copy is "New message from <name>" (no message preview).';



CREATE OR REPLACE FUNCTION "public"."notify_trade_on_application_status"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_job_title text;
  v_title     text;
  v_body      text;
BEGIN
  -- Only act on a real status transition into a builder-driven outcome state.
  -- (The WHEN clause on the trigger also guards this; belt and braces.)
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT j.title INTO v_job_title
    FROM public.jobs j
   WHERE j.id = NEW.job_id;

  v_job_title := COALESCE(NULLIF(v_job_title, ''), 'a job');

  CASE NEW.status
    WHEN 'shortlisted' THEN
      v_title := 'You were shortlisted';
      v_body  := 'You''ve been shortlisted for "' || v_job_title || '".';
    WHEN 'hired' THEN
      v_title := 'You got the job';
      v_body  := 'You''ve been hired for "' || v_job_title || '". Congratulations!';
    WHEN 'rejected' THEN
      v_title := 'Application update';
      v_body  := 'Your application for "' || v_job_title || '" was not successful.';
    ELSE
      RETURN NEW;  -- not a state we notify on (e.g. withdrawn / declined_by_trade).
  END CASE;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.trade_id,
    'application_status',
    v_title,
    v_body,
    jsonb_build_object(
      'job_id',         NEW.job_id,
      'application_id', NEW.id,
      'status',         NEW.status::text
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_trade_on_application_status"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_trade_on_application_status"() IS 'Stream B producer: when an application moves to shortlisted/hired/rejected, inserts an application_status notification for the tradie (applications.trade_id). Central push fanout delivers it. Tradie-driven states (withdrawn/declined) are skipped.';



CREATE OR REPLACE FUNCTION "public"."notify_trade_on_quote_request"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_job_title    text;
  v_builder_name text;
BEGIN
  SELECT j.title INTO v_job_title
    FROM public.jobs j WHERE j.id = NEW.job_id;

  SELECT p.display_name INTO v_builder_name
    FROM public.profiles p WHERE p.id = NEW.builder_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.trade_id,
    'quote_requested',
    'Quote requested',
    COALESCE(NULLIF(v_builder_name, ''), 'A builder')
      || ' asked you to quote "'
      || COALESCE(NULLIF(v_job_title, ''), 'a job')
      || '".',
    jsonb_build_object('job_id', NEW.job_id, 'quote_request_id', NEW.id)
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_trade_on_quote_request"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_trade_on_quote_request"() IS '#18 producer: on a new quote_requests row, notifies the trade (quote_requested). Central push fanout delivers it.';



CREATE OR REPLACE FUNCTION "public"."notify_trades_on_new_job"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.status <> 'open' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT tp.id,
         'new_job',
         'New job near you',
         COALESCE(NULLIF(NEW.title, ''), 'A new job')
           || ' — ' || COALESCE(NULLIF(NEW.trade_type_required, ''), 'trade'),
         jsonb_build_object('job_id', NEW.id, 'trade', NEW.trade_type_required)
    FROM public.trade_profiles tp
   WHERE tp.deleted_at IS NULL
     AND tp.is_available
     AND NEW.trade_type_required <> ''
     AND lower(tp.primary_trade) = lower(NEW.trade_type_required)
     AND tp.id <> NEW.builder_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_trades_on_new_job"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_trades_on_new_job"() IS '#8 in-app fan-out: notifies matching available trades when a job is posted. Trade-type match (geo is a follow-up). FCM push delivery is separate.';



CREATE OR REPLACE FUNCTION "public"."quote_requests_touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."quote_requests_touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  UPDATE public.builder_profiles bp
  SET average_rating = sub.avg_rating,
      rating_count   = sub.cnt
  FROM (
    SELECT round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS cnt
    FROM public.reviews
    WHERE reviewee_id = p_builder_id
  ) sub
  WHERE bp.id = p_builder_id;
$$;


ALTER FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  UPDATE public.trade_profiles tp
  SET average_rating = sub.avg_rating,
      rating_count   = sub.cnt
  FROM (
    SELECT round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS cnt
    FROM public.reviews
    WHERE reviewee_id = p_trade_id
  ) sub
  WHERE tp.id = p_trade_id;
$$;


ALTER FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text" DEFAULT NULL::"text", "p_confirmed_number" "text" DEFAULT NULL::"text", "p_trade_class" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_doc       public.verification_documents%ROWTYPE;
  v_kind      text;
  v_existing  uuid;
  v_doc_label text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'invalid_status: %', p_status;
  END IF;

  UPDATE public.verification_documents
     SET status       = p_status,
         reviewed_at  = now(),
         reviewed_by  = auth.uid(),
         review_notes = COALESCE(NULLIF(btrim(p_notes), ''), review_notes)
   WHERE id = p_document_id
   RETURNING * INTO v_doc;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'document_not_found';
  END IF;

  -- On approval of a CORE credential doc, promote to a verified verifications
  -- row so the status is visible everywhere. Supplementary docs (public
  -- liability, white card, photo id, …) approve but do not create a row.
  IF p_status = 'approved' THEN
    v_kind := CASE v_doc.doc_type
                WHEN 'trade_licence'   THEN 'licence'
                WHEN 'abn_certificate' THEN 'abn'
                ELSE NULL
              END;

    IF v_kind IS NOT NULL THEN
      SELECT id INTO v_existing
        FROM public.verifications
       WHERE user_id = v_doc.trade_id AND kind = v_kind
       ORDER BY updated_at DESC
       LIMIT 1;

      IF v_existing IS NULL THEN
        INSERT INTO public.verifications (
          user_id, kind, status,
          abn, licence_number, licence_state, licence_trade_class,
          register_source, detail_captured_at, verified_at, expires_at,
          manual_fallback_allowed, last_checked_at, failure_reason
        ) VALUES (
          v_doc.trade_id, v_kind, 'verified',
          -- abn: reviewer-confirmed value wins, else the typed document number.
          CASE WHEN v_kind = 'abn'
               THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
          END,
          -- licence_number: reviewer-confirmed value wins, else typed number.
          CASE WHEN v_kind = 'licence'
               THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
          END,
          CASE WHEN v_kind = 'licence' THEN v_doc.state END,
          -- licence_trade_class: reviewer-confirmed class wins, else the class
          -- captured on the document at upload time.
          CASE WHEN v_kind = 'licence'
               THEN COALESCE(NULLIF(btrim(p_trade_class), ''), v_doc.trade_class)
          END,
          'admin_manual', now(), now(), v_doc.expiry_date,
          false, now(), NULL
        );
      ELSE
        UPDATE public.verifications
           SET status                  = 'verified',
               abn                     = CASE WHEN v_kind = 'abn'
                                              THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
                                              ELSE abn END,
               licence_number          = CASE WHEN v_kind = 'licence'
                                              THEN COALESCE(NULLIF(btrim(p_confirmed_number), ''), v_doc.document_number)
                                              ELSE licence_number END,
               licence_state           = CASE WHEN v_kind = 'licence' THEN v_doc.state ELSE licence_state END,
               licence_trade_class     = CASE WHEN v_kind = 'licence'
                                              THEN COALESCE(NULLIF(btrim(p_trade_class), ''), v_doc.trade_class)
                                              ELSE licence_trade_class END,
               register_source         = 'admin_manual',
               detail_captured_at      = now(),
               verified_at             = now(),
               expires_at              = v_doc.expiry_date,
               failure_reason          = NULL,
               manual_fallback_allowed = false,
               last_checked_at         = now(),
               updated_at              = now()
         WHERE id = v_existing;
      END IF;
    END IF;
  END IF;

  -- ALWAYS notify the trade — approve OR reject. The app already understands
  -- these type strings ('verification_approved' / 'verification_rejected') and
  -- routes the tap to the receipts / re-upload surface. Without this, an
  -- approved or rejected trade gets no signal that their status changed (B2).
  v_doc_label := CASE v_doc.doc_type
                   WHEN 'trade_licence'        THEN 'trade licence'
                   WHEN 'abn_certificate'      THEN 'ABN certificate'
                   WHEN 'public_liability'     THEN 'public liability cover'
                   WHEN 'workers_compensation' THEN 'workers compensation cover'
                   WHEN 'white_card'           THEN 'white card'
                   WHEN 'photo_id'             THEN 'photo ID'
                   ELSE 'document'
                 END;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_doc.trade_id,
    CASE WHEN p_status = 'approved' THEN 'verification_approved' ELSE 'verification_rejected' END,
    CASE WHEN p_status = 'approved'
         THEN 'You''re verified'
         ELSE 'Verification needs another look' END,
    CASE WHEN p_status = 'approved'
         THEN 'Your ' || v_doc_label || ' was approved.'
         ELSE 'Your ' || v_doc_label || ' wasn''t approved — tap to re-upload.' END,
    jsonb_build_object(
      'doc_type',    v_doc.doc_type,
      'kind',        v_kind,
      'document_id', p_document_id
    )
  );

  PERFORM public.log_admin_action(
    'review_verification_document',
    'verification_documents',
    p_document_id,
    jsonb_build_object('status', p_status, 'promoted_kind', v_kind)
  );
END;
$$;


ALTER FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") IS 'Admin reviews a manual verification doc atomically: updates the doc, and on approval of a licence/abn doc upserts the verified verifications row (manual path, all states) using the reviewer-confirmed number/class when supplied. ALWAYS notifies the trade on approve/reject. Audited via log_admin_action.';



CREATE OR REPLACE FUNCTION "public"."reviews_sync_trade_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    PERFORM public.recompute_builder_rating(OLD.reviewee_id);
    RETURN OLD;
  END IF;
  PERFORM public.recompute_trade_rating(NEW.reviewee_id);
  PERFORM public.recompute_builder_rating(NEW.reviewee_id);
  IF (TG_OP = 'UPDATE' AND OLD.reviewee_id <> NEW.reviewee_id) THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    PERFORM public.recompute_builder_rating(OLD.reviewee_id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."reviews_sync_trade_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not_admin' USING errcode = '42501';
  END IF;

  IF p_kind NOT IN ('abn', 'licence') THEN
    RAISE EXCEPTION 'invalid_kind: %', p_kind;
  END IF;

  -- Latest verified row for this (user, kind). "Latest" matches the
  -- select-then-upsert convention used elsewhere (no UNIQUE(user_id, kind)).
  SELECT id INTO v_id
    FROM public.verifications
   WHERE user_id = p_user_id
     AND kind    = p_kind
     AND status  = 'verified'
   ORDER BY updated_at DESC
   LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'no_verified_row';
  END IF;

  UPDATE public.verifications
     SET status                  = 'failed',
         failure_reason          = 'admin_revoked: ' || COALESCE(p_reason, ''),
         manual_fallback_allowed = true,
         updated_at              = now()
   WHERE id = v_id;

  -- Reuse the 'verification_rejected' channel the app already understands so
  -- the revoked user is told and pointed back at the re-upload surface.
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    p_user_id,
    'verification_rejected',
    'Verification revoked',
    'Your ' || p_kind || ' verification was revoked'
      || CASE WHEN COALESCE(btrim(p_reason), '') <> ''
              THEN ': ' || btrim(p_reason)
              ELSE '.' END
      || ' Tap to re-verify.',
    jsonb_build_object('kind', p_kind, 'reason', p_reason)
  );

  PERFORM public.log_admin_action(
    'revoke_verification',
    'verifications',
    v_id,
    jsonb_build_object('kind', p_kind, 'reason', p_reason)
  );
END;
$$;


ALTER FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") IS 'Admin un-verify: flips the latest verified (user, kind) row to failed with failure_reason "admin_revoked: <reason>" and re-opens manual fallback. Notifies the user and audits via log_admin_action. The is_verified trigger recomputes cross-user surfaces automatically.';



CREATE OR REPLACE FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric DEFAULT NULL::numeric, "p_available_only" boolean DEFAULT false, "p_query" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "full_name" "text", "primary_trade" "text", "crew_size" integer, "years_experience" integer, "hourly_rate_min" numeric, "hourly_rate_max" numeric, "hourly_rate_visible" boolean, "service_radius_km" integer, "base_suburb" "text", "base_state" "text", "base_postcode" "text", "base_formatted_address" "text", "base_place_id" "text", "base_latitude" double precision, "base_longitude" double precision, "about" "text", "trade_other" "text", "licence_url" "text", "portfolio_urls" "text"[], "is_verified" boolean, "average_rating" numeric, "rating_count" integer, "is_available" boolean, "available_from" "date", "distance_km" double precision)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT * FROM (
    SELECT
      tp.id, tp.full_name, tp.primary_trade, tp.crew_size,
      tp.years_experience, tp.hourly_rate_min, tp.hourly_rate_max,
      tp.hourly_rate_visible, tp.service_radius_km,
      tp.base_suburb, tp.base_state, tp.base_postcode,
      tp.base_formatted_address, tp.base_place_id,
      tp.base_latitude, tp.base_longitude,
      tp.about, tp.trade_other, tp.licence_url, tp.portfolio_urls,
      tp.is_verified,
      tp.average_rating, tp.rating_count,
      tp.is_available, tp.available_from,
      (6371 * acos(least(1.0, greatest(-1.0,
        cos(radians(p_lat)) * cos(radians(tp.base_latitude)) *
        cos(radians(tp.base_longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(tp.base_latitude))
      )))) AS distance_km
    FROM public.trade_profiles tp
    WHERE tp.deleted_at IS NULL
      AND tp.base_latitude  IS NOT NULL
      AND tp.base_longitude IS NOT NULL
      AND tp.base_latitude  BETWEEN
            (p_lat - (p_radius_km / 111.0)) AND (p_lat + (p_radius_km / 111.0))
      AND tp.base_longitude BETWEEN
            (p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))) AND
            (p_lng + (p_radius_km / (111.0 * cos(radians(p_lat)))))
      AND (NOT p_available_only
           OR tp.is_available = true
           OR tp.available_from <= current_date)
      AND (p_min_rating IS NULL OR tp.average_rating >= p_min_rating)
      AND (p_query IS NULL OR p_query = ''
           OR tp.full_name     ILIKE '%' || p_query || '%'
           OR tp.primary_trade ILIKE '%' || p_query || '%'
           OR COALESCE(tp.trade_other, '') ILIKE '%' || p_query || '%')
  ) sub
  WHERE sub.distance_km <= p_radius_km
  ORDER BY sub.distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$;


ALTER FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_phone_verified_at"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- INSERT path: profiles row may not exist yet (handle_new_user fires on the
  -- same INSERT). Use UPDATE-or-skip rather than UPSERT so we don't create
  -- a half-formed profile row from a transient state.
  IF TG_OP = 'INSERT' THEN
    IF NEW.phone IS NOT NULL OR NEW.phone_confirmed_at IS NOT NULL THEN
      UPDATE public.profiles
         SET phone             = NEW.phone,
             phone_verified_at = NEW.phone_confirmed_at,
             updated_at        = now()
       WHERE id = NEW.id
         AND (phone IS DISTINCT FROM NEW.phone
              OR phone_verified_at IS DISTINCT FROM NEW.phone_confirmed_at);
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE path: only write when something actually changed, so updated_at
  -- doesn't thrash on unrelated auth.users updates (session refreshes etc).
  IF NEW.phone             IS DISTINCT FROM OLD.phone
     OR NEW.phone_confirmed_at IS DISTINCT FROM OLD.phone_confirmed_at THEN
    UPDATE public.profiles
       SET phone             = NEW.phone,
           phone_verified_at = NEW.phone_confirmed_at,
           updated_at        = now()
     WHERE id = NEW.id
       AND (phone IS DISTINCT FROM NEW.phone
            OR phone_verified_at IS DISTINCT FROM NEW.phone_confirmed_at);
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_phone_verified_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_phone_verified_at"() IS 'Mirrors auth.users.phone + phone_confirmed_at into public.profiles.phone + phone_verified_at so cross-user views and the profile UI read a single consistent value without needing auth.users access. Service-role isolated via SECURITY DEFINER + search_path = public.';



CREATE OR REPLACE FUNCTION "public"."sync_trade_is_verified"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  affected_user uuid;
  has_verified  boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    affected_user := OLD.user_id;
    IF OLD.kind <> 'licence' THEN
      RETURN OLD;
    END IF;
  ELSE
    affected_user := NEW.user_id;
    -- Skip rows that don't touch the licence channel. Cheap fast-path so
    -- the ABR (kind='abn') hot path isn't taxed.
    IF NEW.kind <> 'licence'
       AND (TG_OP = 'INSERT' OR OLD.kind <> 'licence') THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Truthy if ANY licence row is currently verified — handles multi-state
  -- holders correctly (e.g. dual NSW + VIC where one is suspended).
  SELECT EXISTS (
    SELECT 1
    FROM public.verifications
    WHERE user_id = affected_user
      AND kind    = 'licence'
      AND status  = 'verified'
  ) INTO has_verified;

  -- Only write when the flag actually changes — keeps `updated_at` from
  -- thrashing on every regulator re-check.
  UPDATE public.trade_profiles
     SET is_verified = has_verified,
         updated_at  = now()
   WHERE id           = affected_user
     AND is_verified IS DISTINCT FROM has_verified;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;


ALTER FUNCTION "public"."sync_trade_is_verified"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_trade_is_verified"() IS 'Trigger fn — mirrors verified-licence state into trade_profiles.is_verified so cross-user surfaces (applicant lists, tradie cards) stay in sync with the v2.1 verifications state machine without RLS changes.';



CREATE OR REPLACE FUNCTION "public"."update_conversation_last_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE public.conversations c
     SET last_message_at        = NEW.created_at,
         last_message_preview   = left(NEW.body, 140),
         last_message_sender_id = NEW.sender_id,
         builder_unread_count   = c.builder_unread_count
                                   + CASE WHEN NEW.sender_id = c.trade_id   THEN 1 ELSE 0 END,
         trade_unread_count     = c.trade_unread_count
                                   + CASE WHEN NEW.sender_id = c.builder_id THEN 1 ELSE 0 END
   WHERE c.id = NEW.conversation_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_conversation_last_message"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admin_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "actor_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "target_table" "text",
    "target_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_actions_action_check" CHECK (("action" <> ''::"text"))
);


ALTER TABLE "public"."admin_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid" NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "builder_id" "uuid" NOT NULL,
    "status" "public"."application_status" DEFAULT 'pending'::"public"."application_status" NOT NULL,
    "cover_note" "text",
    "proposed_rate" numeric(10,2),
    "proposed_rate_type" "text",
    "available_from" "date",
    "rejection_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status_changed_at" timestamp with time zone,
    "applied_when_verified_at" timestamp with time zone,
    "verification_snapshot_at_hire" "jsonb",
    "quote_amount" numeric(10,2),
    CONSTRAINT "applications_quote_amount_positive" CHECK ((("quote_amount" IS NULL) OR ("quote_amount" > (0)::numeric)))
);


ALTER TABLE "public"."applications" OWNER TO "postgres";


COMMENT ON COLUMN "public"."applications"."applied_when_verified_at" IS 'Stamp captured at submit-time. Non-null means the trade''s verification was currently active when they applied — kept even if the licence later expires.';



COMMENT ON COLUMN "public"."applications"."verification_snapshot_at_hire" IS 'Captured at the moment status flips to ''accepted''. Shape: {"abn":"verified|none|expired","licence":"verified|none|expired|cancelled|suspended","licence_state":"NSW|VIC|...","as_of":"<iso>"}. Immutable in practice.';



CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid" NOT NULL,
    "builder_id" "uuid" NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "scheduled_date" "date" NOT NULL,
    "note" "text",
    "status" "public"."booking_status" DEFAULT 'scheduled'::"public"."booking_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


COMMENT ON TABLE "public"."bookings" IS '#15 scheduling: a builder schedules a hired trade for a job on a date. Builder owns + must own the job; trade reads + can update status.';



CREATE TABLE IF NOT EXISTS "public"."builder_profiles" (
    "id" "uuid" NOT NULL,
    "company_name" "text",
    "abn" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_name" "text",
    "contact_phone" "text",
    "about" "text",
    "website" "text",
    "years_in_business" integer,
    "service_suburb" "text",
    "service_state" "text",
    "service_postcode" "text",
    "service_formatted_address" "text",
    "service_place_id" "text",
    "service_latitude" double precision,
    "service_longitude" double precision,
    "deleted_at" timestamp with time zone,
    "average_rating" numeric(3,2),
    "rating_count" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."builder_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."builder_unverified_acknowledgements" (
    "builder_id" "uuid" NOT NULL,
    "acknowledged_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "app_version" "text"
);


ALTER TABLE "public"."builder_unverified_acknowledgements" OWNER TO "postgres";


COMMENT ON TABLE "public"."builder_unverified_acknowledgements" IS 'One-time consent that the builder understands the risk of including unverified workers in their applicant filter. Immutable record per builder.';



CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid",
    "builder_id" "uuid" NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "last_message_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "public"."conversation_status" DEFAULT 'active'::"public"."conversation_status" NOT NULL,
    "builder_unread_count" integer DEFAULT 0 NOT NULL,
    "trade_unread_count" integer DEFAULT 0 NOT NULL,
    "last_message_preview" "text",
    "last_message_sender_id" "uuid",
    "builder_archived_at" timestamp with time zone,
    "trade_archived_at" timestamp with time zone,
    "builder_muted_until" timestamp with time zone,
    "trade_muted_until" timestamp with time zone,
    "builder_last_read_at" timestamp with time zone,
    "trade_last_read_at" timestamp with time zone
);

ALTER TABLE ONLY "public"."conversations" REPLICA IDENTITY FULL;


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "platform" "text" DEFAULT 'android'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hidden_jobs" (
    "user_id" "uuid" NOT NULL,
    "job_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."hidden_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "builder_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "trade_type_required" "text" DEFAULT ''::"text" NOT NULL,
    "status" "public"."job_status" DEFAULT 'draft'::"public"."job_status" NOT NULL,
    "suburb" "text" DEFAULT ''::"text" NOT NULL,
    "state" "text" DEFAULT ''::"text" NOT NULL,
    "postcode" "text" DEFAULT ''::"text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "budget_min" numeric(10,2),
    "budget_max" numeric(10,2),
    "budget_type" "public"."budget_type",
    "urgency" "public"."job_urgency" DEFAULT 'standard'::"public"."job_urgency" NOT NULL,
    "start_date" "date",
    "estimated_duration_days" integer,
    "duration_text" "text",
    "requires_white_card" boolean DEFAULT false NOT NULL,
    "requires_public_liability" boolean DEFAULT true NOT NULL,
    "requires_verified" boolean DEFAULT true NOT NULL,
    "required_certifications" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "application_count" integer DEFAULT 0 NOT NULL,
    "view_count" integer DEFAULT 0 NOT NULL,
    "published_at" timestamp with time zone,
    "hired_trade_id" "uuid",
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "search_vector" "tsvector" GENERATED ALWAYS AS ("to_tsvector"('"english"'::"regconfig", ((COALESCE("title", ''::"text") || ' '::"text") || COALESCE("description", ''::"text")))) STORED,
    "formatted_address" "text",
    "place_id" "text",
    "pricing_unit" "public"."job_pricing_unit" DEFAULT 'per_job'::"public"."job_pricing_unit" NOT NULL,
    "pricing_type" "public"."job_pricing_type" DEFAULT 'builder_set'::"public"."job_pricing_type" NOT NULL,
    "budget_amount" numeric(10,2),
    CONSTRAINT "jobs_budget_amount_positive" CHECK ((("budget_amount" IS NULL) OR ("budget_amount" > (0)::numeric))),
    CONSTRAINT "jobs_budget_amount_when_set" CHECK (((("pricing_type" = 'builder_set'::"public"."job_pricing_type") AND ("budget_amount" IS NOT NULL)) OR ("pricing_type" = 'request_quote'::"public"."job_pricing_type")))
);


ALTER TABLE "public"."jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."legal_acceptances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "document_type" "text" NOT NULL,
    "document_version" "text" NOT NULL,
    "accepted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "app_version" "text",
    CONSTRAINT "legal_acceptances_document_type_check" CHECK (("document_type" = ANY (ARRAY['terms_of_service'::"text", 'privacy_policy'::"text"])))
);


ALTER TABLE "public"."legal_acceptances" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."manual_verification_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "verification_id" "uuid",
    "reason" "text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "notes" "text",
    "resolved_by" "uuid",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "manual_verification_requests_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."manual_verification_requests" OWNER TO "postgres";


COMMENT ON TABLE "public"."manual_verification_requests" IS 'Queue for failures the API path cannot recover from automatically — builder ABN issues, regulator outages, circuit-breaker-open routes.';



CREATE TABLE IF NOT EXISTS "public"."message_reactions" (
    "message_id" "uuid" NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "emoji" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE ONLY "public"."message_reactions" REPLICA IDENTITY FULL;


ALTER TABLE "public"."message_reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "edited_at" timestamp with time zone,
    "client_tag" "uuid",
    "attachment_path" "text",
    "attachment_mime" "text",
    "attachment_w" integer,
    "attachment_h" integer
);

ALTER TABLE ONLY "public"."messages" REPLICA IDENTITY FULL;


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "user_id" "uuid" NOT NULL,
    "category" "text" NOT NULL,
    "push_enabled" boolean DEFAULT true NOT NULL,
    "in_app_enabled" boolean DEFAULT true NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_preferences" IS 'Per-user push/in-app opt-out by category. Missing row = enabled (default on). Read by notifications_push_fanout() and the mobile /settings/notifications UI.';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "data" "jsonb",
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE ONLY "public"."notifications" REPLICA IDENTITY FULL;


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone_verified_at" timestamp with time zone,
    "phone" "text",
    "user_status" "public"."user_status" DEFAULT 'active'::"public"."user_status" NOT NULL,
    "status_reason" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."trade_profiles" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "primary_trade" "text",
    "is_verified" boolean DEFAULT false NOT NULL,
    "portfolio_urls" "text"[],
    "years_experience" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "trade_other" "text",
    "about" "text",
    "base_suburb" "text",
    "base_state" "text",
    "base_postcode" "text",
    "licence_url" "text",
    "crew_size" integer DEFAULT 1 NOT NULL,
    "hourly_rate_min" numeric(10,2),
    "hourly_rate_max" numeric(10,2),
    "hourly_rate_visible" boolean DEFAULT true NOT NULL,
    "service_radius_km" integer DEFAULT 50 NOT NULL,
    "base_formatted_address" "text",
    "base_place_id" "text",
    "base_latitude" double precision,
    "base_longitude" double precision,
    "deleted_at" timestamp with time zone,
    "is_available" boolean DEFAULT true NOT NULL,
    "available_from" "date",
    "average_rating" numeric(3,2),
    "rating_count" integer DEFAULT 0 NOT NULL,
    "unavailable_dates" "date"[] DEFAULT '{}'::"date"[] NOT NULL
);


ALTER TABLE "public"."trade_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."trade_profiles"."unavailable_dates" IS '#13 availability calendar: specific dates the trade has blocked off (booked / on leave). Date-only; default empty. Owner-write via the existing trade_profiles RLS; readable by authenticated users for the profile view.';



CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'trade'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_roles_role_check" CHECK (("role" = ANY (ARRAY['builder'::"text", 'trade'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profile_completeness" WITH ("security_invoker"='on') AS
 SELECT "p"."id",
    "ur"."role",
        CASE "ur"."role"
            WHEN 'builder'::"text" THEN ((((((("bp"."company_name" IS NOT NULL) AND ("bp"."company_name" <> ''::"text")))::integer + ((("bp"."abn" IS NOT NULL) AND ("bp"."abn" <> ''::"text")))::integer) + ((("bp"."service_suburb" IS NOT NULL) AND ("bp"."service_suburb" <> ''::"text")))::integer) + (("p"."phone_verified_at" IS NOT NULL))::integer) * 25)
            WHEN 'trade'::"text" THEN (((((((("tp"."primary_trade" IS NOT NULL) AND ("tp"."primary_trade" <> ''::"text")))::integer + ((("tp"."licence_url" IS NOT NULL) AND ("tp"."licence_url" <> ''::"text")))::integer) + ((("tp"."base_suburb" IS NOT NULL) AND ("tp"."base_suburb" <> ''::"text")))::integer) + (("p"."phone_verified_at" IS NOT NULL))::integer) + ((COALESCE("array_length"("tp"."portfolio_urls", 1), 0) > 0))::integer) * 20)
            ELSE NULL::integer
        END AS "completeness_pct"
   FROM ((("public"."profiles" "p"
     LEFT JOIN "public"."user_roles" "ur" ON (("ur"."user_id" = "p"."id")))
     LEFT JOIN "public"."builder_profiles" "bp" ON (("bp"."id" = "p"."id")))
     LEFT JOIN "public"."trade_profiles" "tp" ON (("tp"."id" = "p"."id")))
  WHERE ("p"."id" = "auth"."uid"());


ALTER VIEW "public"."profile_completeness" OWNER TO "postgres";


COMMENT ON VIEW "public"."profile_completeness" IS 'Per-user profile completeness % (0–100). Scoped to auth.uid() at view level; safe to expose via PostgREST. Drives ProfileCompletenessBanner on /home and is the source of truth for completeness in BI dashboards.';



CREATE OR REPLACE VIEW "public"."profiles_public" WITH ("security_invoker"='on') AS
 SELECT "id",
    "display_name",
    "avatar_url"
   FROM "public"."profiles";


ALTER VIEW "public"."profiles_public" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quote_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid" NOT NULL,
    "builder_id" "uuid" NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "status" "public"."quote_request_status" DEFAULT 'requested'::"public"."quote_request_status" NOT NULL,
    "request_note" "text",
    "quote_amount" numeric,
    "response_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "responded_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."quote_requests" OWNER TO "postgres";


COMMENT ON TABLE "public"."quote_requests" IS '#18 builder-initiated quote requests to a specific trade for a job. Builder owns the row + must own the job; trade reads + responds. Notification fan-out + accept→invoice (payments) are follow-ups.';



CREATE TABLE IF NOT EXISTS "public"."regulator_circuit_state" (
    "regulator" "text" NOT NULL,
    "state" "text" DEFAULT 'closed'::"text" NOT NULL,
    "failure_count" integer DEFAULT 0 NOT NULL,
    "success_count" integer DEFAULT 0 NOT NULL,
    "window_started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "opened_at" timestamp with time zone,
    "last_attempt_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "regulator_circuit_state_state_check" CHECK (("state" = ANY (ARRAY['closed'::"text", 'open'::"text", 'half_open'::"text"])))
);


ALTER TABLE "public"."regulator_circuit_state" OWNER TO "postgres";


COMMENT ON TABLE "public"."regulator_circuit_state" IS 'One row per regulator (ABR, NSW, VIC, ...). state=open routes new requests straight to manual_review without calling the regulator.';



CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid" NOT NULL,
    "reviewer_id" "uuid" NOT NULL,
    "reviewee_id" "uuid" NOT NULL,
    "rating" smallint NOT NULL,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewee_verification_snapshot" "jsonb",
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


COMMENT ON COLUMN "public"."reviews"."reviewee_verification_snapshot" IS 'Copied from applications.verification_snapshot_at_hire at review-write time. Surfaces "verified at hire" / "not verified at hire" subtitle in the review UI.';



CREATE TABLE IF NOT EXISTS "public"."saved_jobs" (
    "user_id" "uuid" NOT NULL,
    "job_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."saved_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."timesheets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_id" "uuid" NOT NULL,
    "builder_id" "uuid" NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "check_in_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "check_out_at" timestamp with time zone,
    "check_in_lat" double precision,
    "check_in_lng" double precision,
    "check_out_lat" double precision,
    "check_out_lng" double precision,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."timesheets" OWNER TO "postgres";


COMMENT ON TABLE "public"."timesheets" IS '#16 timesheets: trade clock-on/off per job with optional GPS. Trade owns their rows; builder reads entries on their jobs. Feeds future earnings.';



CREATE TABLE IF NOT EXISTS "public"."trade_categories" (
    "slug" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "trade_categories_category_check" CHECK (("category" = ANY (ARRAY['electrical'::"text", 'structural'::"text", 'finishing'::"text", 'heavy_specialist'::"text"])))
);


ALTER TABLE "public"."trade_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_role_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "old_role" "text",
    "new_role" "text" NOT NULL,
    "changed_by" "uuid",
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_role_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."verification_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "trade_id" "uuid" NOT NULL,
    "type" "text",
    "url" "text",
    "status" "public"."document_status" DEFAULT 'pending'::"public"."document_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "doc_type" "public"."document_doc_type",
    "file_path" "text",
    "submitted_at" timestamp with time zone DEFAULT "now"(),
    "state" "text",
    "issuer" "text",
    "document_number" "text",
    "issued_date" "date",
    "expiry_date" "date",
    "rejection_reason" "text",
    "review_notes" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "trade_class" "text"
);

ALTER TABLE ONLY "public"."verification_documents" REPLICA IDENTITY FULL;


ALTER TABLE "public"."verification_documents" OWNER TO "postgres";


COMMENT ON COLUMN "public"."verification_documents"."trade_class" IS 'Trade class captured at manual licence upload (e.g. "Carpentry", "Electrical"). Copied onto verifications.licence_trade_class when the document is approved so the counterparty badge can render the class.';



CREATE TABLE IF NOT EXISTS "public"."verification_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "verification_id" "uuid" NOT NULL,
    "event_type" "text" NOT NULL,
    "raw_response" "jsonb",
    "actor_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "verification_events_event_type_check" CHECK (("event_type" = ANY (ARRAY['api_call'::"text", 'status_change'::"text", 'manual_override'::"text"])))
);


ALTER TABLE "public"."verification_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."verification_events" IS 'Append-only audit trail. Raw regulator JSONB responses retained for disputes.';



CREATE TABLE IF NOT EXISTS "public"."verification_funnel_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "step" "text" NOT NULL,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."verification_funnel_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."verification_funnel_events" IS 'Wizard funnel telemetry — wizard_open, abn_entered, abn_verified, licence_entered, licence_verified, result_failed, result_manual, continue_tap.';



CREATE TABLE IF NOT EXISTS "public"."verification_rate_limits" (
    "bucket_key" "text" NOT NULL,
    "endpoint" "text" NOT NULL,
    "window_start" timestamp with time zone NOT NULL,
    "attempt_count" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "verification_rate_limits_endpoint_check" CHECK (("endpoint" = ANY (ARRAY['verify-abn'::"text", 'verify-licence'::"text"])))
);


ALTER TABLE "public"."verification_rate_limits" OWNER TO "postgres";


COMMENT ON TABLE "public"."verification_rate_limits" IS 'bucket_key is "user:<uuid>" or "ip:<addr>". Service-role-only writes.';



CREATE TABLE IF NOT EXISTS "public"."verifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "abn" "text",
    "abn_entity_name" "text",
    "licence_number" "text",
    "licence_state" "text",
    "licence_trade_class" "text",
    "status" "public"."verification_status" DEFAULT 'pending'::"public"."verification_status" NOT NULL,
    "verified_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "last_checked_at" timestamp with time zone,
    "failure_reason" "text",
    "manual_fallback_allowed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "entity_type" "text",
    "abn_registered_at" "date",
    "abr_state" "text",
    "abr_postcode" "text",
    "gst_registered" boolean,
    "register_source" "text",
    "detail_captured_at" timestamp with time zone,
    CONSTRAINT "verifications_kind_check" CHECK (("kind" = ANY (ARRAY['abn'::"text", 'licence'::"text"]))),
    CONSTRAINT "verifications_licence_state_check" CHECK (("licence_state" = ANY (ARRAY['NSW'::"text", 'VIC'::"text", 'QLD'::"text", 'SA'::"text", 'WA'::"text", 'TAS'::"text", 'ACT'::"text", 'NT'::"text"])))
);


ALTER TABLE "public"."verifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."verifications" IS 'API-first verification state machine. One row per (user_id, kind). kind=abn for builders and trades; kind=licence for trades only.';



COMMENT ON COLUMN "public"."verifications"."abn_entity_name" IS 'Registered entity name from ABR. Stored alongside the user-entered trading name (builder_profiles.company_name) so both are visible on the badge.';



COMMENT ON COLUMN "public"."verifications"."manual_fallback_allowed" IS 'True only when failure_reason is recoverable (not_found / unknown / timeout). False for cancelled/suspended — those cannot be overridden by a doc upload.';



COMMENT ON COLUMN "public"."verifications"."entity_type" IS 'ABR EntityTypeName, e.g. "Individual/Sole Trader". Replaces the hardcoded "Company" label on the profile COMPANY DETAILS card.';



COMMENT ON COLUMN "public"."verifications"."abn_registered_at" IS 'ABR AbnStatusFromDate — the date the current AbnStatus took effect. Used to render "In business since YYYY" on profiles.';



COMMENT ON COLUMN "public"."verifications"."abr_state" IS 'AU state where the business is registered (from ABR AddressState). Distinct from builder_profiles.service_state (where they actually work).';



COMMENT ON COLUMN "public"."verifications"."abr_postcode" IS 'Postcode of the registered business address (from ABR AddressPostcode). Public information per ABR; storing per Privacy Act exempt-business-info.';



COMMENT ON COLUMN "public"."verifications"."gst_registered" IS 'Whether the ABN is registered for GST (from ABR Gst field). NULL until an ABN verify runs. Register-derived, public per ABR.';



COMMENT ON COLUMN "public"."verifications"."register_source" IS 'Which register produced this row: ''ABR'' (ABN), ''admin_manual'' (admin-approved licence), or a regulator code for future auto-licence adapters.';



COMMENT ON COLUMN "public"."verifications"."detail_captured_at" IS 'The "as at" timestamp for the captured details. ALWAYS shown next to a verified badge so a stale snapshot can never read as a bare "Verified".';



ALTER TABLE ONLY "public"."admin_actions"
    ADD CONSTRAINT "admin_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_trade_id_key" UNIQUE ("job_id", "trade_id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_profiles"
    ADD CONSTRAINT "builder_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_unverified_acknowledgements"
    ADD CONSTRAINT "builder_unverified_acknowledgements_pkey" PRIMARY KEY ("builder_id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."hidden_jobs"
    ADD CONSTRAINT "hidden_jobs_pkey" PRIMARY KEY ("user_id", "job_id");



ALTER TABLE ONLY "public"."jobs"
    ADD CONSTRAINT "jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."legal_acceptances"
    ADD CONSTRAINT "legal_acceptances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."legal_acceptances"
    ADD CONSTRAINT "legal_acceptances_user_id_document_type_document_version_key" UNIQUE ("user_id", "document_type", "document_version");



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_pkey" PRIMARY KEY ("message_id", "user_id");



ALTER TABLE "public"."messages"
    ADD CONSTRAINT "messages_body_len_chk" CHECK ((("char_length"("body") <= 4000) AND (("char_length"("btrim"("body")) >= 1) OR ("attachment_path" IS NOT NULL)))) NOT VALID;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("user_id", "category");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_job_id_trade_id_key" UNIQUE ("job_id", "trade_id");



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."regulator_circuit_state"
    ADD CONSTRAINT "regulator_circuit_state_pkey" PRIMARY KEY ("regulator");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_job_id_reviewer_id_key" UNIQUE ("job_id", "reviewer_id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_jobs"
    ADD CONSTRAINT "saved_jobs_pkey" PRIMARY KEY ("user_id", "job_id");



ALTER TABLE ONLY "public"."timesheets"
    ADD CONSTRAINT "timesheets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trade_categories"
    ADD CONSTRAINT "trade_categories_pkey" PRIMARY KEY ("slug");



ALTER TABLE ONLY "public"."trade_profiles"
    ADD CONSTRAINT "trade_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_role_events"
    ADD CONSTRAINT "user_role_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_events"
    ADD CONSTRAINT "verification_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_funnel_events"
    ADD CONSTRAINT "verification_funnel_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verification_rate_limits"
    ADD CONSTRAINT "verification_rate_limits_pkey" PRIMARY KEY ("bucket_key", "endpoint", "window_start");



ALTER TABLE ONLY "public"."verifications"
    ADD CONSTRAINT "verifications_pkey" PRIMARY KEY ("id");



CREATE INDEX "admin_actions_actor_id_idx" ON "public"."admin_actions" USING "btree" ("actor_id");



CREATE INDEX "admin_actions_created_at_idx" ON "public"."admin_actions" USING "btree" ("created_at" DESC);



CREATE INDEX "admin_actions_target_idx" ON "public"."admin_actions" USING "btree" ("target_table", "target_id");



CREATE INDEX "applications_builder_id_idx" ON "public"."applications" USING "btree" ("builder_id");



CREATE INDEX "applications_job_id_idx" ON "public"."applications" USING "btree" ("job_id");



CREATE INDEX "applications_trade_id_idx" ON "public"."applications" USING "btree" ("trade_id");



CREATE INDEX "bookings_builder_idx" ON "public"."bookings" USING "btree" ("builder_id");



CREATE INDEX "bookings_date_idx" ON "public"."bookings" USING "btree" ("scheduled_date");



CREATE INDEX "bookings_trade_idx" ON "public"."bookings" USING "btree" ("trade_id");



CREATE INDEX "builder_profiles_average_rating_idx" ON "public"."builder_profiles" USING "btree" ("average_rating");



CREATE INDEX "conversations_builder_active_idx" ON "public"."conversations" USING "btree" ("builder_id", "last_message_at" DESC) WHERE ("builder_archived_at" IS NULL);



CREATE INDEX "conversations_builder_id_idx" ON "public"."conversations" USING "btree" ("builder_id");



CREATE INDEX "conversations_trade_active_idx" ON "public"."conversations" USING "btree" ("trade_id", "last_message_at" DESC) WHERE ("trade_archived_at" IS NULL);



CREATE INDEX "conversations_trade_id_idx" ON "public"."conversations" USING "btree" ("trade_id");



CREATE UNIQUE INDEX "conversations_uniq_no_job" ON "public"."conversations" USING "btree" ("builder_id", "trade_id") WHERE ("job_id" IS NULL);



CREATE UNIQUE INDEX "conversations_uniq_with_job" ON "public"."conversations" USING "btree" ("job_id", "builder_id", "trade_id") WHERE ("job_id" IS NOT NULL);



CREATE INDEX "hidden_jobs_user_id_idx" ON "public"."hidden_jobs" USING "btree" ("user_id");



CREATE INDEX "idx_bookings_job_id" ON "public"."bookings" USING "btree" ("job_id");



CREATE INDEX "idx_builder_profiles_active" ON "public"."builder_profiles" USING "btree" ("id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_builder_profiles_service_latlng" ON "public"."builder_profiles" USING "btree" ("service_latitude", "service_longitude");



CREATE INDEX "idx_conversations_last_sender" ON "public"."conversations" USING "btree" ("last_message_sender_id");



CREATE INDEX "idx_hidden_jobs_job_id" ON "public"."hidden_jobs" USING "btree" ("job_id");



CREATE INDEX "idx_jobs_hired_trade_id" ON "public"."jobs" USING "btree" ("hired_trade_id");



CREATE INDEX "idx_legal_acceptances_user" ON "public"."legal_acceptances" USING "btree" ("user_id", "document_type");



CREATE INDEX "idx_message_reactions_user" ON "public"."message_reactions" USING "btree" ("user_id");



CREATE INDEX "idx_mvr_resolved_by" ON "public"."manual_verification_requests" USING "btree" ("resolved_by");



CREATE INDEX "idx_mvr_user_id" ON "public"."manual_verification_requests" USING "btree" ("user_id");



CREATE INDEX "idx_mvr_verification_id" ON "public"."manual_verification_requests" USING "btree" ("verification_id");



CREATE INDEX "idx_reviews_reviewer_id" ON "public"."reviews" USING "btree" ("reviewer_id");



CREATE INDEX "idx_saved_jobs_job_id" ON "public"."saved_jobs" USING "btree" ("job_id");



CREATE INDEX "idx_timesheets_builder_id" ON "public"."timesheets" USING "btree" ("builder_id");



CREATE INDEX "idx_trade_profiles_active" ON "public"."trade_profiles" USING "btree" ("id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_trade_profiles_base_latlng" ON "public"."trade_profiles" USING "btree" ("base_latitude", "base_longitude");



CREATE INDEX "idx_ure_changed_by" ON "public"."user_role_events" USING "btree" ("changed_by");



CREATE INDEX "idx_vd_reviewed_by" ON "public"."verification_documents" USING "btree" ("reviewed_by");



CREATE INDEX "idx_verification_events_actor" ON "public"."verification_events" USING "btree" ("actor_id");



CREATE INDEX "idx_vfe_user_id" ON "public"."verification_funnel_events" USING "btree" ("user_id");



CREATE INDEX "jobs_builder_id_idx" ON "public"."jobs" USING "btree" ("builder_id");



CREATE INDEX "jobs_search_vector_idx" ON "public"."jobs" USING "gin" ("search_vector");



CREATE INDEX "jobs_status_idx" ON "public"."jobs" USING "btree" ("status");



CREATE INDEX "jobs_trade_type_idx" ON "public"."jobs" USING "btree" ("trade_type_required");



CREATE INDEX "manual_verif_requests_open_idx" ON "public"."manual_verification_requests" USING "btree" ("created_at" DESC) WHERE ("status" = 'open'::"text");



CREATE INDEX "message_reactions_conversation_idx" ON "public"."message_reactions" USING "btree" ("conversation_id");



CREATE UNIQUE INDEX "messages_conv_client_tag_uidx" ON "public"."messages" USING "btree" ("conversation_id", "client_tag");



CREATE INDEX "messages_conversation_id_idx" ON "public"."messages" USING "btree" ("conversation_id");



CREATE INDEX "messages_sender_id_idx" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "messages_thread_feed_idx" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC) WHERE ("deleted_at" IS NULL);



CREATE INDEX "notifications_read_at_idx" ON "public"."notifications" USING "btree" ("user_id", "read_at") WHERE ("read_at" IS NULL);



CREATE INDEX "notifications_user_id_idx" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "quote_requests_builder_idx" ON "public"."quote_requests" USING "btree" ("builder_id");



CREATE INDEX "quote_requests_trade_idx" ON "public"."quote_requests" USING "btree" ("trade_id");



CREATE INDEX "rate_limits_lookup_idx" ON "public"."verification_rate_limits" USING "btree" ("bucket_key", "endpoint", "window_start" DESC);



CREATE INDEX "reviews_reviewee_id_idx" ON "public"."reviews" USING "btree" ("reviewee_id");



CREATE INDEX "saved_jobs_user_id_created_at_idx" ON "public"."saved_jobs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "timesheets_job_idx" ON "public"."timesheets" USING "btree" ("job_id");



CREATE INDEX "timesheets_trade_idx" ON "public"."timesheets" USING "btree" ("trade_id");



CREATE INDEX "trade_profiles_average_rating_idx" ON "public"."trade_profiles" USING "btree" ("average_rating");



CREATE INDEX "trade_profiles_is_available_idx" ON "public"."trade_profiles" USING "btree" ("is_available");



CREATE INDEX "user_role_events_created_at_idx" ON "public"."user_role_events" USING "btree" ("created_at" DESC);



CREATE INDEX "user_role_events_user_id_idx" ON "public"."user_role_events" USING "btree" ("user_id");



CREATE INDEX "verification_documents_expiry_idx" ON "public"."verification_documents" USING "btree" ("expiry_date") WHERE (("status" = 'approved'::"public"."document_status") AND ("deleted_at" IS NULL) AND ("expiry_date" IS NOT NULL));



CREATE INDEX "verification_documents_trade_id_idx" ON "public"."verification_documents" USING "btree" ("trade_id");



CREATE INDEX "verification_events_vid_idx" ON "public"."verification_events" USING "btree" ("verification_id", "created_at" DESC);



CREATE INDEX "verification_funnel_step_idx" ON "public"."verification_funnel_events" USING "btree" ("step", "created_at" DESC);



CREATE INDEX "verifications_expiring_idx" ON "public"."verifications" USING "btree" ("expires_at") WHERE ("status" = 'verified'::"public"."verification_status");



CREATE INDEX "verifications_kind_status_idx" ON "public"."verifications" USING "btree" ("kind", "status");



CREATE INDEX "verifications_recheck_idx" ON "public"."verifications" USING "btree" ("last_checked_at") WHERE ("status" = 'verified'::"public"."verification_status");



CREATE INDEX "verifications_status_idx" ON "public"."verifications" USING "btree" ("status") WHERE ("status" = ANY (ARRAY['pending'::"public"."verification_status", 'manual_review'::"public"."verification_status"]));



CREATE INDEX "verifications_user_idx" ON "public"."verifications" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "applications_protect_quote" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."applications_protect_quote"();



CREATE OR REPLACE TRIGGER "applications_updated_at" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "bookings_touch_updated_at_trg" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."bookings_touch_updated_at"();



CREATE OR REPLACE TRIGGER "builder_profiles_pin_verified_abn_trg" BEFORE UPDATE ON "public"."builder_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."builder_profiles_pin_verified_abn"();



CREATE OR REPLACE TRIGGER "builder_profiles_updated_at" BEFORE UPDATE ON "public"."builder_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "jobs_updated_at" BEFORE UPDATE ON "public"."jobs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "messages_update_last_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_conversation_last_message"();



CREATE OR REPLACE TRIGGER "notifications_push_fanout_trg" AFTER INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."notifications_push_fanout"();



CREATE OR REPLACE TRIGGER "notify_builder_on_new_application_trg" AFTER INSERT ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."notify_builder_on_new_application"();



CREATE OR REPLACE TRIGGER "notify_builder_on_quote_response_trg" AFTER UPDATE OF "status" ON "public"."quote_requests" FOR EACH ROW WHEN ((("old"."status" IS DISTINCT FROM "new"."status") AND ("new"."status" = ANY (ARRAY['quoted'::"public"."quote_request_status", 'declined'::"public"."quote_request_status"])))) EXECUTE FUNCTION "public"."notify_builder_on_quote_response"();



CREATE OR REPLACE TRIGGER "notify_on_new_message_trg" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_new_message"();



CREATE OR REPLACE TRIGGER "notify_trade_on_application_status_trg" AFTER UPDATE OF "status" ON "public"."applications" FOR EACH ROW WHEN ((("old"."status" IS DISTINCT FROM "new"."status") AND ("new"."status" = ANY (ARRAY['shortlisted'::"public"."application_status", 'hired'::"public"."application_status", 'rejected'::"public"."application_status"])))) EXECUTE FUNCTION "public"."notify_trade_on_application_status"();



CREATE OR REPLACE TRIGGER "notify_trade_on_quote_request_trg" AFTER INSERT ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."notify_trade_on_quote_request"();



CREATE OR REPLACE TRIGGER "notify_trades_on_new_job_trg" AFTER INSERT ON "public"."jobs" FOR EACH ROW EXECUTE FUNCTION "public"."notify_trades_on_new_job"();



CREATE OR REPLACE TRIGGER "profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "quote_requests_touch_updated_at_trg" BEFORE UPDATE ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."quote_requests_touch_updated_at"();



CREATE OR REPLACE TRIGGER "reviews_sync_trade_rating_trg" AFTER INSERT OR DELETE OR UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."reviews_sync_trade_rating"();



CREATE OR REPLACE TRIGGER "trade_profiles_updated_at" BEFORE UPDATE ON "public"."trade_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_forbid_role_mutation" BEFORE UPDATE ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_role_mutation"();



CREATE OR REPLACE TRIGGER "trg_log_role_event" AFTER INSERT OR UPDATE OF "role" ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."log_role_event"();



CREATE OR REPLACE TRIGGER "user_roles_forbid_self_admin" BEFORE INSERT ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_self_admin"();



CREATE OR REPLACE TRIGGER "verification_documents_updated_at" BEFORE UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "verifications_sync_trade_is_verified" AFTER INSERT OR DELETE OR UPDATE ON "public"."verifications" FOR EACH ROW EXECUTE FUNCTION "public"."sync_trade_is_verified"();



CREATE OR REPLACE TRIGGER "verifications_updated_at" BEFORE UPDATE ON "public"."verifications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."admin_actions"
    ADD CONSTRAINT "admin_actions_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."builder_profiles"
    ADD CONSTRAINT "builder_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."builder_unverified_acknowledgements"
    ADD CONSTRAINT "builder_unverified_acknowledgements_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_last_message_sender_id_fkey" FOREIGN KEY ("last_message_sender_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hidden_jobs"
    ADD CONSTRAINT "hidden_jobs_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hidden_jobs"
    ADD CONSTRAINT "hidden_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jobs"
    ADD CONSTRAINT "jobs_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."jobs"
    ADD CONSTRAINT "jobs_hired_trade_id_fkey" FOREIGN KEY ("hired_trade_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."legal_acceptances"
    ADD CONSTRAINT "legal_acceptances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_verification_id_fkey" FOREIGN KEY ("verification_id") REFERENCES "public"."verifications"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."message_reactions"
    ADD CONSTRAINT "message_reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quote_requests"
    ADD CONSTRAINT "quote_requests_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_reviewee_id_fkey" FOREIGN KEY ("reviewee_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saved_jobs"
    ADD CONSTRAINT "saved_jobs_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saved_jobs"
    ADD CONSTRAINT "saved_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timesheets"
    ADD CONSTRAINT "timesheets_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timesheets"
    ADD CONSTRAINT "timesheets_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."timesheets"
    ADD CONSTRAINT "timesheets_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trade_profiles"
    ADD CONSTRAINT "trade_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_role_events"
    ADD CONSTRAINT "user_role_events_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_role_events"
    ADD CONSTRAINT "user_role_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_events"
    ADD CONSTRAINT "verification_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verification_events"
    ADD CONSTRAINT "verification_events_verification_id_fkey" FOREIGN KEY ("verification_id") REFERENCES "public"."verifications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_funnel_events"
    ADD CONSTRAINT "verification_funnel_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verifications"
    ADD CONSTRAINT "verifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Admins read all acceptances" ON "public"."legal_acceptances" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "Users insert own acceptances" ON "public"."legal_acceptances" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own acceptances" ON "public"."legal_acceptances" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."admin_actions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_actions_admin_read" ON "public"."admin_actions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



ALTER TABLE "public"."applications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "applications_admin_read" ON "public"."applications" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("ur"."role" = 'admin'::"text")))));



CREATE POLICY "applications_insert_trade" ON "public"."applications" FOR INSERT WITH CHECK (("auth"."uid"() = "trade_id"));



CREATE POLICY "applications_select" ON "public"."applications" FOR SELECT USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



CREATE POLICY "applications_update" ON "public"."applications" FOR UPDATE USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bookings_builder_all" ON "public"."bookings" TO "authenticated" USING (("builder_id" = "auth"."uid"())) WITH CHECK ((("builder_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."jobs" "j"
  WHERE (("j"."id" = "bookings"."job_id") AND ("j"."builder_id" = "auth"."uid"()))))));



CREATE POLICY "bookings_trade_select" ON "public"."bookings" FOR SELECT TO "authenticated" USING (("trade_id" = "auth"."uid"()));



CREATE POLICY "bookings_trade_update" ON "public"."bookings" FOR UPDATE TO "authenticated" USING (("trade_id" = "auth"."uid"())) WITH CHECK (("trade_id" = "auth"."uid"()));



CREATE POLICY "buak_admin_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "buak_owner_insert" ON "public"."builder_unverified_acknowledgements" FOR INSERT WITH CHECK (("auth"."uid"() = "builder_id"));



CREATE POLICY "buak_owner_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT USING (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."builder_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "builder_profiles_admin_read" ON "public"."builder_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("ur"."role" = 'admin'::"text")))));



CREATE POLICY "builder_profiles_insert_own" ON "public"."builder_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "builder_profiles_select_authenticated" ON "public"."builder_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "builder_profiles"."id") AND ("ur"."role" = 'builder'::"text")))));



CREATE POLICY "builder_profiles_update_own" ON "public"."builder_profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."builder_unverified_acknowledgements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_insert" ON "public"."conversations" FOR INSERT WITH CHECK ((("auth"."uid"() = "builder_id") OR ("auth"."uid"() = "trade_id")));



CREATE POLICY "conversations_select" ON "public"."conversations" FOR SELECT USING ((("auth"."uid"() = "builder_id") OR ("auth"."uid"() = "trade_id")));



CREATE POLICY "conversations_update_participant" ON "public"."conversations" FOR UPDATE USING ((("auth"."uid"() = "builder_id") OR ("auth"."uid"() = "trade_id"))) WITH CHECK ((("auth"."uid"() = "builder_id") OR ("auth"."uid"() = "trade_id")));



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_tokens_owner" ON "public"."device_tokens" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."hidden_jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "hidden_jobs_delete_own" ON "public"."hidden_jobs" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "hidden_jobs_insert_own" ON "public"."hidden_jobs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "hidden_jobs_select_own" ON "public"."hidden_jobs" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "jobs_admin_read" ON "public"."jobs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("ur"."role" = 'admin'::"text")))));



CREATE POLICY "jobs_delete_own" ON "public"."jobs" FOR DELETE USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_insert_own" ON "public"."jobs" FOR INSERT WITH CHECK ((("auth"."uid"() = "builder_id") AND "public"."is_builder_abn_verified"("auth"."uid"())));



CREATE POLICY "jobs_select_open" ON "public"."jobs" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ("status" = ANY (ARRAY['open'::"public"."job_status", 'filled'::"public"."job_status"])) AND ("deleted_at" IS NULL)));



CREATE POLICY "jobs_select_own" ON "public"."jobs" FOR SELECT USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_update_own" ON "public"."jobs" FOR UPDATE USING (("auth"."uid"() = "builder_id")) WITH CHECK (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."legal_acceptances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."manual_verification_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_insert" ON "public"."messages" FOR INSERT WITH CHECK ((("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"())))))));



CREATE POLICY "messages_modify_own" ON "public"."messages" FOR UPDATE USING (("sender_id" = "auth"."uid"())) WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_select" ON "public"."messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "mvr_admin_read" ON "public"."manual_verification_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "mvr_no_client_insert" ON "public"."manual_verification_requests" FOR INSERT WITH CHECK (false);



CREATE POLICY "mvr_owner_read" ON "public"."manual_verification_requests" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notification_preferences_owner" ON "public"."notification_preferences" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_admin_read" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("ur"."role" = 'admin'::"text")))));



CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."quote_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "quote_requests_builder_all" ON "public"."quote_requests" TO "authenticated" USING (("builder_id" = "auth"."uid"())) WITH CHECK ((("builder_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."jobs" "j"
  WHERE (("j"."id" = "quote_requests"."job_id") AND ("j"."builder_id" = "auth"."uid"()))))));



CREATE POLICY "quote_requests_trade_select" ON "public"."quote_requests" FOR SELECT TO "authenticated" USING (("trade_id" = "auth"."uid"()));



CREATE POLICY "quote_requests_trade_update" ON "public"."quote_requests" FOR UPDATE TO "authenticated" USING (("trade_id" = "auth"."uid"())) WITH CHECK (("trade_id" = "auth"."uid"()));



CREATE POLICY "reactions_delete" ON "public"."message_reactions" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "reactions_insert" ON "public"."message_reactions" FOR INSERT WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "message_reactions"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"())))))));



CREATE POLICY "reactions_select" ON "public"."message_reactions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "message_reactions"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "reactions_update" ON "public"."message_reactions" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."regulator_circuit_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reviews_insert_reviewer" ON "public"."reviews" FOR INSERT WITH CHECK (("auth"."uid"() = "reviewer_id"));



CREATE POLICY "reviews_select_authenticated" ON "public"."reviews" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "role_events_admin_all" ON "public"."user_role_events" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "role_events_select_own" ON "public"."user_role_events" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."saved_jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "saved_jobs_delete_own" ON "public"."saved_jobs" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "saved_jobs_insert_own" ON "public"."saved_jobs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "saved_jobs_select_own" ON "public"."saved_jobs" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."timesheets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "timesheets_builder_select" ON "public"."timesheets" FOR SELECT TO "authenticated" USING (("builder_id" = "auth"."uid"()));



CREATE POLICY "timesheets_trade_all" ON "public"."timesheets" TO "authenticated" USING (("trade_id" = "auth"."uid"())) WITH CHECK (("trade_id" = "auth"."uid"()));



ALTER TABLE "public"."trade_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_categories_select_all" ON "public"."trade_categories" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."trade_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_profiles_admin_read" ON "public"."trade_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("ur"."role" = 'admin'::"text")))));



CREATE POLICY "trade_profiles_insert_own" ON "public"."trade_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "trade_profiles_select_authenticated" ON "public"."trade_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "trade_profiles"."id") AND ("ur"."role" = 'trade'::"text")))));



CREATE POLICY "trade_profiles_update_own" ON "public"."trade_profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."user_role_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_roles_admin_read" ON "public"."user_roles" FOR SELECT TO "authenticated" USING ((COALESCE(("auth"."jwt"() ->> 'user_role'::"text"), ''::"text") = 'admin'::"text"));



CREATE POLICY "user_roles_insert_own" ON "public"."user_roles" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND ("role" = ANY (ARRAY['builder'::"text", 'trade'::"text"]))));



CREATE POLICY "user_roles_select_own" ON "public"."user_roles" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."verification_documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_documents_admin_select" ON "public"."verification_documents" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "verification_documents_admin_update" ON "public"."verification_documents" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "verification_documents_insert_own" ON "public"."verification_documents" FOR INSERT WITH CHECK (("auth"."uid"() = "trade_id"));



CREATE POLICY "verification_documents_select_own" ON "public"."verification_documents" FOR SELECT USING (("auth"."uid"() = "trade_id"));



CREATE POLICY "verification_documents_update_own" ON "public"."verification_documents" FOR UPDATE USING (("auth"."uid"() = "trade_id")) WITH CHECK (("auth"."uid"() = "trade_id"));



ALTER TABLE "public"."verification_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_events_admin_read" ON "public"."verification_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "verification_events_no_client_insert" ON "public"."verification_events" FOR INSERT WITH CHECK (false);



CREATE POLICY "verification_events_owner_read" ON "public"."verification_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."verifications" "v"
  WHERE (("v"."id" = "verification_events"."verification_id") AND ("v"."user_id" = "auth"."uid"())))));



CREATE POLICY "verification_funnel_admin_read" ON "public"."verification_funnel_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



ALTER TABLE "public"."verification_funnel_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_funnel_insert_own" ON "public"."verification_funnel_events" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("user_id" IS NULL)));



ALTER TABLE "public"."verification_rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."verifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verifications_admin_read" ON "public"."verifications" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "verifications_no_client_delete" ON "public"."verifications" FOR DELETE USING (false);



CREATE POLICY "verifications_no_client_insert" ON "public"."verifications" FOR INSERT WITH CHECK (false);



CREATE POLICY "verifications_no_client_update" ON "public"."verifications" FOR UPDATE USING (false);



CREATE POLICY "verifications_owner_read" ON "public"."verifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "anon";
GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "service_role";



GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."builder_profiles_pin_verified_abn"() TO "anon";
GRANT ALL ON FUNCTION "public"."builder_profiles_pin_verified_abn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."builder_profiles_pin_verified_abn"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."delete_my_account"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."expire_stale_verifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."expire_stale_verifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."expire_stale_verifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_role_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_role_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_role_event"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."notifications_push_fanout"() TO "anon";
GRANT ALL ON FUNCTION "public"."notifications_push_fanout"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notifications_push_fanout"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_builder_on_new_application"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_builder_on_new_application"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_builder_on_new_application"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_builder_on_quote_response"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_builder_on_quote_response"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_builder_on_quote_response"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_trade_on_application_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_trade_on_application_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_trade_on_application_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_trade_on_quote_request"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_trade_on_quote_request"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_trade_on_quote_request"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_trades_on_new_job"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_trades_on_new_job"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_trades_on_new_job"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."reviews_sync_trade_rating"() TO "anon";
GRANT ALL ON FUNCTION "public"."reviews_sync_trade_rating"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reviews_sync_trade_rating"() TO "service_role";



GRANT ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_trade_is_verified"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_trade_is_verified"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_trade_is_verified"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "service_role";



GRANT ALL ON TABLE "public"."admin_actions" TO "anon";
GRANT ALL ON TABLE "public"."admin_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_actions" TO "service_role";



GRANT ALL ON TABLE "public"."applications" TO "anon";
GRANT ALL ON TABLE "public"."applications" TO "authenticated";
GRANT ALL ON TABLE "public"."applications" TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON TABLE "public"."builder_profiles" TO "anon";
GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."builder_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_profiles" TO "service_role";



GRANT INSERT("id"),UPDATE("id") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("company_name"),UPDATE("company_name") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("abn"),UPDATE("abn") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("contact_name"),UPDATE("contact_name") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("contact_phone"),UPDATE("contact_phone") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("about"),UPDATE("about") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("website"),UPDATE("website") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("years_in_business"),UPDATE("years_in_business") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_suburb"),UPDATE("service_suburb") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_state"),UPDATE("service_state") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_postcode"),UPDATE("service_postcode") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_formatted_address"),UPDATE("service_formatted_address") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_place_id"),UPDATE("service_place_id") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_latitude"),UPDATE("service_latitude") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT INSERT("service_longitude"),UPDATE("service_longitude") ON TABLE "public"."builder_profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "anon";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."hidden_jobs" TO "anon";
GRANT ALL ON TABLE "public"."hidden_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."hidden_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."jobs" TO "anon";
GRANT ALL ON TABLE "public"."jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."jobs" TO "service_role";



GRANT ALL ON TABLE "public"."legal_acceptances" TO "anon";
GRANT ALL ON TABLE "public"."legal_acceptances" TO "authenticated";
GRANT ALL ON TABLE "public"."legal_acceptances" TO "service_role";



GRANT ALL ON TABLE "public"."manual_verification_requests" TO "anon";
GRANT ALL ON TABLE "public"."manual_verification_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."manual_verification_requests" TO "service_role";



GRANT ALL ON TABLE "public"."message_reactions" TO "anon";
GRANT ALL ON TABLE "public"."message_reactions" TO "authenticated";
GRANT ALL ON TABLE "public"."message_reactions" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preferences" TO "anon";
GRANT ALL ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."trade_profiles" TO "anon";
GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."trade_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_profiles" TO "service_role";



GRANT INSERT("id"),UPDATE("id") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("full_name"),UPDATE("full_name") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("primary_trade"),UPDATE("primary_trade") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("portfolio_urls"),UPDATE("portfolio_urls") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("years_experience"),UPDATE("years_experience") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("trade_other"),UPDATE("trade_other") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("about"),UPDATE("about") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_suburb"),UPDATE("base_suburb") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_state"),UPDATE("base_state") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_postcode"),UPDATE("base_postcode") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("licence_url"),UPDATE("licence_url") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("crew_size"),UPDATE("crew_size") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("hourly_rate_min"),UPDATE("hourly_rate_min") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("hourly_rate_max"),UPDATE("hourly_rate_max") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("hourly_rate_visible"),UPDATE("hourly_rate_visible") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("service_radius_km"),UPDATE("service_radius_km") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_formatted_address"),UPDATE("base_formatted_address") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_place_id"),UPDATE("base_place_id") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_latitude"),UPDATE("base_latitude") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("base_longitude"),UPDATE("base_longitude") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("is_available"),UPDATE("is_available") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("available_from"),UPDATE("available_from") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT INSERT("unavailable_dates"),UPDATE("unavailable_dates") ON TABLE "public"."trade_profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."profile_completeness" TO "anon";
GRANT ALL ON TABLE "public"."profile_completeness" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_completeness" TO "service_role";



GRANT ALL ON TABLE "public"."profiles_public" TO "anon";
GRANT ALL ON TABLE "public"."profiles_public" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_public" TO "service_role";



GRANT ALL ON TABLE "public"."quote_requests" TO "anon";
GRANT ALL ON TABLE "public"."quote_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."quote_requests" TO "service_role";



GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "anon";
GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "authenticated";
GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."saved_jobs" TO "anon";
GRANT ALL ON TABLE "public"."saved_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."saved_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."timesheets" TO "anon";
GRANT ALL ON TABLE "public"."timesheets" TO "authenticated";
GRANT ALL ON TABLE "public"."timesheets" TO "service_role";



GRANT ALL ON TABLE "public"."trade_categories" TO "anon";
GRANT ALL ON TABLE "public"."trade_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_categories" TO "service_role";



GRANT ALL ON TABLE "public"."user_role_events" TO "anon";
GRANT ALL ON TABLE "public"."user_role_events" TO "authenticated";
GRANT ALL ON TABLE "public"."user_role_events" TO "service_role";



GRANT ALL ON TABLE "public"."verification_documents" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."verification_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_documents" TO "service_role";



GRANT UPDATE("deleted_at") ON TABLE "public"."verification_documents" TO "authenticated";



GRANT ALL ON TABLE "public"."verification_events" TO "anon";
GRANT ALL ON TABLE "public"."verification_events" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_events" TO "service_role";



GRANT ALL ON TABLE "public"."verification_funnel_events" TO "anon";
GRANT ALL ON TABLE "public"."verification_funnel_events" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_funnel_events" TO "service_role";



GRANT ALL ON TABLE "public"."verification_rate_limits" TO "anon";
GRANT ALL ON TABLE "public"."verification_rate_limits" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_rate_limits" TO "service_role";



GRANT ALL ON TABLE "public"."verifications" TO "anon";
GRANT ALL ON TABLE "public"."verifications" TO "authenticated";
GRANT ALL ON TABLE "public"."verifications" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







