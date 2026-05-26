


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


CREATE TYPE "public"."verification_status" AS ENUM (
    'pending',
    'verified',
    'failed',
    'expired',
    'suspended',
    'manual_review'
);


ALTER TYPE "public"."verification_status" OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_display_name text;
  v_role         text;
BEGIN
  v_display_name := NEW.raw_user_meta_data->>'full_name';
  v_role         := NEW.raw_user_meta_data->>'role';

  INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, v_display_name)
    ON CONFLICT (id) DO NOTHING;

  -- admin role intentionally NOT accepted from client metadata (F-RLS-01).
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id)
        VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name) ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


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
  -- Insert path: profiles row may not exist yet (handle_new_user fires on
  -- the same INSERT). Use UPDATE-or-skip rather than UPSERT so we don't
  -- accidentally create a half-formed profile row.
  IF (TG_OP = 'INSERT' AND NEW.phone_confirmed_at IS NOT NULL)
     OR (TG_OP = 'UPDATE'
         AND NEW.phone_confirmed_at IS DISTINCT FROM OLD.phone_confirmed_at) THEN
    UPDATE public.profiles
       SET phone_verified_at = NEW.phone_confirmed_at
     WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_phone_verified_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_conversation_last_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_conversation_last_message"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


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
    "verification_snapshot_at_hire" "jsonb"
);


ALTER TABLE "public"."applications" OWNER TO "postgres";


COMMENT ON COLUMN "public"."applications"."applied_when_verified_at" IS 'Stamp captured at submit-time. Non-null means the trade''s verification was currently active when they applied — kept even if the licence later expires.';



COMMENT ON COLUMN "public"."applications"."verification_snapshot_at_hire" IS 'Captured at the moment status flips to ''accepted''. Shape: {"abn":"verified|none|expired","licence":"verified|none|expired|cancelled|suspended","licence_state":"NSW|VIC|...","as_of":"<iso>"}. Immutable in practice.';



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
    "deleted_at" timestamp with time zone
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
    "trade_muted_until" timestamp with time zone
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


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
    "place_id" "text"
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



CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "edited_at" timestamp with time zone
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


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


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone_verified_at" timestamp with time zone,
    "phone" "text"
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
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."trade_profiles" OWNER TO "postgres";


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
    "submitted_at" timestamp with time zone,
    "state" "text",
    "issuer" "text",
    "document_number" "text",
    "issued_date" "date",
    "expiry_date" "date",
    "rejection_reason" "text",
    "review_notes" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."verification_documents" OWNER TO "postgres";


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
    CONSTRAINT "verifications_kind_check" CHECK (("kind" = ANY (ARRAY['abn'::"text", 'licence'::"text"]))),
    CONSTRAINT "verifications_licence_state_check" CHECK (("licence_state" = ANY (ARRAY['NSW'::"text", 'VIC'::"text", 'QLD'::"text", 'SA'::"text", 'WA'::"text", 'TAS'::"text", 'ACT'::"text", 'NT'::"text"])))
);


ALTER TABLE "public"."verifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."verifications" IS 'API-first verification state machine. One row per (user_id, kind). kind=abn for builders and trades; kind=licence for trades only.';



COMMENT ON COLUMN "public"."verifications"."abn_entity_name" IS 'Registered entity name from ABR. Stored alongside the user-entered trading name (builder_profiles.company_name) so both are visible on the badge.';



COMMENT ON COLUMN "public"."verifications"."manual_fallback_allowed" IS 'True only when failure_reason is recoverable (not_found / unknown / timeout). False for cancelled/suspended — those cannot be overridden by a doc upload.';



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_trade_id_key" UNIQUE ("job_id", "trade_id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_profiles"
    ADD CONSTRAINT "builder_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_unverified_acknowledgements"
    ADD CONSTRAINT "builder_unverified_acknowledgements_pkey" PRIMARY KEY ("builder_id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."regulator_circuit_state"
    ADD CONSTRAINT "regulator_circuit_state_pkey" PRIMARY KEY ("regulator");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_job_id_reviewer_id_key" UNIQUE ("job_id", "reviewer_id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_jobs"
    ADD CONSTRAINT "saved_jobs_pkey" PRIMARY KEY ("user_id", "job_id");



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



CREATE INDEX "applications_builder_id_idx" ON "public"."applications" USING "btree" ("builder_id");



CREATE INDEX "applications_job_id_idx" ON "public"."applications" USING "btree" ("job_id");



CREATE INDEX "applications_trade_id_idx" ON "public"."applications" USING "btree" ("trade_id");



CREATE INDEX "conversations_builder_active_idx" ON "public"."conversations" USING "btree" ("builder_id", "last_message_at" DESC) WHERE ("builder_archived_at" IS NULL);



CREATE INDEX "conversations_builder_id_idx" ON "public"."conversations" USING "btree" ("builder_id");



CREATE INDEX "conversations_trade_active_idx" ON "public"."conversations" USING "btree" ("trade_id", "last_message_at" DESC) WHERE ("trade_archived_at" IS NULL);



CREATE INDEX "conversations_trade_id_idx" ON "public"."conversations" USING "btree" ("trade_id");



CREATE UNIQUE INDEX "conversations_uniq_no_job" ON "public"."conversations" USING "btree" ("builder_id", "trade_id") WHERE ("job_id" IS NULL);



CREATE UNIQUE INDEX "conversations_uniq_with_job" ON "public"."conversations" USING "btree" ("job_id", "builder_id", "trade_id") WHERE ("job_id" IS NOT NULL);



CREATE INDEX "hidden_jobs_user_id_idx" ON "public"."hidden_jobs" USING "btree" ("user_id");



CREATE INDEX "idx_builder_profiles_active" ON "public"."builder_profiles" USING "btree" ("id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_builder_profiles_service_latlng" ON "public"."builder_profiles" USING "btree" ("service_latitude", "service_longitude");



CREATE INDEX "idx_legal_acceptances_user" ON "public"."legal_acceptances" USING "btree" ("user_id", "document_type");



CREATE INDEX "idx_trade_profiles_active" ON "public"."trade_profiles" USING "btree" ("id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_trade_profiles_base_latlng" ON "public"."trade_profiles" USING "btree" ("base_latitude", "base_longitude");



CREATE INDEX "jobs_builder_id_idx" ON "public"."jobs" USING "btree" ("builder_id");



CREATE INDEX "jobs_search_vector_idx" ON "public"."jobs" USING "gin" ("search_vector");



CREATE INDEX "jobs_status_idx" ON "public"."jobs" USING "btree" ("status");



CREATE INDEX "jobs_trade_type_idx" ON "public"."jobs" USING "btree" ("trade_type_required");



CREATE INDEX "manual_verif_requests_open_idx" ON "public"."manual_verification_requests" USING "btree" ("created_at" DESC) WHERE ("status" = 'open'::"text");



CREATE INDEX "messages_conversation_id_idx" ON "public"."messages" USING "btree" ("conversation_id");



CREATE INDEX "messages_sender_id_idx" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "messages_thread_feed_idx" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC) WHERE ("deleted_at" IS NULL);



CREATE INDEX "notifications_read_at_idx" ON "public"."notifications" USING "btree" ("user_id", "read_at") WHERE ("read_at" IS NULL);



CREATE INDEX "notifications_user_id_idx" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "rate_limits_lookup_idx" ON "public"."verification_rate_limits" USING "btree" ("bucket_key", "endpoint", "window_start" DESC);



CREATE INDEX "reviews_reviewee_id_idx" ON "public"."reviews" USING "btree" ("reviewee_id");



CREATE INDEX "saved_jobs_user_id_created_at_idx" ON "public"."saved_jobs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "user_role_events_created_at_idx" ON "public"."user_role_events" USING "btree" ("created_at" DESC);



CREATE INDEX "user_role_events_user_id_idx" ON "public"."user_role_events" USING "btree" ("user_id");



CREATE INDEX "verification_documents_expiry_idx" ON "public"."verification_documents" USING "btree" ("expiry_date") WHERE (("status" = 'approved'::"public"."document_status") AND ("deleted_at" IS NULL) AND ("expiry_date" IS NOT NULL));



CREATE INDEX "verification_documents_trade_id_idx" ON "public"."verification_documents" USING "btree" ("trade_id");



CREATE INDEX "verification_events_vid_idx" ON "public"."verification_events" USING "btree" ("verification_id", "created_at" DESC);



CREATE INDEX "verification_funnel_step_idx" ON "public"."verification_funnel_events" USING "btree" ("step", "created_at" DESC);



CREATE INDEX "verifications_expiring_idx" ON "public"."verifications" USING "btree" ("expires_at") WHERE ("status" = 'verified'::"public"."verification_status");



CREATE INDEX "verifications_recheck_idx" ON "public"."verifications" USING "btree" ("last_checked_at") WHERE ("status" = 'verified'::"public"."verification_status");



CREATE INDEX "verifications_status_idx" ON "public"."verifications" USING "btree" ("status") WHERE ("status" = ANY (ARRAY['pending'::"public"."verification_status", 'manual_review'::"public"."verification_status"]));



CREATE INDEX "verifications_user_idx" ON "public"."verifications" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "applications_updated_at" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "builder_profiles_updated_at" BEFORE UPDATE ON "public"."builder_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "jobs_updated_at" BEFORE UPDATE ON "public"."jobs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "messages_update_last_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_conversation_last_message"();



CREATE OR REPLACE TRIGGER "profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trade_profiles_updated_at" BEFORE UPDATE ON "public"."trade_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_forbid_role_mutation" BEFORE UPDATE ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_role_mutation"();



CREATE OR REPLACE TRIGGER "trg_log_role_event" AFTER INSERT OR UPDATE OF "role" ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."log_role_event"();



CREATE OR REPLACE TRIGGER "user_roles_forbid_self_admin" BEFORE INSERT ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_self_admin"();



CREATE OR REPLACE TRIGGER "verification_documents_updated_at" BEFORE UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "verifications_updated_at" BEFORE UPDATE ON "public"."verifications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



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
    ADD CONSTRAINT "manual_verification_requests_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."manual_verification_requests"
    ADD CONSTRAINT "manual_verification_requests_verification_id_fkey" FOREIGN KEY ("verification_id") REFERENCES "public"."verifications"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."trade_profiles"
    ADD CONSTRAINT "trade_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_role_events"
    ADD CONSTRAINT "user_role_events_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_role_events"
    ADD CONSTRAINT "user_role_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verification_documents"
    ADD CONSTRAINT "verification_documents_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verification_events"
    ADD CONSTRAINT "verification_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."profiles"("id");



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



ALTER TABLE "public"."applications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "applications_insert_trade" ON "public"."applications" FOR INSERT WITH CHECK (("auth"."uid"() = "trade_id"));



CREATE POLICY "applications_select" ON "public"."applications" FOR SELECT USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



CREATE POLICY "applications_update" ON "public"."applications" FOR UPDATE USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



CREATE POLICY "buak_admin_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "buak_owner_insert" ON "public"."builder_unverified_acknowledgements" FOR INSERT WITH CHECK (("auth"."uid"() = "builder_id"));



CREATE POLICY "buak_owner_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT USING (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."builder_profiles" ENABLE ROW LEVEL SECURITY;


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



ALTER TABLE "public"."hidden_jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "hidden_jobs_delete_own" ON "public"."hidden_jobs" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "hidden_jobs_insert_own" ON "public"."hidden_jobs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "hidden_jobs_select_own" ON "public"."hidden_jobs" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "jobs_delete_own" ON "public"."jobs" FOR DELETE USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_insert_own" ON "public"."jobs" FOR INSERT WITH CHECK (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_select_open" ON "public"."jobs" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ("status" = ANY (ARRAY['open'::"public"."job_status", 'filled'::"public"."job_status"])) AND ("deleted_at" IS NULL)));



CREATE POLICY "jobs_select_own" ON "public"."jobs" FOR SELECT USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_update_own" ON "public"."jobs" FOR UPDATE USING (("auth"."uid"() = "builder_id")) WITH CHECK (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."legal_acceptances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."manual_verification_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_insert" ON "public"."messages" FOR INSERT WITH CHECK ((("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"())))))));



CREATE POLICY "messages_modify_own" ON "public"."messages" FOR UPDATE USING (("sender_id" = "auth"."uid"())) WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_select" ON "public"."messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "messages_update_read" ON "public"."messages" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "mvr_admin_read" ON "public"."manual_verification_requests" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'admin'::"text")))));



CREATE POLICY "mvr_no_client_insert" ON "public"."manual_verification_requests" FOR INSERT WITH CHECK (false);



CREATE POLICY "mvr_owner_read" ON "public"."manual_verification_requests" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



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



ALTER TABLE "public"."trade_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_categories_select_all" ON "public"."trade_categories" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."trade_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_profiles_insert_own" ON "public"."trade_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "trade_profiles_select_authenticated" ON "public"."trade_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."user_roles" "ur"
  WHERE (("ur"."user_id" = "trade_profiles"."id") AND ("ur"."role" = 'trade'::"text")))));



CREATE POLICY "trade_profiles_update_own" ON "public"."trade_profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."user_role_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_roles_insert_own" ON "public"."user_roles" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND ("role" = ANY (ARRAY['builder'::"text", 'trade'::"text"]))));



CREATE POLICY "user_roles_select_own" ON "public"."user_roles" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."verification_documents" ENABLE ROW LEVEL SECURITY;


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



REVOKE ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "supabase_auth_admin";



GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_role_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_role_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_role_event"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "service_role";



GRANT ALL ON TABLE "public"."applications" TO "anon";
GRANT ALL ON TABLE "public"."applications" TO "authenticated";
GRANT ALL ON TABLE "public"."applications" TO "service_role";



GRANT ALL ON TABLE "public"."builder_profiles" TO "anon";
GRANT ALL ON TABLE "public"."builder_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "anon";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



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



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."trade_profiles" TO "anon";
GRANT ALL ON TABLE "public"."trade_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."profile_completeness" TO "anon";
GRANT ALL ON TABLE "public"."profile_completeness" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_completeness" TO "service_role";



GRANT ALL ON TABLE "public"."profiles_public" TO "anon";
GRANT ALL ON TABLE "public"."profiles_public" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_public" TO "service_role";



GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "anon";
GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "authenticated";
GRANT ALL ON TABLE "public"."regulator_circuit_state" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."saved_jobs" TO "anon";
GRANT ALL ON TABLE "public"."saved_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."saved_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."trade_categories" TO "anon";
GRANT ALL ON TABLE "public"."trade_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_categories" TO "service_role";



GRANT ALL ON TABLE "public"."user_role_events" TO "anon";
GRANT ALL ON TABLE "public"."user_role_events" TO "authenticated";
GRANT ALL ON TABLE "public"."user_role_events" TO "service_role";



GRANT ALL ON TABLE "public"."verification_documents" TO "anon";
GRANT ALL ON TABLE "public"."verification_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."verification_documents" TO "service_role";



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







