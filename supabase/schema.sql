


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


CREATE OR REPLACE FUNCTION "public"."admin_actor_is_active"("p_actor_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT public.admin_company_actor_role(p_actor_id)='owner'
$$;


ALTER FUNCTION "public"."admin_actor_is_active"("p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
DECLARE
  v_title text := regexp_replace(p_title, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_body text := regexp_replace(p_body, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_user_id uuid;
  v_count integer;
BEGIN
  PERFORM public.admin_company_require('communications.send');
  IF v_title IS NULL OR char_length(v_title) NOT BETWEEN 1 AND 80
    OR v_body IS NULL OR char_length(v_body) NOT BETWEEN 1 AND 240
    OR p_audience IS NULL OR jsonb_typeof(coalesce(p_data, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  IF p_audience NOT IN ('all', 'builders', 'trades') THEN
    IF p_audience !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'invalid_audience' USING ERRCODE = '22023';
    END IF;
    v_user_id := p_audience::uuid;
    PERFORM 1 FROM public.profiles WHERE id = v_user_id FOR KEY SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001'; END IF;
  END IF;
  INSERT INTO public.notifications(user_id, type, title, body, data)
    SELECT p.id, 'announcement', v_title, v_body, coalesce(p_data, '{}'::jsonb)
    FROM public.profiles p LEFT JOIN public.user_roles r ON r.user_id = p.id
    WHERE p_audience = 'all' OR p.id = v_user_id
      OR (p_audience = 'builders' AND r.role = 'builder')
      OR (p_audience = 'trades' AND r.role = 'trade');
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN RAISE EXCEPTION 'no_recipients' USING ERRCODE = 'P0001'; END IF;
  PERFORM public.log_admin_action('broadcast', 'notifications', v_user_id,
    jsonb_build_object('audience', p_audience, 'count', v_count));
  RETURN v_count;
END;
$_$;


ALTER FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") IS 'Push program (Stream A): admin sends an announcement to All / builders / trades / a single user. Admin-only; inserts type=announcement notification rows (auto-pushed by notifications_push_fanout); audited via log_admin_action. Returns the recipient count.';



CREATE OR REPLACE FUNCTION "public"."admin_broadcast_to_user"("p_title" "text", "p_body" "text", "p_user_id" "uuid", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  PERFORM public.admin_company_require('communications.send');
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023'; END IF;
  RETURN public.admin_broadcast(p_title, p_body, p_user_id::text, p_data);
END;
$$;


ALTER FUNCTION "public"."admin_broadcast_to_user"("p_title" "text", "p_body" "text", "p_user_id" "uuid", "p_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_actor_role"("p_actor_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT s.staff_role FROM public.admin_staff s JOIN public.user_roles r ON r.user_id=s.user_id
 JOIN public.profiles p ON p.id=s.user_id
 WHERE s.user_id=p_actor_id AND s.active AND r.role='admin' AND p.user_status='active'
$$;


ALTER FUNCTION "public"."admin_company_actor_role"("p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_assert_owner"("p_actor_id" "uuid", "p_aal" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' OR public.admin_company_actor_role(p_actor_id) IS DISTINCT FROM 'owner'
 OR (EXISTS(SELECT 1 FROM public.admin_platform_settings WHERE key='admin_mfa_required' AND value='true'::jsonb)
     AND p_aal IS DISTINCT FROM 'aal2') THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501';
 END IF;
 RETURN true;
END $$;


ALTER FUNCTION "public"."admin_company_assert_owner"("p_actor_id" "uuid", "p_aal" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_guard_owner"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE v_user uuid; v_loses boolean; v_self uuid:=auth.uid();
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles',0));
 IF TG_TABLE_NAME='admin_staff' THEN
  v_user:=OLD.user_id;
  v_loses:=OLD.staff_role='owner' AND OLD.active AND
    (TG_OP='DELETE' OR NEW.staff_role<>'owner' OR NOT NEW.active OR NEW.user_id<>OLD.user_id);
  IF TG_OP='UPDATE' AND NEW.user_id<>OLD.user_id THEN RAISE EXCEPTION 'immutable_staff_identity'; END IF;
  IF v_user=v_self AND (TG_OP='DELETE' OR NEW.staff_role<>OLD.staff_role OR NOT NEW.active) THEN
   RAISE EXCEPTION 'self_staff_change';
  END IF;
 ELSIF TG_TABLE_NAME='profiles' THEN
  v_user:=OLD.id; v_loses:=TG_OP='DELETE' OR NEW.user_status<>'active';
 ELSE
  v_user:=OLD.user_id; v_loses:=TG_OP='DELETE' OR NEW.role<>'admin';
 END IF;
 IF v_loses AND EXISTS(SELECT 1 FROM public.admin_staff s JOIN public.profiles p ON p.id=s.user_id
   JOIN public.user_roles r ON r.user_id=s.user_id WHERE s.user_id=v_user AND s.active AND s.staff_role='owner'
   AND p.user_status='active' AND r.role='admin') THEN
  IF v_user=v_self THEN RAISE EXCEPTION 'self_owner_change'; END IF;
  IF (SELECT count(*) FROM public.admin_staff s JOIN public.profiles p ON p.id=s.user_id
   JOIN public.user_roles r ON r.user_id=s.user_id WHERE s.active AND s.staff_role='owner'
   AND p.user_status='active' AND r.role='admin')<=1 THEN RAISE EXCEPTION 'last_active_owner'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;


ALTER FUNCTION "public"."admin_company_guard_owner"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_has_permission"("p_permission" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT coalesce(
  (p_permission='session' OR NOT EXISTS(SELECT 1 FROM public.admin_platform_settings WHERE key='admin_mfa_required' AND value='true'::jsonb)
   OR auth.jwt()->>'aal'='aal2') AND
  CASE public.admin_company_actor_role(auth.uid())
   WHEN 'owner' THEN p_permission=ANY(ARRAY['session','users.read','users.manage','marketplace.read','marketplace.manage','verification.read','verification.manage','support.read','support.manage','analytics.read','communications.read','communications.send','audit.read','staff.read','staff.manage','platform.read','platform.manage'])
   WHEN 'operations' THEN p_permission=ANY(ARRAY['session','users.read','users.manage','marketplace.read','marketplace.manage','support.read','support.manage','analytics.read','communications.read','communications.send','audit.read'])
   WHEN 'verification' THEN p_permission=ANY(ARRAY['session','users.read','verification.read','verification.manage','audit.read'])
   WHEN 'support' THEN p_permission=ANY(ARRAY['session','users.read','marketplace.read','support.read','support.manage','audit.read'])
   WHEN 'read_only' THEN p_permission=ANY(ARRAY['session','users.read','marketplace.read','support.read','analytics.read','communications.read','audit.read'])
   ELSE false END,false)
$$;


ALTER FUNCTION "public"."admin_company_has_permission"("p_permission" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_list"("p_resource" "text", "p_page" integer DEFAULT 1, "p_user_id" "uuid" DEFAULT NULL::"uuid", "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
DECLARE v_permission text; v_source text; v_filter text:='true'; v_sql text; v_rows jsonb; v_total bigint; v_offset bigint;
BEGIN
 v_permission:=CASE p_resource
  WHEN 'applications' THEN 'marketplace.read' WHEN 'quotes' THEN 'marketplace.read'
  WHEN 'timesheets' THEN 'marketplace.read' WHEN 'reports' THEN 'support.read'
  WHEN 'reviews' THEN 'marketplace.read' WHEN 'enquiries' THEN 'support.read'
  WHEN 'support' THEN 'support.read' WHEN 'staff' THEN 'staff.read'
  WHEN 'settings' THEN 'platform.read' WHEN 'communications' THEN 'communications.read'
  WHEN 'health' THEN 'platform.read' WHEN 'reference' THEN 'platform.read'
  WHEN 'verifications' THEN 'verification.read' END;
 IF v_permission IS NULL THEN RAISE EXCEPTION 'invalid_resource' USING ERRCODE='22023'; END IF;
 PERFORM public.admin_company_require(v_permission);
 IF p_page IS NULL OR p_page<1 OR p_page>100000 OR length(coalesce(p_status,''))>50 THEN
  RAISE EXCEPTION 'invalid_page' USING ERRCODE='22023'; END IF;
 v_offset:=(p_page::bigint-1)*50;
 v_source:=CASE p_resource
  WHEN 'applications' THEN 'SELECT id,job_id,trade_id,builder_id,status::text AS status,created_at FROM public.applications'
  WHEN 'quotes' THEN 'SELECT id,job_id,builder_id,trade_id,status::text AS status,quote_amount,created_at FROM public.quote_requests'
  WHEN 'timesheets' THEN 'SELECT id,job_id,builder_id,trade_id,check_in_at,check_out_at,note,created_at FROM public.timesheets'
  WHEN 'reports' THEN 'SELECT id,reporter_id,reported_id,reason,details,status,version,created_at FROM public.reports'
  WHEN 'reviews' THEN 'SELECT id,reviewer_id,reviewee_id,rating,comment,created_at FROM public.reviews'
  WHEN 'enquiries' THEN 'SELECT id,name,email,phone,message,created_at FROM public.contact_enquiries'
  WHEN 'support' THEN $q$SELECT c.id,c.subject,c.user_id,c.priority,c.assignee_id,c.status,c.version,c.created_at,c.updated_at,
    (SELECT coalesce(jsonb_agg(jsonb_build_object('id',n.id,'body',n.body,'author_id',n.author_id,'created_at',n.created_at) ORDER BY n.created_at), '[]'::jsonb)
     FROM public.admin_support_notes n WHERE n.case_id=c.id) AS notes FROM public.admin_support_cases c$q$
  WHEN 'staff' THEN $q$SELECT s.id,s.user_id,p.display_name,u.email,s.staff_role,s.active,p.user_status,s.version,s.created_at,s.updated_at
    FROM public.admin_staff s JOIN public.profiles p ON p.id=s.user_id JOIN auth.users u ON u.id=s.user_id$q$
  WHEN 'settings' THEN 'SELECT id,key,value,version,updated_at,updated_at AS created_at FROM public.admin_platform_settings'
  WHEN 'communications' THEN $q$SELECT id,action,metadata->>'audience' AS audience,metadata->>'count' AS count,created_at FROM public.admin_actions WHERE action='broadcast'$q$
  WHEN 'health' THEN $q$SELECT '00000000-0000-0000-0000-000000000001'::uuid AS id,'available'::text AS status,'Database reachable'::text AS detail,now() AS created_at$q$
  WHEN 'reference' THEN $q$SELECT md5('trade_categories:'||slug)::uuid AS id,'trade_categories'::text AS source,display_name AS name,slug,display_name,sort_order,version,created_at FROM public.trade_categories
   UNION ALL SELECT md5('site_tickets:'||slug)::uuid,'site_tickets',display_name,slug,display_name,sort_order,version,created_at FROM public.site_tickets$q$
  WHEN 'verifications' THEN $q$SELECT d.id,d.trade_id,d.doc_type::text AS doc_type,d.status::text AS status,d.expiry_date,d.reviewed_by,
     a.assignee_id,coalesce(a.version,1) AS version,d.created_at FROM public.verification_documents d
     LEFT JOIN public.admin_verification_assignments a ON a.id=d.id WHERE d.deleted_at IS NULL$q$ END;
 IF p_user_id IS NOT NULL THEN
  IF p_resource NOT IN ('applications','quotes','timesheets','reports','reviews','support','staff','verifications') THEN
   RAISE EXCEPTION 'invalid_user_filter' USING ERRCODE='22023'; END IF;
  v_filter:=CASE p_resource
   WHEN 'applications' THEN format('(x.trade_id=%L::uuid OR x.builder_id=%L::uuid)',p_user_id,p_user_id)
   WHEN 'quotes' THEN format('(x.trade_id=%L::uuid OR x.builder_id=%L::uuid)',p_user_id,p_user_id)
   WHEN 'timesheets' THEN format('(x.trade_id=%L::uuid OR x.builder_id=%L::uuid)',p_user_id,p_user_id)
   WHEN 'reports' THEN format('(x.reporter_id=%L::uuid OR x.reported_id=%L::uuid)',p_user_id,p_user_id)
   WHEN 'reviews' THEN format('(x.reviewer_id=%L::uuid OR x.reviewee_id=%L::uuid)',p_user_id,p_user_id)
   WHEN 'support' THEN format('x.user_id=%L::uuid',p_user_id)
   WHEN 'staff' THEN format('x.user_id=%L::uuid',p_user_id)
   WHEN 'verifications' THEN format('x.trade_id=%L::uuid',p_user_id)
   ELSE 'false' END;
 END IF;
 IF p_status IS NOT NULL AND p_status<>'' THEN
  IF p_resource='support' AND p_status='active' THEN
   v_filter:=v_filter||' AND x.status IN (''open'',''in_progress'')';
  ELSIF p_resource='verifications' AND p_status='expiring' THEN
   v_filter:=v_filter||' AND x.status=''approved'' AND x.expiry_date>=current_date AND x.expiry_date<=current_date+30';
  ELSIF p_resource='verifications' AND p_status='expired' THEN
   v_filter:=v_filter||' AND (x.status=''expired'' OR (x.status=''approved'' AND x.expiry_date<current_date))';
  ELSIF p_resource IN ('applications','quotes','reports','support','verifications') THEN
   v_filter:=v_filter||format(' AND x.status::text=%L',p_status);
  ELSE RAISE EXCEPTION 'invalid_status_filter' USING ERRCODE='22023'; END IF;
 END IF;
 v_sql:=format('WITH x AS (%s) SELECT count(*) FROM x WHERE %s',v_source,v_filter);
 EXECUTE v_sql INTO v_total;
 v_sql:=format('WITH x AS (%s) SELECT coalesce(jsonb_agg(to_jsonb(y) ORDER BY y.created_at DESC,y.id DESC),''[]''::jsonb) FROM (SELECT * FROM x WHERE %s ORDER BY created_at DESC,id DESC LIMIT 50 OFFSET %s) y',v_source,v_filter,v_offset);
 EXECUTE v_sql INTO v_rows;
 RETURN jsonb_build_object('rows',v_rows,'total',v_total,'page',p_page,'pageSize',50);
END $_$;


ALTER FUNCTION "public"."admin_company_list"("p_resource" "text", "p_page" integer, "p_user_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_mutate"("p_resource" "text", "p_id" "uuid", "p_payload" "jsonb", "p_expected_version" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
DECLARE v_permission text; v_reason text; v_id uuid:=p_id; v_version integer; v_keys text[]; v_allowed text[];
 v_source text; v_slug text; v_assignee uuid; v_role text; v_value jsonb; v_old_value jsonb; v_key text;
BEGIN
 v_permission:=CASE p_resource WHEN 'support' THEN 'support.manage' WHEN 'note' THEN 'support.manage'
  WHEN 'report' THEN 'support.manage' WHEN 'staff' THEN 'staff.manage'
  WHEN 'setting' THEN 'platform.manage' WHEN 'verification-assignment' THEN 'verification.manage'
  WHEN 'reference' THEN 'platform.manage' END;
 IF v_permission IS NULL THEN RAISE EXCEPTION 'invalid_resource' USING ERRCODE='22023'; END IF;
 PERFORM public.admin_company_require(v_permission);
 IF jsonb_typeof(p_payload)<>'object' THEN RAISE EXCEPTION 'invalid_payload' USING ERRCODE='22023'; END IF;
 v_reason:=btrim(p_payload->>'reason');
 IF jsonb_typeof(p_payload->'reason') IS DISTINCT FROM 'string' OR length(v_reason) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'invalid_reason' USING ERRCODE='22023'; END IF;
 v_allowed:=CASE p_resource
  WHEN 'support' THEN ARRAY['subject','user_id','priority','assignee_id','status','reason']
  WHEN 'note' THEN ARRAY['case_id','body','reason']
  WHEN 'report' THEN ARRAY['status','reason']
  WHEN 'staff' THEN ARRAY['user_id','staff_role','active','reason']
  WHEN 'setting' THEN ARRAY['value','reason']
  WHEN 'verification-assignment' THEN ARRAY['assignee_id','reason']
  WHEN 'reference' THEN ARRAY['source','slug','display_name','sort_order','reason'] END;
 SELECT array_agg(key) INTO v_keys FROM jsonb_object_keys(p_payload) key;
 IF EXISTS(SELECT 1 FROM unnest(v_keys) k WHERE k<>ALL(v_allowed)) THEN
  RAISE EXCEPTION 'invalid_keys' USING ERRCODE='22023'; END IF;
 IF p_resource='support' THEN
  IF p_payload->>'priority' NOT IN ('low','normal','high','urgent')
   OR p_payload->>'status' NOT IN ('open','in_progress','resolved','closed')
   OR length(btrim(p_payload->>'subject')) NOT BETWEEN 3 AND 200 THEN RAISE EXCEPTION 'invalid_support' USING ERRCODE='22023'; END IF;
  v_assignee:=nullif(p_payload->>'assignee_id','')::uuid;
  IF v_assignee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.admin_staff s WHERE s.user_id=v_assignee AND s.active AND s.staff_role IN ('owner','operations','support')
   AND public.admin_company_actor_role(s.user_id) IS NOT NULL) THEN RAISE EXCEPTION 'invalid_assignee' USING ERRCODE='22023'; END IF;
  IF p_id IS NULL THEN
   IF p_expected_version IS NOT NULL THEN RAISE EXCEPTION 'invalid_version' USING ERRCODE='22023'; END IF;
   INSERT INTO public.admin_support_cases(subject,user_id,priority,assignee_id,status)
   VALUES(btrim(p_payload->>'subject'),nullif(p_payload->>'user_id','')::uuid,p_payload->>'priority',v_assignee,p_payload->>'status')
   RETURNING id,version INTO v_id,v_version;
  ELSE
   UPDATE public.admin_support_cases SET subject=btrim(p_payload->>'subject'),user_id=nullif(p_payload->>'user_id','')::uuid,
    priority=p_payload->>'priority',assignee_id=v_assignee,status=p_payload->>'status',version=version+1,updated_at=now()
   WHERE id=p_id AND version=p_expected_version RETURNING version INTO v_version;
  END IF;
 ELSIF p_resource='note' THEN
  IF p_id IS NOT NULL OR p_expected_version IS NOT NULL OR length(btrim(p_payload->>'body')) NOT BETWEEN 1 AND 5000
   OR p_payload->>'case_id' IS NULL THEN RAISE EXCEPTION 'invalid_note' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.admin_support_cases WHERE id=(p_payload->>'case_id')::uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'case_not_found'; END IF;
  INSERT INTO public.admin_support_notes(case_id,author_id,body)
  VALUES((p_payload->>'case_id')::uuid,auth.uid(),btrim(p_payload->>'body')) RETURNING id INTO v_id;
  v_version:=1;
 ELSIF p_resource='report' THEN
  IF p_id IS NULL OR p_payload->>'status' NOT IN ('pending','reviewed','actioned','dismissed') THEN RAISE EXCEPTION 'invalid_report' USING ERRCODE='22023'; END IF;
  UPDATE public.reports SET status=p_payload->>'status',version=version+1 WHERE id=p_id AND version=p_expected_version RETURNING version INTO v_version;
 ELSIF p_resource='staff' THEN
  v_role:=p_payload->>'staff_role';
  IF v_role NOT IN ('owner','operations','verification','support','read_only') OR jsonb_typeof(p_payload->'active')<>'boolean'
   OR p_payload->>'user_id' IS NULL THEN RAISE EXCEPTION 'invalid_staff' USING ERRCODE='22023'; END IF;
  IF v_role='owner' AND public.admin_company_actor_role(auth.uid())<>'owner' THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF p_id IS NULL THEN
   IF p_expected_version IS NOT NULL THEN RAISE EXCEPTION 'invalid_version' USING ERRCODE='22023'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.user_roles r JOIN public.profiles p ON p.id=r.user_id
    WHERE r.user_id=(p_payload->>'user_id')::uuid AND r.role='admin' AND p.user_status='active') THEN RAISE EXCEPTION 'invalid_staff_user'; END IF;
   INSERT INTO public.admin_staff(user_id,staff_role,active)
   VALUES((p_payload->>'user_id')::uuid,v_role,(p_payload->>'active')::boolean) RETURNING id,version INTO v_id,v_version;
  ELSE
   IF public.admin_company_actor_role(auth.uid())<>'owner' AND EXISTS
    (SELECT 1 FROM public.admin_staff WHERE id=p_id AND staff_role='owner') THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
   UPDATE public.admin_staff SET staff_role=v_role,active=(p_payload->>'active')::boolean,version=version+1,updated_at=now()
    WHERE id=p_id AND user_id=(p_payload->>'user_id')::uuid AND version=p_expected_version RETURNING version INTO v_version;
  END IF;
 ELSIF p_resource='setting' THEN
  IF p_id IS NULL THEN RAISE EXCEPTION 'invalid_setting' USING ERRCODE='22023'; END IF;
  SELECT key,value INTO v_key,v_old_value FROM public.admin_platform_settings WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'setting_not_found'; END IF;
  v_value:=p_payload->'value';
  IF v_key IN ('marketplace_enabled','registration_enabled','admin_mfa_required') THEN
   IF jsonb_typeof(v_value)<>'boolean' THEN RAISE EXCEPTION 'invalid_setting_value' USING ERRCODE='22023'; END IF;
  ELSIF v_key='maintenance_notice' THEN
   IF jsonb_typeof(v_value)<>'string' OR length(v_value#>>'{}')>500 THEN RAISE EXCEPTION 'invalid_setting_value' USING ERRCODE='22023'; END IF;
  ELSE
   IF jsonb_typeof(v_value)<>'string' OR (v_value#>>'{}') !~ '^[0-9]+\.[0-9]+\.[0-9]+$' THEN
    RAISE EXCEPTION 'invalid_setting_value' USING ERRCODE='22023'; END IF;
  END IF;
  IF v_key='admin_mfa_required' AND v_value='true'::jsonb AND auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' THEN
   RAISE EXCEPTION 'mfa_required' USING ERRCODE='42501'; END IF;
  UPDATE public.admin_platform_settings SET value=v_value,version=version+1,updated_at=now()
   WHERE id=p_id AND version=p_expected_version RETURNING version INTO v_version;
 ELSIF p_resource='verification-assignment' THEN
  IF p_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.verification_documents WHERE id=p_id AND deleted_at IS NULL) THEN
   RAISE EXCEPTION 'invalid_document' USING ERRCODE='22023'; END IF;
  v_assignee:=nullif(p_payload->>'assignee_id','')::uuid;
  IF v_assignee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.admin_staff s WHERE s.user_id=v_assignee AND s.active
   AND s.staff_role IN ('owner','verification') AND public.admin_company_actor_role(s.user_id) IS NOT NULL) THEN
   RAISE EXCEPTION 'invalid_assignee' USING ERRCODE='22023'; END IF;
  IF p_expected_version=1 AND NOT EXISTS(SELECT 1 FROM public.admin_verification_assignments WHERE id=p_id) THEN
   INSERT INTO public.admin_verification_assignments(id,assignee_id,version) VALUES(p_id,v_assignee,2) RETURNING version INTO v_version;
  ELSE
   UPDATE public.admin_verification_assignments SET assignee_id=v_assignee,version=version+1,updated_at=now()
    WHERE id=p_id AND version=p_expected_version RETURNING version INTO v_version;
  END IF;
 ELSIF p_resource='reference' THEN
  v_source:=p_payload->>'source'; v_slug:=p_payload->>'slug';
  IF p_id IS NOT NULL OR v_source NOT IN ('trade_categories','site_tickets') OR v_slug !~ '^[a-z0-9_]{1,100}$'
   OR length(btrim(p_payload->>'display_name')) NOT BETWEEN 2 AND 100
   OR (p_payload->>'sort_order')::integer NOT BETWEEN 0 AND 10000 THEN RAISE EXCEPTION 'invalid_reference' USING ERRCODE='22023'; END IF;
  EXECUTE format('UPDATE public.%I SET display_name=$1,sort_order=$2,version=version+1 WHERE slug=$3 AND version=$4 RETURNING version',v_source)
   INTO v_version USING btrim(p_payload->>'display_name'),(p_payload->>'sort_order')::integer,v_slug,p_expected_version;
 ELSE RAISE EXCEPTION 'invalid_resource' USING ERRCODE='22023'; END IF;
 IF v_version IS NULL THEN RAISE EXCEPTION 'stale_version' USING ERRCODE='40001'; END IF;
 INSERT INTO public.admin_actions(actor_id,action,target_table,target_id,metadata)
 VALUES(auth.uid(),'company_'||p_resource,p_resource,v_id,
  jsonb_build_object('reason',v_reason,'version',v_version,'source',v_source,'slug',v_slug)
  || CASE WHEN p_resource='setting' THEN jsonb_build_object('key',v_key,'old_value',v_old_value,'new_value',v_value) ELSE '{}'::jsonb END);
 RETURN jsonb_build_object('id',v_id,'version',v_version);
END $_$;


ALTER FUNCTION "public"."admin_company_mutate"("p_resource" "text", "p_id" "uuid", "p_payload" "jsonb", "p_expected_version" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_overview"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE v_counts jsonb; v_trends jsonb:='[]'::jsonb; v_can_users boolean; v_can_market boolean; v_can_support boolean; v_can_verify boolean;
BEGIN
 PERFORM public.admin_company_require('session');
 v_can_users:=public.admin_company_has_permission('users.read');
 v_can_market:=public.admin_company_has_permission('marketplace.read');
 v_can_support:=public.admin_company_has_permission('support.read');
 v_can_verify:=public.admin_company_has_permission('verification.read');
 SELECT jsonb_build_object(
  'profiles',CASE WHEN v_can_users THEN (SELECT count(*) FROM public.profiles) END,
  'jobs',CASE WHEN v_can_market THEN (SELECT count(*) FROM public.jobs) END,
  'openJobs',CASE WHEN v_can_market THEN (SELECT count(*) FROM public.jobs WHERE status='open') END,
  'pendingReports',CASE WHEN v_can_support THEN (SELECT count(*) FROM public.reports WHERE status='pending') END,
  'pendingVerifications',CASE WHEN v_can_verify THEN (SELECT count(*) FROM public.verification_documents WHERE status='pending' AND deleted_at IS NULL) END,
  'openSupport',CASE WHEN v_can_support THEN (SELECT count(*) FROM public.admin_support_cases WHERE status IN ('open','in_progress')) END) INTO v_counts;
 IF public.admin_company_has_permission('analytics.read') AND v_can_users AND v_can_market THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('date',d::date,'profiles',(SELECT count(*) FROM public.profiles WHERE created_at::date=d::date),
   'jobs',(SELECT count(*) FROM public.jobs WHERE created_at::date=d::date)) ORDER BY d),'[]'::jsonb)
  INTO v_trends FROM generate_series(current_date-13,current_date,'1 day'::interval) d;
 END IF;
 RETURN jsonb_build_object('counts',v_counts,'trends',v_trends,'sources',jsonb_build_object('profiles','profiles','jobs','jobs','reports','reports','verifications','verification_documents','support','admin_support_cases'),'asOf',now());
END $$;


ALTER FUNCTION "public"."admin_company_overview"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_public_config"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb) FROM public.admin_platform_settings
 WHERE key IN ('maintenance_notice','minimum_android_version','minimum_ios_version','marketplace_enabled','registration_enabled')
$$;


ALTER FUNCTION "public"."admin_company_public_config"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_require"("p_permission" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
 -- Serialize revocations with privileged writes. Current membership is re-read.
 PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles',0));
 IF NOT public.admin_company_has_permission(p_permission) THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501';
 END IF;
END $$;


ALTER FUNCTION "public"."admin_company_require"("p_permission" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_search_users"("p_q" "text", "p_search_by" "text", "p_role" "text" DEFAULT 'all'::"text", "p_status" "text" DEFAULT 'all'::"text", "p_page" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE v_rows jsonb; v_total bigint; v_q text:=btrim(p_q); v_phone text; v_phone_query text;
BEGIN
 PERFORM public.admin_company_require('users.read');
 IF p_q IS NULL OR p_search_by IS NULL OR p_role IS NULL OR p_status IS NULL OR p_page IS NULL
 OR p_search_by NOT IN ('email','company','full_name','phone','name','id') OR p_role NOT IN ('all','builder','trade','admin')
 OR p_status NOT IN ('all','active','suspended','banned') OR p_page NOT BETWEEN 1 AND 100000
 OR length(v_q) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'invalid_search' USING ERRCODE='22023'; END IF;
 v_phone:=regexp_replace(v_q,'[^0-9]','','g');
 v_phone_query:=CASE WHEN v_phone LIKE '0%' THEN '61'||substring(v_phone FROM 2) ELSE v_phone END;
 WITH matches AS (
  SELECT p.id,p.display_name,p.user_status,p.avatar_url,p.created_at,r.role,
   coalesce(t.is_verified,false) AS is_verified
  FROM public.profiles p LEFT JOIN public.user_roles r ON r.user_id=p.id
  LEFT JOIN public.trade_profiles t ON t.id=p.id
  LEFT JOIN public.builder_profiles b ON b.id=p.id
  LEFT JOIN auth.users u ON u.id=p.id
  WHERE (p_role='all' OR r.role::text=p_role) AND (p_status='all' OR p.user_status::text=p_status)
   AND CASE p_search_by
    WHEN 'email' THEN u.email ILIKE '%' || replace(replace(replace(v_q,'\','\\'),'%','\%'),'_','\_') || '%'
    WHEN 'company' THEN b.company_name ILIKE '%' || replace(replace(replace(v_q,'\','\\'),'%','\%'),'_','\_') || '%'
    WHEN 'full_name' THEN t.full_name ILIKE '%' || replace(replace(replace(v_q,'\','\\'),'%','\%'),'_','\_') || '%'
    WHEN 'phone' THEN length(v_phone)>=3 AND (regexp_replace(coalesce(p.phone,''),'[^0-9]','','g') LIKE '%'||v_phone||'%'
       OR regexp_replace(coalesce(p.phone,''),'[^0-9]','','g') LIKE '%'||v_phone_query||'%')
    WHEN 'id' THEN p.id::text=v_q
    ELSE p.display_name ILIKE '%' || replace(replace(replace(v_q,'\','\\'),'%','\%'),'_','\_') || '%' END
 ), page AS (SELECT * FROM matches ORDER BY created_at DESC,id DESC LIMIT 50 OFFSET (p_page::bigint-1)*50)
 SELECT (SELECT count(*) FROM matches),
  (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'displayName',coalesce(nullif(btrim(display_name),''),left(id::text,8)||'…'),
   'role',coalesce(role::text,'unknown'),'userStatus',user_status::text,'isVerified',is_verified,
   'createdAt',created_at,'avatarUrl',avatar_url) ORDER BY created_at DESC,id DESC),'[]'::jsonb) FROM page)
 INTO v_total,v_rows;
 RETURN jsonb_build_object('rows',v_rows,'total',v_total,'page',p_page,'pageSize',50);
END $$;


ALTER FUNCTION "public"."admin_company_search_users"("p_q" "text", "p_search_by" "text", "p_role" "text", "p_status" "text", "p_page" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_company_session"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE v_role text:=public.admin_company_actor_role(auth.uid()); v_mfa boolean;
BEGIN
 IF v_role IS NULL THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
 SELECT value='true'::jsonb INTO v_mfa FROM public.admin_platform_settings WHERE key='admin_mfa_required';
 RETURN jsonb_build_object('staffRole',v_role,'mfaRequired',coalesce(v_mfa,false));
END $$;


ALTER FUNCTION "public"."admin_company_session"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_require_active"("p_actor_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles',0));
 IF public.admin_company_actor_role(p_actor_id) IS DISTINCT FROM 'owner' THEN
  RAISE EXCEPTION 'not_admin' USING ERRCODE='42501';
 END IF;
 IF auth.role() IS DISTINCT FROM 'service_role' THEN
  IF p_actor_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not_admin' USING ERRCODE='42501'; END IF;
  PERFORM public.admin_company_require('staff.manage');
 END IF;
END $$;


ALTER FUNCTION "public"."admin_require_active"("p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- Preserve legacy clients while marking the absent reviewer reason honestly.
  PERFORM public.admin_set_job_status(p_job_id, p_status, 'Legacy client: reason not supplied');
END;
$$;


ALTER FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") IS '#21a admin moderation: set a job status (e.g. closed). Admin-only; audited.';



CREATE OR REPLACE FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
DECLARE
  v_old_status public.job_status;
  v_reason text := regexp_replace(p_reason, '^[[:space:]]+|[[:space:]]+$', '', 'g');
BEGIN
  PERFORM public.admin_company_require('marketplace.manage');
  IF p_job_id IS NULL OR p_status IS NULL
    OR NOT (p_status = ANY(enum_range(NULL::public.job_status)::text[]))
    OR v_reason IS NULL OR char_length(v_reason) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  SELECT status INTO v_old_status FROM public.jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'job_not_found' USING ERRCODE = 'P0001'; END IF;
  UPDATE public.jobs SET status = p_status::public.job_status WHERE id = p_job_id;
  PERFORM public.log_admin_action('set_job_status', 'jobs', p_job_id,
    jsonb_build_object('status', p_status, 'old_status', v_old_status, 'reason', v_reason));
END;
$_$;


ALTER FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_user_role"("p_actor_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_expected_role" "text", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_old_role text;
  v_name text;
  v_previous_actor text;
  v_previous_reason text;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_actor_id IS NULL OR p_user_id IS NULL OR p_role IS NULL
    OR p_role NOT IN ('builder','trade','admin')
    OR (p_expected_role IS NOT NULL AND p_expected_role NOT IN ('builder','trade','admin'))
    OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 500
    OR p_reason ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  -- Serialize promotions/demotions, including opposing concurrent requests.
  PERFORM public.admin_require_active(p_actor_id);
  IF p_actor_id = p_user_id THEN RAISE EXCEPTION 'self_role_change' USING ERRCODE = 'P0001'; END IF;
  PERFORM 1 FROM auth.users WHERE id = p_user_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001'; END IF;

  SELECT role INTO v_old_role FROM public.user_roles WHERE user_id = p_user_id FOR UPDATE;
  -- NULL means the UI observed no role, not permission to overwrite any role.
  IF v_old_role IS DISTINCT FROM p_expected_role THEN
    RAISE EXCEPTION 'role_conflict' USING ERRCODE = 'P0001';
  END IF;
  IF v_old_role = 'admin' AND p_role <> 'admin'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND user_status = 'active')
    AND (SELECT count(*) FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
         WHERE r.role = 'admin' AND p.user_status = 'active') <= 1 THEN
    RAISE EXCEPTION 'last_active_admin' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.profiles(id, display_name)
    SELECT id, nullif(btrim(raw_user_meta_data->>'full_name'), '') FROM auth.users WHERE id = p_user_id
    ON CONFLICT (id) DO NOTHING;
  SELECT display_name INTO v_name FROM public.profiles WHERE id = p_user_id;
  IF p_role = 'builder' THEN
    INSERT INTO public.builder_profiles(id) VALUES(p_user_id) ON CONFLICT (id) DO NOTHING;
  ELSIF p_role = 'trade' THEN
    INSERT INTO public.trade_profiles(id, full_name) VALUES(p_user_id, v_name) ON CONFLICT (id) DO NOTHING;
  END IF;
  -- Preserve both historical role profiles; never clear apprentice, business,
  -- verification, job, quote or application data when changing the auth role.
  v_previous_actor := current_setting('jobdun.admin_actor_id', true);
  v_previous_reason := current_setting('jobdun.admin_role_reason', true);
  PERFORM set_config('jobdun.admin_actor_id', p_actor_id::text, true);
  PERFORM set_config('jobdun.admin_role_reason', btrim(p_reason), true);
  INSERT INTO public.user_roles(user_id, role) VALUES(p_user_id, p_role)
    ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;
  PERFORM set_config('jobdun.admin_actor_id', coalesce(v_previous_actor, ''), true);
  PERFORM set_config('jobdun.admin_role_reason', coalesce(v_previous_reason, ''), true);

  INSERT INTO public.admin_actions(actor_id, action, target_table, target_id, metadata)
    VALUES(p_actor_id, 'set_user_role', 'user_roles', p_user_id,
      jsonb_build_object('old_role', v_old_role, 'new_role', p_role, 'reason', btrim(p_reason)));
  RETURN jsonb_build_object('userId', p_user_id, 'role', p_role);
END;
$$;


ALTER FUNCTION "public"."admin_set_user_role"("p_actor_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_expected_role" "text", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE v_old public.user_status; v_reason text:=btrim(p_reason);
BEGIN
 PERFORM public.admin_company_require('users.manage');
 IF p_user_id IS NULL OR p_status IS NULL OR p_status NOT IN ('active','suspended','banned')
 OR v_reason IS NULL OR length(v_reason) NOT BETWEEN 5 AND 500 THEN
  RAISE EXCEPTION 'invalid_request' USING ERRCODE='22023'; END IF;
 IF p_user_id=auth.uid() AND p_status<>'active' THEN RAISE EXCEPTION 'self_status_change'; END IF;
 IF NOT public.admin_company_has_permission('staff.manage') AND (EXISTS
  (SELECT 1 FROM public.admin_staff WHERE user_id=p_user_id) OR EXISTS
  (SELECT 1 FROM public.user_roles WHERE user_id=p_user_id AND role='admin')) THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
 SELECT user_status INTO v_old FROM public.profiles WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found'; END IF;
 UPDATE public.profiles SET user_status=p_status::public.user_status,status_reason=v_reason WHERE id=p_user_id;
 INSERT INTO public.admin_actions(actor_id,action,target_table,target_id,metadata)
 VALUES(auth.uid(),'set_user_status','profiles',p_user_id,jsonb_build_object('status',p_status,'old_status',v_old,'reason',v_reason));
END $$;


ALTER FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") IS '#21a admin moderation: set a user active/suspended/banned. Admin-only; audited via log_admin_action. Enforcement (blocking suspended users) is a follow-up RLS concern.';



CREATE OR REPLACE FUNCTION "public"."admin_user_invitation_preflight"("p_actor_id" "uuid", "p_email" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  PERFORM public.admin_user_management_ready(p_actor_id);
  IF p_email IS NULL OR length(p_email) NOT BETWEEN 3 AND 254 THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(btrim(p_email))) THEN
    RAISE EXCEPTION 'user_exists' USING ERRCODE = 'P0001';
  END IF;
END;
$$;


ALTER FUNCTION "public"."admin_user_invitation_preflight"("p_actor_id" "uuid", "p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_user_management_is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT public.admin_company_has_permission('users.read')
$$;


ALTER FUNCTION "public"."admin_user_management_is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_user_management_rate_limit"("p_actor_id" "uuid", "p_ip" "text", "p_action" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_endpoint text;
  v_actor_limit integer;
  v_ip_limit integer;
  v_minute timestamptz := date_trunc('minute', clock_timestamp());
  v_actor_bucket text := 'user:' || p_actor_id::text;
  v_ip_bucket text := 'ip:' || coalesce(nullif(btrim(p_ip), ''), 'unknown');
BEGIN
  PERFORM public.admin_user_management_ready(p_actor_id);
  IF p_action IS NULL OR p_action NOT IN ('invite','set-role') OR length(p_ip) > 200 THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  v_endpoint := 'admin-users-' || p_action;
  v_actor_limit := CASE WHEN p_action = 'invite' THEN 5 ELSE 30 END;
  v_ip_limit := CASE WHEN p_action = 'invite' THEN 20 ELSE 90 END;
  PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:rate-limit', 0));
  IF (SELECT coalesce(sum(attempt_count),0) FROM public.verification_rate_limits
      WHERE endpoint = v_endpoint AND bucket_key = v_actor_bucket AND window_start >= v_minute - interval '1 hour') >= v_actor_limit
    OR (SELECT coalesce(sum(attempt_count),0) FROM public.verification_rate_limits
      WHERE endpoint = v_endpoint AND bucket_key = v_ip_bucket AND window_start >= v_minute - interval '1 hour') >= v_ip_limit THEN
    RETURN jsonb_build_object('allowed', false, 'retry_after', 3660);
  END IF;
  INSERT INTO public.verification_rate_limits(bucket_key, endpoint, window_start, attempt_count)
    VALUES(v_actor_bucket, v_endpoint, v_minute, 1), (v_ip_bucket, v_endpoint, v_minute, 1)
    ON CONFLICT (bucket_key, endpoint, window_start) DO UPDATE
    SET attempt_count = public.verification_rate_limits.attempt_count + 1;
  RETURN jsonb_build_object('allowed', true, 'retry_after', 3660);
END;
$$;


ALTER FUNCTION "public"."admin_user_management_rate_limit"("p_actor_id" "uuid", "p_ip" "text", "p_action" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_user_management_ready"("p_actor_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' OR p_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_active(p_actor_id);
  RETURN true;
END;
$$;


ALTER FUNCTION "public"."admin_user_management_ready"("p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_raw jsonb;
BEGIN
  PERFORM public.admin_company_require('verification.read');

  PERFORM 1 FROM public.verifications WHERE id = p_verification_id FOR KEY SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'verification_not_found' USING ERRCODE = 'P0001';
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
    SET "search_path" TO 'public'
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
    SET "search_path" TO 'public'
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



CREATE OR REPLACE FUNCTION "public"."forbid_identity_col_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  -- Requests signed with the service-role key (admin Edge Functions / server jobs) bypass.
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'messages' THEN
    IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
       OR NEW.sender_id     IS DISTINCT FROM OLD.sender_id THEN
      RAISE EXCEPTION 'messages.conversation_id and sender_id are immutable'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    -- conversations, applications, bookings, quote_requests, timesheets
    -- (all carry builder_id / trade_id / job_id).
    IF NEW.builder_id IS DISTINCT FROM OLD.builder_id
       OR NEW.trade_id IS DISTINCT FROM OLD.trade_id
       OR NEW.job_id   IS DISTINCT FROM OLD.job_id THEN
      RAISE EXCEPTION '%.builder_id / trade_id / job_id are immutable from the client', TG_TABLE_NAME
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."forbid_identity_col_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."forbid_role_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'user_roles.role is immutable from client; role changes must go through an admin Edge Function (service_role)'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."forbid_role_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."forbid_self_admin"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.role = 'admin' AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned' USING ERRCODE = '42501';
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



CREATE OR REPLACE FUNCTION "public"."get_inbox"("p_user" "uuid") RETURNS TABLE("id" "uuid", "job_id" "uuid", "builder_id" "uuid", "trade_id" "uuid", "last_message_at" timestamp with time zone, "last_message_preview" "text", "last_message_sender_id" "uuid", "status" "text", "created_at" timestamp with time zone, "my_unread_count" integer, "other_display_name" "text", "other_avatar_url" "text", "job_title" "text", "is_pinned" boolean, "is_muted" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                        AS my_unread_count,
         CASE
           WHEN c.builder_id <> p_user
             THEN COALESCE(NULLIF(btrim(bp.company_name), ''), other.display_name)
           ELSE other.display_name
         END                                                       AS other_display_name,
         other.avatar_url                                          AS other_avatar_url,
         j.title                                                   AS job_title,
         CASE WHEN c.builder_id = p_user THEN c.builder_pinned_at IS NOT NULL
              ELSE c.trade_pinned_at IS NOT NULL END               AS is_pinned,
         CASE WHEN c.builder_id = p_user THEN c.builder_muted_at IS NOT NULL
              ELSE c.trade_muted_at IS NOT NULL END                AS is_muted
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
    LEFT JOIN public.builder_profiles bp ON bp.id = c.builder_id
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY
     -- Pinned conversations float to the top per viewer
     CASE WHEN c.builder_id = p_user THEN (c.builder_pinned_at IS NOT NULL)::int
          ELSE (c.trade_pinned_at IS NOT NULL)::int
     END DESC,
     c.last_message_at DESC NULLS LAST;
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

  -- Refuse to open/re-open a thread between blocked users.
  IF EXISTS (
    SELECT 1 FROM public.blocks
     WHERE (blocker_id = p_builder AND blocked_id = p_trade)
        OR (blocker_id = p_trade   AND blocked_id = p_builder)
  ) THEN
    RAISE EXCEPTION 'user_blocked';
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
 SELECT vd.trade_id,vd.doc_type::text,vd.expiry_date,
  CASE WHEN vd.expiry_date IS NULL OR vd.expiry_date>=current_date THEN 'current' ELSE 'expired' END,
  vd.reviewed_at FROM public.verification_documents vd
 JOIN public.trade_profiles tp ON tp.id=vd.trade_id
 WHERE vd.trade_id=p_user_id AND vd.status='approved' AND vd.deleted_at IS NULL
  AND vd.doc_type IN ('white_card','public_liability') AND tp.deleted_at IS NULL;
$$;


ALTER FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") IS 'Minimized counterparty projection of a tradie''s APPROVED supplementary credentials (white_card, public_liability). SECURITY DEFINER on purpose: exposes ONLY the credential type, lapsed-or-not, and the as-at approval date — never the document url, number, insurer, state, or review notes.';



CREATE OR REPLACE FUNCTION "public"."guard_application_lifecycle"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  actor uuid := auth.uid();
  vacancy public.jobs%ROWTYPE;
BEGIN
  -- Administrative maintenance retains its existing privileged path.
  IF auth.role() = 'service_role' THEN RETURN NEW; END IF;
  IF actor IS NULL THEN
    RAISE EXCEPTION 'Sign in to manage applications' USING ERRCODE='42501';
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT * INTO vacancy FROM public.jobs WHERE id=NEW.job_id FOR UPDATE;
    IF actor IS DISTINCT FROM NEW.trade_id OR NEW.status <> 'pending'
       OR NEW.builder_id IS DISTINCT FROM vacancy.builder_id
       OR actor = vacancy.builder_id
       OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=actor AND role='trade') THEN
      RAISE EXCEPTION 'Invalid application owner or initial status' USING ERRCODE='42501';
    END IF;
    IF vacancy.id IS NULL OR vacancy.status <> 'open' OR vacancy.deleted_at IS NOT NULL THEN
      RAISE EXCEPTION 'This job is no longer accepting applications' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  IF actor = OLD.builder_id THEN
    -- Lock before every builder decision, not only hire, so cancellation and
    -- filling a vacancy cannot race shortlist/reject requests from stale UI.
    SELECT * INTO vacancy FROM public.jobs WHERE id=OLD.job_id FOR UPDATE;
    IF vacancy.id IS NULL OR vacancy.builder_id IS DISTINCT FROM actor
       OR vacancy.status <> 'open' OR vacancy.deleted_at IS NOT NULL THEN
      RAISE EXCEPTION 'This job is no longer accepting application decisions' USING ERRCODE='23514';
    END IF;
    IF OLD.status NOT IN ('pending','shortlisted') OR NEW.status NOT IN ('shortlisted','rejected','hired') THEN
      RAISE EXCEPTION 'This application can no longer be changed' USING ERRCODE='23514';
    END IF;
  ELSIF actor = OLD.trade_id THEN
    IF NOT ((OLD.status IN ('pending','shortlisted') AND NEW.status='withdrawn')
       OR (OLD.status='hired' AND NEW.status='declined_by_trade')) THEN
      RAISE EXCEPTION 'Applicants may only withdraw or decline their application' USING ERRCODE='42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'Not a participant in this application' USING ERRCODE='42501';
  END IF;
  IF NEW.status='hired' THEN
    -- The job row lock serialises two concurrent hires for the same vacancy.
    SELECT * INTO vacancy FROM public.jobs WHERE id=NEW.job_id FOR UPDATE;
    IF vacancy.status <> 'open' OR vacancy.deleted_at IS NOT NULL
       OR vacancy.hired_trade_id IS NOT NULL
       OR EXISTS (SELECT 1 FROM public.applications
                  WHERE job_id=NEW.job_id AND status='hired' AND id<>NEW.id) THEN
      RAISE EXCEPTION 'This job is no longer available to hire' USING ERRCODE='23514';
    END IF;
    UPDATE public.jobs SET status='filled', hired_trade_id=NEW.trade_id WHERE id=NEW.job_id;
  ELSIF NEW.status='declined_by_trade' THEN
    UPDATE public.jobs SET status='open', hired_trade_id=NULL
      WHERE id=NEW.job_id AND hired_trade_id=NEW.trade_id AND status='filled' AND deleted_at IS NULL;
  END IF;
  NEW.status_changed_at := now();
  RETURN NEW;
END $$;


ALTER FUNCTION "public"."guard_application_lifecycle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_conversation_creation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE actor uuid := auth.uid();
BEGIN
  IF auth.role() = 'service_role' THEN RETURN NEW; END IF;
  IF actor IS NULL OR (actor IS DISTINCT FROM NEW.builder_id AND actor IS DISTINCT FROM NEW.trade_id) THEN
    RAISE EXCEPTION 'Not a participant in this conversation' USING ERRCODE='42501';
  END IF;
  IF NEW.builder_id = NEW.trade_id
     OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=NEW.builder_id AND role='builder')
     OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=NEW.trade_id AND role='trade') THEN
    RAISE EXCEPTION 'Conversations require a builder and a trade' USING ERRCODE='42501';
  END IF;
  IF NEW.job_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.jobs WHERE id=NEW.job_id AND builder_id=NEW.builder_id
  ) THEN
    RAISE EXCEPTION 'Conversation job must belong to its builder' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."guard_conversation_creation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_timesheet_lifecycle"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  actor uuid := auth.uid();
  vacancy public.jobs%ROWTYPE;
BEGIN
  IF auth.role() = 'service_role' THEN RETURN NEW; END IF;
  IF actor IS NULL OR actor IS DISTINCT FROM NEW.trade_id THEN
    RAISE EXCEPTION 'Only the trade may manage their timesheet' USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Hold the vacancy stable through this transaction. Concurrent closure,
    -- deletion or hired-trade reassignment must serialize with clock-in.
    SELECT * INTO vacancy FROM public.jobs WHERE id = NEW.job_id FOR SHARE;
    IF vacancy.id IS NULL THEN
      RAISE EXCEPTION 'This job is not available for check-in' USING ERRCODE = '23514';
    END IF;
    IF NEW.builder_id IS DISTINCT FROM vacancy.builder_id
       OR actor = vacancy.builder_id
       OR NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = actor AND role = 'trade') THEN
      RAISE EXCEPTION 'Invalid timesheet owner or builder' USING ERRCODE = '42501';
    END IF;
    IF vacancy.status <> 'filled' OR vacancy.deleted_at IS NOT NULL
       OR vacancy.hired_trade_id IS DISTINCT FROM actor
       OR NOT EXISTS (
         SELECT 1 FROM public.applications
         WHERE job_id = NEW.job_id AND trade_id = actor
           AND builder_id = vacancy.builder_id AND status = 'hired'
       ) THEN
      RAISE EXCEPTION 'Only the hired trade may check in to an active job' USING ERRCODE = '23514';
    END IF;
    IF NEW.check_out_at IS NOT NULL OR NEW.check_out_lat IS NOT NULL OR NEW.check_out_lng IS NOT NULL THEN
      RAISE EXCEPTION 'A new timesheet must start with check-in only' USING ERRCODE = '23514';
    END IF;
    -- The app omits these fields. Override submitted values too, so a client
    -- cannot fabricate an earlier start or a different creation timestamp.
    NEW.check_in_at := statement_timestamp();
    NEW.created_at := NEW.check_in_at;
    RETURN NEW;
  END IF;

  IF OLD.check_out_at IS NOT NULL THEN
    RAISE EXCEPTION 'A completed timesheet cannot be changed' USING ERRCODE = '23514';
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.job_id IS DISTINCT FROM OLD.job_id
     OR NEW.builder_id IS DISTINCT FROM OLD.builder_id
     OR NEW.trade_id IS DISTINCT FROM OLD.trade_id
     OR NEW.check_in_at IS DISTINCT FROM OLD.check_in_at
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.check_in_lat IS DISTINCT FROM OLD.check_in_lat
     OR NEW.check_in_lng IS DISTINCT FROM OLD.check_in_lng
     OR NEW.note IS DISTINCT FROM OLD.note THEN
    RAISE EXCEPTION 'Timesheet identity and check-in details are immutable' USING ERRCODE = '42501';
  END IF;
  IF NEW.check_out_at IS NULL OR NOT isfinite(NEW.check_out_at)
     OR NEW.check_out_at < OLD.check_in_at
     OR statement_timestamp() < OLD.check_in_at THEN
    RAISE EXCEPTION 'Check-out must be a finite time at or after check-in' USING ERRCODE = '23514';
  END IF;
  -- Keep rejecting malformed or out-of-order input, but never let a client's
  -- clock determine shift duration. Privileged historical maintenance already
  -- returned above and retains its submitted timestamps.
  NEW.check_out_at := statement_timestamp();
  -- Do not recheck job/hire eligibility here: closing, deleting or reassigning
  -- a job must not strand its trade with an existing open entry.
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."guard_timesheet_lifecycle"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."invalidate_deleted_verification_file"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
 IF OLD.bucket_id='private-docs' THEN
  UPDATE public.verification_documents SET deleted_at=coalesce(deleted_at,clock_timestamp()),
   status='rejected',rejection_reason='Evidence file removed. Upload a new document.'
  -- Include receipts hidden before the physical file was removed: restoring
  -- their deleted_at must never attach their old decision to replacement bytes.
  WHERE file_path=OLD.name;
 END IF;
 RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."invalidate_deleted_verification_file"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invalidate_removed_verification_evidence"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND (NEW.deleted_at IS NULL OR OLD.deleted_at IS NOT NULL) THEN RETURN NEW; END IF;
 IF OLD.status='approved' AND OLD.doc_type IN ('abn_certificate','trade_licence') THEN
  UPDATE public.verifications SET status='failed',failure_reason='manual_evidence_removed',
   manual_fallback_allowed=true,last_checked_at=clock_timestamp(),updated_at=clock_timestamp()
  WHERE user_id=OLD.trade_id AND status='verified' AND register_source='admin_manual'
   AND verified_at=OLD.reviewed_at
   AND kind=CASE OLD.doc_type WHEN 'abn_certificate' THEN 'abn' ELSE 'licence' END;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."invalidate_removed_verification_evidence"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
 SELECT EXISTS(SELECT 1 FROM public.verifications WHERE user_id=p_uid
  AND kind='abn' AND status='verified' AND (expires_at IS NULL OR expires_at>now()));
$$;


ALTER FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text" DEFAULT NULL::"text", "p_target_id" "uuid" DEFAULT NULL::"uuid", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_id uuid;
BEGIN
  PERFORM public.admin_company_require('session');

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
  v_old text;
  v_actor uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_reason := 'signup';
    v_old := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.role IS NOT DISTINCT FROM NEW.role THEN RETURN NEW; END IF;
    v_reason := 'admin_change';
    v_old := OLD.role;
  ELSE RETURN NEW;
  END IF;
  -- Never honor caller-supplied context on an authenticated signup request.
  IF auth.role() = 'service_role'
    AND nullif(current_setting('jobdun.admin_actor_id', true), '') IS NOT NULL THEN
    v_actor := current_setting('jobdun.admin_actor_id', true)::uuid;
    v_reason := nullif(current_setting('jobdun.admin_role_reason', true), '');
  END IF;
  INSERT INTO public.user_role_events(user_id, old_role, new_role, changed_by, reason)
  VALUES (NEW.user_id, v_old, NEW.role, v_actor, v_reason);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."log_role_event"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notification_category"("p_type" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'public'
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
  v_token    text;
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

  -- Read the shared secret; if Vault is unavailable, degrade to no-push (never break the insert).
  BEGIN
    SELECT decrypted_secret INTO v_token
      FROM vault.decrypted_secrets WHERE name = 'push_internal_token';
  EXCEPTION WHEN OTHERS THEN
    v_token := NULL;
  END;

  BEGIN
    PERFORM net.http_post(
      url := 'https://zethpanvkfyijislxesn.supabase.co/functions/v1/push-send',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpldGhwYW52a2Z5aWppc2x4ZXNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MjYyMzUsImV4cCI6MjA5MzQwMjIzNX0.YvW3jHql3SfiwGo7y2y_AwewMa3igyz7nNTbhNC9s5E',
        'Content-Type', 'application/json',
        'x-internal-token', COALESCE(v_token, '')
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



CREATE OR REPLACE FUNCTION "public"."notify_on_new_review"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_reviewer_name text;
BEGIN
  -- Defensive: never notify someone about their own review.
  IF NEW.reviewee_id = NEW.reviewer_id THEN
    RETURN NEW;
  END IF;

  SELECT p.display_name INTO v_reviewer_name
    FROM public.profiles p
   WHERE p.id = NEW.reviewer_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.reviewee_id,
    'review_received',
    'New review',
    COALESCE(NULLIF(v_reviewer_name, ''), 'Someone')
      || ' rated you ' || NEW.rating || '/5',
    jsonb_build_object(
      'review_id', NEW.id,
      'job_id',    NEW.job_id,
      'rating',    NEW.rating
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_on_new_review"() OWNER TO "postgres";


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
    SET "search_path" TO 'public'
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
    AS $_$
DECLARE
 v_doc public.verification_documents%ROWTYPE;
 v_existing public.verifications%ROWTYPE;
 v_kind text;
 v_role text;
 v_owner uuid;
 v_number text;
 v_class text;
 v_label text;
 v_notes text := nullif(regexp_replace(p_notes,'^[[:space:]]+|[[:space:]]+$','','g'),'');
 v_checked timestamptz;
 v_checksum integer;
 v_file_id uuid;
 v_file_path text;
BEGIN
 PERFORM public.admin_company_require('verification.manage');
 IF p_status IS NULL OR p_status NOT IN ('approved','rejected') THEN
  RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
 END IF;
 IF v_notes IS NULL THEN RAISE EXCEPTION 'review_notes_required' USING ERRCODE='22023'; END IF;
 SELECT trade_id,file_path INTO v_owner,v_file_path FROM public.verification_documents WHERE id=p_document_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'document_not_found'; END IF;
 -- Lock Storage before the receipt: Storage DELETE already holds the object
 -- row before its trigger locks receipts. The owner still serializes competing
 -- documents, and revocation uses the same receipt -> credential order.
 PERFORM 1 FROM public.profiles WHERE id=v_owner FOR UPDATE;
 SELECT role INTO v_role FROM public.user_roles WHERE user_id=v_owner FOR UPDATE;
 IF p_status='approved' THEN
  SELECT id INTO v_file_id FROM storage.objects
   WHERE bucket_id='private-docs' AND name=v_file_path FOR UPDATE;
 END IF;
 SELECT * INTO v_doc FROM public.verification_documents WHERE id=p_document_id FOR UPDATE;
 IF v_doc.id IS NULL THEN RAISE EXCEPTION 'document_not_found'; END IF;
 IF v_doc.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'document_deleted'; END IF;
 IF v_doc.status <> 'pending' THEN RAISE EXCEPTION 'document_not_pending'; END IF;
 v_kind := CASE v_doc.doc_type WHEN 'abn_certificate' THEN 'abn' WHEN 'trade_licence' THEN 'licence' END;
 IF p_status='approved' THEN
  IF v_doc.expiry_date < current_date THEN RAISE EXCEPTION 'document_expired'; END IF;
  IF v_role IS NULL OR v_role NOT IN ('builder','trade')
   OR (v_kind='abn' AND v_role <> 'builder') OR (v_kind='licence' AND v_role <> 'trade') THEN
   RAISE EXCEPTION 'document_role_mismatch' USING ERRCODE='42501';
  END IF;
  IF v_doc.file_path IS DISTINCT FROM v_file_path
   OR v_doc.trade_id IS DISTINCT FROM v_owner
   OR v_doc.file_path IS NULL
   OR split_part(v_doc.file_path,'/',1) <> v_doc.trade_id::text
   OR length(v_doc.file_path)<=37 THEN
   RAISE EXCEPTION 'document_file_mismatch';
  END IF;
  IF v_file_id IS NULL THEN RAISE EXCEPTION 'document_file_missing'; END IF;
  v_number := coalesce(nullif(btrim(p_confirmed_number),''),nullif(btrim(v_doc.document_number),''));
  v_class := coalesce(nullif(btrim(p_trade_class),''),nullif(btrim(v_doc.trade_class),''));
  IF v_kind='abn' THEN
   v_number := regexp_replace(v_number,'[[:space:]]','','g');
   IF v_number IS NULL OR v_number !~ '^[0-9]{11}$' THEN
    RAISE EXCEPTION 'invalid_abn_number' USING ERRCODE='22023';
   END IF;
   SELECT sum((substr(v_number,n,1)::int - CASE WHEN n=1 THEN 1 ELSE 0 END)
    * (ARRAY[10,1,3,5,7,9,11,13,15,17,19])[n]) INTO v_checksum FROM generate_series(1,11) n;
   IF v_checksum % 89 <> 0 THEN RAISE EXCEPTION 'invalid_abn_number' USING ERRCODE='22023'; END IF;
  ELSIF v_kind='licence' THEN
   IF v_number IS NULL OR v_number !~ '^[A-Za-z0-9][A-Za-z0-9 /-]{0,79}$' THEN
    RAISE EXCEPTION 'invalid_licence_number' USING ERRCODE='22023';
   END IF;
   IF v_doc.state IS NULL OR v_doc.state NOT IN ('NSW','VIC','QLD','SA','WA','TAS','ACT','NT') THEN
    RAISE EXCEPTION 'invalid_licence_state' USING ERRCODE='22023';
   END IF;
  END IF;
  IF v_kind IS NOT NULL THEN
   SELECT * INTO v_existing FROM public.verifications WHERE user_id=v_owner AND kind=v_kind FOR UPDATE;
   IF v_existing.id IS NOT NULL
    AND greatest(v_existing.last_checked_at,v_existing.updated_at,v_existing.verified_at)
      > coalesce(v_doc.submitted_at,v_doc.created_at) THEN
    RAISE EXCEPTION 'document_stale';
   END IF;
  END IF;
 END IF;
 v_checked := clock_timestamp();
 UPDATE public.verification_documents SET status=p_status::public.document_status,
  reviewed_at=v_checked, reviewed_by=auth.uid(), review_notes=v_notes,
  rejection_reason=CASE WHEN p_status='rejected' THEN v_notes END
 WHERE id=p_document_id;
 IF p_status='approved' AND v_kind IS NOT NULL THEN
  INSERT INTO public.verifications(user_id,kind,status,abn,licence_number,
   licence_state,licence_trade_class,register_source,detail_captured_at,
   verified_at,expires_at,manual_fallback_allowed,last_checked_at,failure_reason)
  VALUES(v_owner,v_kind,'verified',CASE WHEN v_kind='abn' THEN v_number END,
   CASE WHEN v_kind='licence' THEN v_number END,CASE WHEN v_kind='licence' THEN v_doc.state END,
   CASE WHEN v_kind='licence' THEN v_class END,'admin_manual',v_checked,v_checked,
   -- A document valid on its expiry date remains valid until that day ends.
   CASE WHEN v_doc.expiry_date IS NOT NULL THEN (v_doc.expiry_date+1)::timestamptz END,
   false,v_checked,NULL)
  ON CONFLICT (user_id,kind) DO UPDATE SET status='verified',abn=excluded.abn,
   licence_number=excluded.licence_number,licence_state=excluded.licence_state,
   licence_trade_class=excluded.licence_trade_class,register_source='admin_manual',
   detail_captured_at=v_checked,verified_at=v_checked,expires_at=excluded.expires_at,
   manual_fallback_allowed=false,last_checked_at=v_checked,failure_reason=NULL,updated_at=v_checked;
 END IF;
 v_label := CASE v_doc.doc_type WHEN 'abn_certificate' THEN 'ABN certificate'
  WHEN 'trade_licence' THEN 'trade licence' WHEN 'public_liability' THEN 'public liability cover'
  WHEN 'workers_compensation' THEN 'workers compensation cover' WHEN 'white_card' THEN 'white card'
  WHEN 'photo_id' THEN 'photo ID' ELSE 'document' END;
 INSERT INTO public.notifications(user_id,type,title,body,data) VALUES(v_owner,
  CASE WHEN p_status='approved' THEN 'verification_approved' ELSE 'verification_rejected' END,
  CASE WHEN p_status='approved' THEN 'Your '||v_label||' was approved' ELSE 'Your '||v_label||' needs another look' END,
  CASE WHEN p_status='approved' THEN 'Your '||v_label||' was approved. Phone verification is separate.'
   ELSE v_notes||' Tap to upload a replacement document.' END,
  jsonb_build_object('doc_type',v_doc.doc_type,'kind',v_kind,'document_id',p_document_id));
 PERFORM public.log_admin_action('review_verification_document','verification_documents',p_document_id,
  jsonb_build_object('status',p_status,'promoted_kind',CASE WHEN p_status='approved' THEN v_kind END,
   'notes',v_notes,'confirmed_number',CASE WHEN v_kind IS NOT NULL AND p_status='approved' THEN v_number END,
   'trade_class',CASE WHEN v_kind='licence' AND p_status='approved' THEN v_class END));
END;
$_$;


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
    AS $_$
DECLARE
 v_id uuid;
 v_reason text := nullif(regexp_replace(p_reason,'^[[:space:]]+|[[:space:]]+$','','g'),'');
BEGIN
 PERFORM public.admin_company_require('verification.manage');
 IF p_kind IS NULL OR p_kind NOT IN ('abn','licence') THEN RAISE EXCEPTION 'invalid_kind' USING ERRCODE='22023'; END IF;
 IF v_reason IS NULL THEN RAISE EXCEPTION 'reason_required' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_user_id FOR UPDATE;
 -- Same lock order as review; collect receipts before locking the projection.
 PERFORM 1 FROM public.verification_documents WHERE trade_id=p_user_id
  AND doc_type=(CASE WHEN p_kind='abn' THEN 'abn_certificate' ELSE 'trade_licence' END)::public.document_doc_type
  ORDER BY id FOR UPDATE;
 SELECT id INTO v_id FROM public.verifications WHERE user_id=p_user_id AND kind=p_kind AND status='verified' FOR UPDATE;
 IF v_id IS NULL THEN RAISE EXCEPTION 'no_verified_row'; END IF;
 UPDATE public.verifications SET status='failed',failure_reason='admin_revoked: '||v_reason,
  manual_fallback_allowed=true,last_checked_at=clock_timestamp(),updated_at=clock_timestamp() WHERE id=v_id;
 UPDATE public.verification_documents SET status='rejected',reviewed_at=clock_timestamp(),
  reviewed_by=auth.uid(),review_notes=v_reason,rejection_reason=v_reason
 WHERE trade_id=p_user_id AND status='approved'
  AND doc_type=(CASE WHEN p_kind='abn' THEN 'abn_certificate' ELSE 'trade_licence' END)::public.document_doc_type;
 INSERT INTO public.notifications(user_id,type,title,body,data) VALUES(p_user_id,'verification_rejected',
  CASE WHEN p_kind='abn' THEN 'Business verification revoked' ELSE 'Trade licence verification revoked' END,
  v_reason||' Tap to upload a replacement document.',jsonb_build_object('kind',p_kind,'reason',v_reason));
 PERFORM public.log_admin_action('revoke_verification','verifications',v_id,jsonb_build_object('kind',p_kind,'reason',v_reason));
END;
$_$;


ALTER FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") IS 'Admin un-verify: flips the latest verified (user, kind) row to failed with failure_reason "admin_revoked: <reason>" and re-opens manual fallback. Notifies the user and audits via log_admin_action. The is_verified trigger recomputes cross-user surfaces automatically.';



CREATE OR REPLACE FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric DEFAULT NULL::numeric, "p_available_only" boolean DEFAULT false, "p_query" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_apprentice" boolean DEFAULT false) RETURNS TABLE("id" "uuid", "full_name" "text", "primary_trade" "text", "crew_size" integer, "years_experience" integer, "hourly_rate_min" numeric, "hourly_rate_max" numeric, "hourly_rate_visible" boolean, "service_radius_km" integer, "base_suburb" "text", "base_state" "text", "base_postcode" "text", "base_formatted_address" "text", "base_place_id" "text", "base_latitude" double precision, "base_longitude" double precision, "about" "text", "trade_other" "text", "licence_url" "text", "portfolio_urls" "text"[], "is_verified" boolean, "average_rating" numeric, "rating_count" integer, "is_available" boolean, "available_from" "date", "distance_km" double precision, "is_apprentice" boolean, "apprenticeship_stage" "text", "site_tickets" "text"[])
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    sub.id, sub.full_name, sub.primary_trade, sub.crew_size,
    sub.years_experience,
    CASE WHEN sub.hourly_rate_visible THEN sub.hourly_rate_min END,
    CASE WHEN sub.hourly_rate_visible THEN sub.hourly_rate_max END,
    sub.hourly_rate_visible, sub.service_radius_km,
    sub.base_suburb, sub.base_state, sub.base_postcode,
    NULL::text,  -- base_formatted_address: exact address never leaves the DB
    NULL::text,  -- base_place_id
    round(sub.base_latitude::numeric, 2)::double precision,
    round(sub.base_longitude::numeric, 2)::double precision,
    sub.about, sub.trade_other,
    NULL::text,  -- licence_url: private-docs pointer; badge = is_verified
    sub.portfolio_urls, EXISTS (SELECT 1 FROM public.verifications v WHERE v.user_id=sub.id AND v.kind='licence' AND v.status='verified' AND (v.expires_at IS NULL OR v.expires_at>now())),
    sub.average_rating, sub.rating_count,
    sub.is_available, sub.available_from, sub.distance_km,
    -- Apprentice projection. site_tickets is SELF-DECLARED: the caller must
    -- render it as a distinct, weaker tier than is_verified. Never merge them.
    sub.is_apprentice, sub.apprenticeship_stage, sub.site_tickets
  FROM (
    SELECT
      tp.*,
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
      -- The one new predicate. coalesce so an explicit NULL from a client
      -- behaves as "qualified trades", never as "everyone".
      AND tp.is_apprentice = coalesce(p_apprentice, false)
  ) sub
  WHERE sub.distance_km <= p_radius_km
  ORDER BY sub.distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$;


ALTER FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer, "p_apprentice" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stamp_verification_submission"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
 IF auth.role() = 'authenticated' THEN
  NEW.created_at := clock_timestamp();
  NEW.submitted_at := NEW.created_at;
 END IF;
 RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."stamp_verification_submission"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_job_application_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.jobs
    SET application_count = application_count + 1
    WHERE id = NEW.job_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.jobs
    SET application_count = GREATEST(application_count - 1, 0)
    WHERE id = OLD.job_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."sync_job_application_count"() OWNER TO "postgres";


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
      AND (expires_at IS NULL OR expires_at>now())
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
    SET "search_path" TO 'public'
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


CREATE TABLE IF NOT EXISTS "public"."admin_platform_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_platform_settings_key_check" CHECK (("key" = ANY (ARRAY['maintenance_notice'::"text", 'minimum_android_version'::"text", 'minimum_ios_version'::"text", 'marketplace_enabled'::"text", 'registration_enabled'::"text", 'admin_mfa_required'::"text"])))
);


ALTER TABLE "public"."admin_platform_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_staff" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "staff_role" "text" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_staff_staff_role_check" CHECK (("staff_role" = ANY (ARRAY['owner'::"text", 'operations'::"text", 'verification'::"text", 'support'::"text", 'read_only'::"text"]))),
    CONSTRAINT "admin_staff_version_check" CHECK (("version" > 0))
);


ALTER TABLE "public"."admin_staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_support_cases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "subject" "text" NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "assignee_id" "uuid",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_support_cases_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'normal'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "admin_support_cases_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'closed'::"text"]))),
    CONSTRAINT "admin_support_cases_subject_check" CHECK ((("length"("btrim"("subject")) >= 1) AND ("length"("btrim"("subject")) <= 200)))
);


ALTER TABLE "public"."admin_support_cases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_support_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "case_id" "uuid" NOT NULL,
    "author_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_support_notes_body_check" CHECK ((("length"("btrim"("body")) >= 1) AND ("length"("btrim"("body")) <= 5000)))
);


ALTER TABLE "public"."admin_support_notes" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'trade'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_roles_role_check" CHECK (("role" = ANY (ARRAY['builder'::"text", 'trade'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."admin_user_directory" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."display_name",
    "p"."avatar_url",
    "p"."created_at",
    "p"."user_status",
    "p"."phone",
    "r"."role"
   FROM ("public"."profiles" "p"
     LEFT JOIN "public"."user_roles" "r" ON (("r"."user_id" = "p"."id")))
  WHERE ( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission");


ALTER VIEW "public"."admin_user_directory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_verification_assignments" (
    "id" "uuid" NOT NULL,
    "assignee_id" "uuid",
    "version" integer DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."admin_verification_assignments" OWNER TO "postgres";


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
    "open_to_apprentices" boolean DEFAULT false NOT NULL,
    "job_kind" "text" DEFAULT 'trade_job'::"text" NOT NULL,
    CONSTRAINT "jobs_apprenticeship_terms" CHECK ((("job_kind" <> 'apprenticeship'::"text") OR ("open_to_apprentices" AND ("pricing_type" = 'builder_set'::"public"."job_pricing_type") AND ("pricing_unit" = 'hourly'::"public"."job_pricing_unit") AND ("budget_amount" IS NOT NULL) AND ("budget_amount" > (0)::numeric) AND ("budget_amount" < 'Infinity'::numeric)))),
    CONSTRAINT "jobs_budget_amount_positive" CHECK ((("budget_amount" IS NULL) OR ("budget_amount" > (0)::numeric))),
    CONSTRAINT "jobs_budget_amount_when_set" CHECK (((("pricing_type" = 'builder_set'::"public"."job_pricing_type") AND ("budget_amount" IS NOT NULL)) OR ("pricing_type" = 'request_quote'::"public"."job_pricing_type"))),
    CONSTRAINT "jobs_kind_valid" CHECK (("job_kind" = ANY (ARRAY['trade_job'::"text", 'apprenticeship'::"text"])))
);


ALTER TABLE "public"."jobs" OWNER TO "postgres";


COMMENT ON COLUMN "public"."jobs"."open_to_apprentices" IS 'Builder invites apprentice applicants. Drives a job-card chip and an apprentice-side filter -- it gates nothing.';



CREATE OR REPLACE VIEW "public"."application_job_summaries" WITH ("security_barrier"='true', "security_invoker"='false') AS
 SELECT "id",
    "title",
    "suburb",
    "state",
    "status",
    "budget_amount",
    "pricing_unit",
    "pricing_type",
    "job_kind",
    "open_to_apprentices"
   FROM "public"."jobs" "j"
  WHERE ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM "public"."applications" "a"
          WHERE (("a"."job_id" = "j"."id") AND ((( SELECT "auth"."uid"() AS "uid") = "a"."builder_id") OR (( SELECT "auth"."uid"() AS "uid") = "a"."trade_id"))))));


ALTER VIEW "public"."application_job_summaries" OWNER TO "postgres";


COMMENT ON VIEW "public"."application_job_summaries" IS 'Read-only job summaries for application participants, including closed, cancelled and soft-deleted jobs. Excludes description, precise location and contact details; does not expand jobs RLS.';



CREATE TABLE IF NOT EXISTS "public"."blocks" (
    "blocker_id" "uuid" NOT NULL,
    "blocked_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "blocks_no_self_block" CHECK (("blocker_id" <> "blocked_id"))
);


ALTER TABLE "public"."blocks" OWNER TO "postgres";


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


CREATE OR REPLACE VIEW "public"."builder_profiles_public" AS
 SELECT "id",
    "company_name",
    "abn",
    "about",
    "website",
    "years_in_business",
    "service_suburb",
    "service_state",
    "service_postcode",
    ("round"(("service_latitude")::numeric, 2))::double precision AS "service_latitude",
    ("round"(("service_longitude")::numeric, 2))::double precision AS "service_longitude",
    "average_rating",
    "rating_count",
    "created_at"
   FROM "public"."builder_profiles" "bp"
  WHERE ("deleted_at" IS NULL);


ALTER VIEW "public"."builder_profiles_public" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."builder_unverified_acknowledgements" (
    "builder_id" "uuid" NOT NULL,
    "acknowledged_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "app_version" "text"
);


ALTER TABLE "public"."builder_unverified_acknowledgements" OWNER TO "postgres";


COMMENT ON TABLE "public"."builder_unverified_acknowledgements" IS 'One-time consent that the builder understands the risk of including unverified workers in their applicant filter. Immutable record per builder.';



CREATE TABLE IF NOT EXISTS "public"."contact_enquiries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "phone" "text",
    "role" "text",
    "state" "text",
    "message" "text" NOT NULL,
    "user_agent" "text",
    "ip_hash" "text",
    CONSTRAINT "contact_enquiries_email_check" CHECK ((("char_length"("email") >= 3) AND ("char_length"("email") <= 320))),
    CONSTRAINT "contact_enquiries_ip_hash_check" CHECK ((("ip_hash" IS NULL) OR ("char_length"("ip_hash") <= 64))),
    CONSTRAINT "contact_enquiries_message_check" CHECK ((("char_length"("message") >= 1) AND ("char_length"("message") <= 5000))),
    CONSTRAINT "contact_enquiries_name_check" CHECK ((("char_length"("name") >= 1) AND ("char_length"("name") <= 200))),
    CONSTRAINT "contact_enquiries_phone_check" CHECK ((("phone" IS NULL) OR ("char_length"("phone") <= 40))),
    CONSTRAINT "contact_enquiries_role_check" CHECK ((("role" IS NULL) OR ("char_length"("role") <= 40))),
    CONSTRAINT "contact_enquiries_state_check" CHECK ((("state" IS NULL) OR ("char_length"("state") <= 10))),
    CONSTRAINT "contact_enquiries_user_agent_check" CHECK ((("user_agent" IS NULL) OR ("char_length"("user_agent") <= 512)))
);


ALTER TABLE "public"."contact_enquiries" OWNER TO "postgres";


COMMENT ON TABLE "public"."contact_enquiries" IS 'Marketing-site contact form submissions. Service-role only (contact-send edge function).';



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
    "trade_last_read_at" timestamp with time zone,
    "builder_pinned_at" timestamp with time zone,
    "trade_pinned_at" timestamp with time zone,
    "builder_muted_at" timestamp with time zone,
    "trade_muted_at" timestamp with time zone
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


CREATE OR REPLACE VIEW "public"."jobs_public_browse" AS
 SELECT "id",
    "builder_id",
    "title",
    "description",
    "suburb",
    "state",
    "postcode",
    "trade_type_required",
    "budget_amount",
    "pricing_unit",
    "pricing_type",
    "urgency",
    "requires_verified",
    "requires_white_card",
    "requires_public_liability",
    "required_certifications",
    "start_date",
    "estimated_duration_days",
    "duration_text",
    "application_count",
    "view_count",
    "status",
    "published_at",
    "created_at",
    "updated_at",
    ("round"(("latitude")::numeric, 2))::double precision AS "latitude",
    ("round"(("longitude")::numeric, 2))::double precision AS "longitude",
    NULLIF("concat_ws"(', '::"text", NULLIF("suburb", ''::"text"), NULLIF("state", ''::"text")), ''::"text") AS "formatted_address",
    NULL::"text" AS "place_id",
    NULL::timestamp with time zone AS "deleted_at",
    "search_vector",
    "open_to_apprentices",
    "job_kind"
   FROM "public"."jobs" "j"
  WHERE (("status" = ANY (ARRAY['open'::"public"."job_status", 'filled'::"public"."job_status"])) AND ("deleted_at" IS NULL));


ALTER VIEW "public"."jobs_public_browse" OWNER TO "postgres";


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
    "unavailable_dates" "date"[] DEFAULT '{}'::"date"[] NOT NULL,
    "is_apprentice" boolean DEFAULT false NOT NULL,
    "apprenticeship_stage" "text",
    "site_tickets" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "resume_path" "text",
    "resume_uploaded_at" timestamp with time zone,
    CONSTRAINT "trade_profiles_apprenticeship_stage_valid" CHECK ((("apprenticeship_stage" IS NULL) OR ("apprenticeship_stage" = ANY (ARRAY['pre_apprentice'::"text", 'year_1'::"text", 'year_2'::"text", 'year_3'::"text", 'year_4'::"text"]))))
);


ALTER TABLE "public"."trade_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."trade_profiles"."unavailable_dates" IS '#13 availability calendar: specific dates the trade has blocked off (booked / on leave). Date-only; default empty. Owner-write via the existing trade_profiles RLS; readable by authenticated users for the profile view.';



COMMENT ON COLUMN "public"."trade_profiles"."is_apprentice" IS 'True when this trade is seeking an apprenticeship. Flips the profile to the apprentice layout (no rates, no insurance, no jobs-completed stat) and moves the row to the APPRENTICES side of search_trades.';



COMMENT ON COLUMN "public"."trade_profiles"."site_tickets" IS 'SELF-DECLARED site ticket slugs (FK-by-convention to site_tickets.slug). A tick is a claim, NOT proof -- verified credentials live in verification_documents and surface via get_trade_public_credentials. Never merge the two lists on a display surface.';



COMMENT ON COLUMN "public"."trade_profiles"."resume_path" IS 'private-docs path, {uid}/resume/{epoch}.{ext}. Never a public URL: reading it requires a signed URL gated by private_docs_resume_applied_builder_select.';



CREATE OR REPLACE VIEW "public"."profile_completeness" WITH ("security_invoker"='on') AS
 SELECT "p"."id",
    "ur"."role",
        CASE "ur"."role"
            WHEN 'builder'::"text" THEN ((((((("bp"."company_name" IS NOT NULL) AND ("bp"."company_name" <> ''::"text")))::integer + ((("bp"."abn" IS NOT NULL) AND ("bp"."abn" <> ''::"text")))::integer) + ((("bp"."service_suburb" IS NOT NULL) AND ("bp"."service_suburb" <> ''::"text")))::integer) + (("p"."phone_verified_at" IS NOT NULL))::integer) * 25)
            WHEN 'trade'::"text" THEN
            CASE
                WHEN "tp"."is_apprentice" THEN (((((((COALESCE("tp"."primary_trade", ''::"text") <> ''::"text"))::integer + (("btrim"(COALESCE("tp"."about", ''::"text")) <> ''::"text"))::integer) + ((COALESCE("tp"."resume_path", ''::"text") <> ''::"text"))::integer) + ((COALESCE("array_length"("tp"."portfolio_urls", 1), 0) > 0))::integer) + ((COALESCE("tp"."base_suburb", ''::"text") <> ''::"text"))::integer) * 20)
                ELSE (((((((("tp"."primary_trade" IS NOT NULL) AND ("tp"."primary_trade" <> ''::"text")))::integer + ((("tp"."licence_url" IS NOT NULL) AND ("tp"."licence_url" <> ''::"text")))::integer) + ((("tp"."base_suburb" IS NOT NULL) AND ("tp"."base_suburb" <> ''::"text")))::integer) + (("p"."phone_verified_at" IS NOT NULL))::integer) + ((COALESCE("array_length"("tp"."portfolio_urls", 1), 0) > 0))::integer) * 20)
            END
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



CREATE TABLE IF NOT EXISTS "public"."reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reported_id" "uuid" NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "message_id" "uuid",
    "reason" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "reports_details_check" CHECK (("char_length"("details") <= 500)),
    CONSTRAINT "reports_no_self_report" CHECK (("reporter_id" <> "reported_id")),
    CONSTRAINT "reports_reason_check" CHECK (("reason" = ANY (ARRAY['harassment'::"text", 'spam_or_scam'::"text", 'fake_profile'::"text", 'inappropriate_content'::"text", 'other'::"text"]))),
    CONSTRAINT "reports_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'reviewed'::"text", 'actioned'::"text", 'dismissed'::"text"])))
);


ALTER TABLE "public"."reports" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."site_tickets" (
    "slug" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "short_name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "doc_type" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "site_tickets_category_check" CHECK (("category" = ANY (ARRAY['induction'::"text", 'safety'::"text", 'licence'::"text", 'transport'::"text"])))
);


ALTER TABLE "public"."site_tickets" OWNER TO "postgres";


COMMENT ON TABLE "public"."site_tickets" IS 'Reference list of site tickets an apprentice or tradie can self-declare. doc_type non-null means the ticket has a verification_documents review path and can reach the VERIFIED tier; null means self-declared only.';



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
    "version" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "trade_categories_category_check" CHECK (("category" = ANY (ARRAY['electrical'::"text", 'structural'::"text", 'finishing'::"text", 'heavy_specialist'::"text"])))
);


ALTER TABLE "public"."trade_categories" OWNER TO "postgres";


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



CREATE OR REPLACE VIEW "public"."trade_profiles_public" AS
 SELECT "id",
    "full_name",
    "primary_trade",
    "trade_other",
    "about",
    "base_suburb",
    "base_state",
    "base_postcode",
    ("round"(("base_latitude")::numeric, 2))::double precision AS "base_latitude",
    ("round"(("base_longitude")::numeric, 2))::double precision AS "base_longitude",
    "crew_size",
    "years_experience",
    "service_radius_km",
    "portfolio_urls",
    (EXISTS ( SELECT 1
           FROM "public"."verifications" "v"
          WHERE (("v"."user_id" = "tp"."id") AND ("v"."kind" = 'licence'::"text") AND ("v"."status" = 'verified'::"public"."verification_status") AND (("v"."expires_at" IS NULL) OR ("v"."expires_at" > "now"()))))) AS "is_verified",
    "is_available",
    "available_from",
        CASE
            WHEN "hourly_rate_visible" THEN "hourly_rate_min"
            ELSE NULL::numeric
        END AS "hourly_rate_min",
        CASE
            WHEN "hourly_rate_visible" THEN "hourly_rate_max"
            ELSE NULL::numeric
        END AS "hourly_rate_max",
    "hourly_rate_visible",
    "average_rating",
    "rating_count",
    "created_at",
    "is_apprentice",
    "apprenticeship_stage",
    "site_tickets"
   FROM "public"."trade_profiles" "tp"
  WHERE ("deleted_at" IS NULL);


ALTER VIEW "public"."trade_profiles_public" OWNER TO "postgres";


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
    CONSTRAINT "verification_rate_limits_endpoint_check" CHECK (("endpoint" = ANY (ARRAY['verify-abn'::"text", 'verify-licence'::"text", 'admin-users-invite'::"text", 'admin-users-set-role'::"text"])))
);


ALTER TABLE "public"."verification_rate_limits" OWNER TO "postgres";


COMMENT ON TABLE "public"."verification_rate_limits" IS 'bucket_key is "user:<uuid>" or "ip:<addr>". Service-role-only writes.';



ALTER TABLE ONLY "public"."admin_actions"
    ADD CONSTRAINT "admin_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_platform_settings"
    ADD CONSTRAINT "admin_platform_settings_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."admin_platform_settings"
    ADD CONSTRAINT "admin_platform_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_staff"
    ADD CONSTRAINT "admin_staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_staff"
    ADD CONSTRAINT "admin_staff_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."admin_support_cases"
    ADD CONSTRAINT "admin_support_cases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_support_notes"
    ADD CONSTRAINT "admin_support_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."admin_verification_assignments"
    ADD CONSTRAINT "admin_verification_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_trade_id_key" UNIQUE ("job_id", "trade_id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_pkey" PRIMARY KEY ("blocker_id", "blocked_id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_profiles"
    ADD CONSTRAINT "builder_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."builder_unverified_acknowledgements"
    ADD CONSTRAINT "builder_unverified_acknowledgements_pkey" PRIMARY KEY ("builder_id");



ALTER TABLE ONLY "public"."contact_enquiries"
    ADD CONSTRAINT "contact_enquiries_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_job_id_reviewer_id_key" UNIQUE ("job_id", "reviewer_id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saved_jobs"
    ADD CONSTRAINT "saved_jobs_pkey" PRIMARY KEY ("user_id", "job_id");



ALTER TABLE ONLY "public"."site_tickets"
    ADD CONSTRAINT "site_tickets_pkey" PRIMARY KEY ("slug");



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



ALTER TABLE ONLY "public"."verifications"
    ADD CONSTRAINT "verifications_user_kind_unique" UNIQUE ("user_id", "kind");



CREATE INDEX "admin_actions_actor_id_idx" ON "public"."admin_actions" USING "btree" ("actor_id");



CREATE INDEX "admin_actions_created_at_idx" ON "public"."admin_actions" USING "btree" ("created_at" DESC);



CREATE INDEX "admin_actions_target_idx" ON "public"."admin_actions" USING "btree" ("target_table", "target_id");



CREATE INDEX "admin_support_cases_user_idx" ON "public"."admin_support_cases" USING "btree" ("user_id");



CREATE INDEX "admin_support_notes_case_idx" ON "public"."admin_support_notes" USING "btree" ("case_id", "created_at");



CREATE INDEX "applications_builder_id_idx" ON "public"."applications" USING "btree" ("builder_id");



CREATE INDEX "applications_job_id_idx" ON "public"."applications" USING "btree" ("job_id");



CREATE INDEX "applications_trade_id_idx" ON "public"."applications" USING "btree" ("trade_id");



CREATE INDEX "blocks_blocked_id_idx" ON "public"."blocks" USING "btree" ("blocked_id");



CREATE INDEX "bookings_builder_idx" ON "public"."bookings" USING "btree" ("builder_id");



CREATE INDEX "bookings_date_idx" ON "public"."bookings" USING "btree" ("scheduled_date");



CREATE INDEX "bookings_trade_idx" ON "public"."bookings" USING "btree" ("trade_id");



CREATE INDEX "builder_profiles_average_rating_idx" ON "public"."builder_profiles" USING "btree" ("average_rating");



CREATE INDEX "conversations_builder_active_idx" ON "public"."conversations" USING "btree" ("builder_id", "last_message_at" DESC) WHERE ("builder_archived_at" IS NULL);



CREATE INDEX "conversations_builder_id_idx" ON "public"."conversations" USING "btree" ("builder_id");



CREATE INDEX "conversations_builder_pinned_idx" ON "public"."conversations" USING "btree" ("builder_id", "builder_pinned_at" DESC) WHERE ("builder_pinned_at" IS NOT NULL);



CREATE INDEX "conversations_trade_active_idx" ON "public"."conversations" USING "btree" ("trade_id", "last_message_at" DESC) WHERE ("trade_archived_at" IS NULL);



CREATE INDEX "conversations_trade_id_idx" ON "public"."conversations" USING "btree" ("trade_id");



CREATE INDEX "conversations_trade_pinned_idx" ON "public"."conversations" USING "btree" ("trade_id", "trade_pinned_at" DESC) WHERE ("trade_pinned_at" IS NOT NULL);



CREATE UNIQUE INDEX "conversations_uniq_no_job" ON "public"."conversations" USING "btree" ("builder_id", "trade_id") WHERE ("job_id" IS NULL);



CREATE UNIQUE INDEX "conversations_uniq_with_job" ON "public"."conversations" USING "btree" ("job_id", "builder_id", "trade_id") WHERE ("job_id" IS NOT NULL);



CREATE INDEX "hidden_jobs_user_id_idx" ON "public"."hidden_jobs" USING "btree" ("user_id");



CREATE INDEX "idx_bookings_job_id" ON "public"."bookings" USING "btree" ("job_id");



CREATE INDEX "idx_builder_profiles_active" ON "public"."builder_profiles" USING "btree" ("id") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_builder_profiles_service_latlng" ON "public"."builder_profiles" USING "btree" ("service_latitude", "service_longitude");



CREATE INDEX "idx_conversations_job_id" ON "public"."conversations" USING "btree" ("job_id");



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



CREATE INDEX "jobs_apprentice_invitation_feed_idx" ON "public"."jobs" USING "btree" ("published_at" DESC) WHERE ("open_to_apprentices" AND ("deleted_at" IS NULL));



CREATE INDEX "jobs_apprenticeship_feed_idx" ON "public"."jobs" USING "btree" ("published_at" DESC) WHERE (("job_kind" = 'apprenticeship'::"text") AND ("deleted_at" IS NULL));



CREATE INDEX "jobs_builder_id_idx" ON "public"."jobs" USING "btree" ("builder_id");



CREATE INDEX "jobs_feed_published_idx" ON "public"."jobs" USING "btree" ("published_at" DESC) WHERE (("deleted_at" IS NULL) AND ("status" = ANY (ARRAY['open'::"public"."job_status", 'filled'::"public"."job_status"])));



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



CREATE INDEX "reports_conversation_id_idx" ON "public"."reports" USING "btree" ("conversation_id");



CREATE UNIQUE INDEX "reports_one_pending_per_conversation" ON "public"."reports" USING "btree" ("reporter_id", "conversation_id") WHERE ("status" = 'pending'::"text");



CREATE INDEX "reports_reported_id_idx" ON "public"."reports" USING "btree" ("reported_id");



CREATE INDEX "reports_reporter_id_idx" ON "public"."reports" USING "btree" ("reporter_id");



CREATE INDEX "reports_status_created_idx" ON "public"."reports" USING "btree" ("status", "created_at" DESC);



CREATE INDEX "reviews_reviewee_id_idx" ON "public"."reviews" USING "btree" ("reviewee_id");



CREATE INDEX "saved_jobs_user_id_created_at_idx" ON "public"."saved_jobs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "timesheets_job_idx" ON "public"."timesheets" USING "btree" ("job_id");



CREATE UNIQUE INDEX "timesheets_one_active_job_trade" ON "public"."timesheets" USING "btree" ("job_id", "trade_id") WHERE ("check_out_at" IS NULL);



CREATE INDEX "timesheets_trade_idx" ON "public"."timesheets" USING "btree" ("trade_id");



CREATE INDEX "trade_profiles_average_rating_idx" ON "public"."trade_profiles" USING "btree" ("average_rating");



CREATE INDEX "trade_profiles_is_apprentice_idx" ON "public"."trade_profiles" USING "btree" ("is_apprentice") WHERE ("deleted_at" IS NULL);



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



CREATE OR REPLACE TRIGGER "application_lifecycle_guard" BEFORE INSERT OR UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."guard_application_lifecycle"();



CREATE OR REPLACE TRIGGER "applications_protect_quote" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."applications_protect_quote"();



CREATE OR REPLACE TRIGGER "applications_updated_at" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "bookings_touch_updated_at_trg" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."bookings_touch_updated_at"();



CREATE OR REPLACE TRIGGER "builder_profiles_pin_verified_abn_trg" BEFORE UPDATE ON "public"."builder_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."builder_profiles_pin_verified_abn"();



CREATE OR REPLACE TRIGGER "builder_profiles_updated_at" BEFORE UPDATE ON "public"."builder_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "company_profile_owner_guard" BEFORE DELETE OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."admin_company_guard_owner"();



CREATE OR REPLACE TRIGGER "company_role_owner_guard" BEFORE DELETE OR UPDATE ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."admin_company_guard_owner"();



CREATE OR REPLACE TRIGGER "company_staff_owner_guard" BEFORE DELETE OR UPDATE ON "public"."admin_staff" FOR EACH ROW EXECUTE FUNCTION "public"."admin_company_guard_owner"();



CREATE OR REPLACE TRIGGER "conversation_creation_guard" BEFORE INSERT ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."guard_conversation_creation"();



CREATE OR REPLACE TRIGGER "jobs_updated_at" BEFORE UPDATE ON "public"."jobs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "messages_update_last_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_conversation_last_message"();



CREATE OR REPLACE TRIGGER "notifications_push_fanout_trg" AFTER INSERT ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."notifications_push_fanout"();



CREATE OR REPLACE TRIGGER "notify_builder_on_new_application_trg" AFTER INSERT ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."notify_builder_on_new_application"();



CREATE OR REPLACE TRIGGER "notify_builder_on_quote_response_trg" AFTER UPDATE OF "status" ON "public"."quote_requests" FOR EACH ROW WHEN ((("old"."status" IS DISTINCT FROM "new"."status") AND ("new"."status" = ANY (ARRAY['quoted'::"public"."quote_request_status", 'declined'::"public"."quote_request_status"])))) EXECUTE FUNCTION "public"."notify_builder_on_quote_response"();



CREATE OR REPLACE TRIGGER "notify_on_new_message_trg" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_new_message"();



CREATE OR REPLACE TRIGGER "notify_on_new_review_trg" AFTER INSERT ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_new_review"();



CREATE OR REPLACE TRIGGER "notify_trade_on_application_status_trg" AFTER UPDATE OF "status" ON "public"."applications" FOR EACH ROW WHEN ((("old"."status" IS DISTINCT FROM "new"."status") AND ("new"."status" = ANY (ARRAY['shortlisted'::"public"."application_status", 'hired'::"public"."application_status", 'rejected'::"public"."application_status"])))) EXECUTE FUNCTION "public"."notify_trade_on_application_status"();



CREATE OR REPLACE TRIGGER "notify_trade_on_quote_request_trg" AFTER INSERT ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."notify_trade_on_quote_request"();



CREATE OR REPLACE TRIGGER "notify_trades_on_new_job_trg" AFTER INSERT ON "public"."jobs" FOR EACH ROW EXECUTE FUNCTION "public"."notify_trades_on_new_job"();



CREATE OR REPLACE TRIGGER "profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "quote_requests_touch_updated_at_trg" BEFORE UPDATE ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."quote_requests_touch_updated_at"();



CREATE OR REPLACE TRIGGER "reviews_sync_trade_rating_trg" AFTER INSERT OR DELETE OR UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."reviews_sync_trade_rating"();



CREATE OR REPLACE TRIGGER "timesheet_lifecycle_guard" BEFORE INSERT OR UPDATE ON "public"."timesheets" FOR EACH ROW EXECUTE FUNCTION "public"."guard_timesheet_lifecycle"();



CREATE OR REPLACE TRIGGER "trade_profiles_updated_at" BEFORE UPDATE ON "public"."trade_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_forbid_role_mutation" BEFORE UPDATE ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_role_mutation"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_applications" BEFORE UPDATE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_bookings" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_conversations" BEFORE UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_messages" BEFORE UPDATE ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_quote_requests" BEFORE UPDATE ON "public"."quote_requests" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_lock_identity_timesheets" BEFORE UPDATE ON "public"."timesheets" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_identity_col_change"();



CREATE OR REPLACE TRIGGER "trg_log_role_event" AFTER INSERT OR UPDATE OF "role" ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."log_role_event"();



CREATE OR REPLACE TRIGGER "trg_sync_job_application_count" AFTER INSERT OR DELETE ON "public"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."sync_job_application_count"();



CREATE OR REPLACE TRIGGER "user_roles_forbid_self_admin" BEFORE INSERT ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "public"."forbid_self_admin"();



CREATE OR REPLACE TRIGGER "verification_documents_invalidate_removed_evidence" AFTER DELETE OR UPDATE OF "deleted_at" ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."invalidate_removed_verification_evidence"();



CREATE OR REPLACE TRIGGER "verification_documents_stamp_submission" BEFORE INSERT ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."stamp_verification_submission"();



CREATE OR REPLACE TRIGGER "verification_documents_updated_at" BEFORE UPDATE ON "public"."verification_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "verifications_sync_trade_is_verified" AFTER INSERT OR DELETE OR UPDATE ON "public"."verifications" FOR EACH ROW EXECUTE FUNCTION "public"."sync_trade_is_verified"();



CREATE OR REPLACE TRIGGER "verifications_updated_at" BEFORE UPDATE ON "public"."verifications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."admin_actions"
    ADD CONSTRAINT "admin_actions_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."admin_staff"
    ADD CONSTRAINT "admin_staff_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."admin_support_cases"
    ADD CONSTRAINT "admin_support_cases_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "public"."admin_staff"("user_id");



ALTER TABLE ONLY "public"."admin_support_cases"
    ADD CONSTRAINT "admin_support_cases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."admin_support_notes"
    ADD CONSTRAINT "admin_support_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."admin_support_notes"
    ADD CONSTRAINT "admin_support_notes_case_id_fkey" FOREIGN KEY ("case_id") REFERENCES "public"."admin_support_cases"("id");



ALTER TABLE ONLY "public"."admin_verification_assignments"
    ADD CONSTRAINT "admin_verification_assignments_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "public"."admin_staff"("user_id");



ALTER TABLE ONLY "public"."admin_verification_assignments"
    ADD CONSTRAINT "admin_verification_assignments_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."verification_documents"("id");



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_builder_id_fkey" FOREIGN KEY ("builder_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "public"."jobs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applications"
    ADD CONSTRAINT "applications_trade_id_fkey" FOREIGN KEY ("trade_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reported_id_fkey" FOREIGN KEY ("reported_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



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



CREATE POLICY "Admins read all acceptances" ON "public"."legal_acceptances" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "Users insert own acceptances" ON "public"."legal_acceptances" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users read own acceptances" ON "public"."legal_acceptances" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."admin_actions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_actions_admin_read" ON "public"."admin_actions" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('audit.read'::"text") AS "admin_company_has_permission"));



ALTER TABLE "public"."admin_platform_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_staff" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_support_cases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_support_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_verification_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."applications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "applications_admin_read" ON "public"."applications" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "applications_insert_trade" ON "public"."applications" FOR INSERT WITH CHECK (("auth"."uid"() = "trade_id"));



CREATE POLICY "applications_select" ON "public"."applications" FOR SELECT USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



CREATE POLICY "applications_update" ON "public"."applications" FOR UPDATE USING ((("auth"."uid"() = "trade_id") OR ("auth"."uid"() = "builder_id")));



ALTER TABLE "public"."blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "blocks_delete_own" ON "public"."blocks" FOR DELETE USING (("auth"."uid"() = "blocker_id"));



CREATE POLICY "blocks_insert_own" ON "public"."blocks" FOR INSERT WITH CHECK (("auth"."uid"() = "blocker_id"));



CREATE POLICY "blocks_select_own" ON "public"."blocks" FOR SELECT USING (("auth"."uid"() = "blocker_id"));



ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bookings_builder_all" ON "public"."bookings" TO "authenticated" USING (("builder_id" = "auth"."uid"())) WITH CHECK ((("builder_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."jobs" "j"
  WHERE (("j"."id" = "bookings"."job_id") AND ("j"."builder_id" = "auth"."uid"()))))));



CREATE POLICY "bookings_trade_select" ON "public"."bookings" FOR SELECT TO "authenticated" USING (("trade_id" = "auth"."uid"()));



CREATE POLICY "bookings_trade_update" ON "public"."bookings" FOR UPDATE TO "authenticated" USING (("trade_id" = "auth"."uid"())) WITH CHECK (("trade_id" = "auth"."uid"()));



CREATE POLICY "buak_admin_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "buak_owner_insert" ON "public"."builder_unverified_acknowledgements" FOR INSERT WITH CHECK (("auth"."uid"() = "builder_id"));



CREATE POLICY "buak_owner_read" ON "public"."builder_unverified_acknowledgements" FOR SELECT USING (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."builder_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "builder_profiles_admin_read" ON "public"."builder_profiles" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "builder_profiles_insert_own" ON "public"."builder_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "builder_profiles_select_related" ON "public"."builder_profiles" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "id") OR (EXISTS ( SELECT 1
   FROM "public"."applications" "a"
  WHERE (("a"."builder_id" = "builder_profiles"."id") AND ("a"."trade_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."builder_id" = "builder_profiles"."id") AND ("c"."trade_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."bookings" "b"
  WHERE (("b"."builder_id" = "builder_profiles"."id") AND ("b"."trade_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."quote_requests" "q"
  WHERE (("q"."builder_id" = "builder_profiles"."id") AND ("q"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "builder_profiles_update_own" ON "public"."builder_profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."builder_unverified_acknowledgements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "company_scoped_read" ON "public"."admin_platform_settings" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('platform.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."admin_staff" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('staff.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."admin_support_cases" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('support.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."admin_support_notes" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('support.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."admin_verification_assignments" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."applications" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."contact_enquiries" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('support.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."quote_requests" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."reports" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('support.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."reviews" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "company_scoped_read" ON "public"."timesheets" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



ALTER TABLE "public"."contact_enquiries" ENABLE ROW LEVEL SECURITY;


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


CREATE POLICY "jobs_admin_read" ON "public"."jobs" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('marketplace.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "jobs_delete_own" ON "public"."jobs" FOR DELETE USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_insert_own" ON "public"."jobs" FOR INSERT WITH CHECK ((("auth"."uid"() = "builder_id") AND "public"."is_builder_abn_verified"("auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."user_roles"
  WHERE (("user_roles"."user_id" = "auth"."uid"()) AND ("user_roles"."role" = 'builder'::"text"))))));



CREATE POLICY "jobs_select_open" ON "public"."jobs" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ("status" = ANY (ARRAY['open'::"public"."job_status", 'filled'::"public"."job_status"])) AND ("deleted_at" IS NULL)));



CREATE POLICY "jobs_select_own" ON "public"."jobs" FOR SELECT USING (("auth"."uid"() = "builder_id"));



CREATE POLICY "jobs_update_own" ON "public"."jobs" FOR UPDATE USING (("auth"."uid"() = "builder_id")) WITH CHECK (("auth"."uid"() = "builder_id"));



ALTER TABLE "public"."legal_acceptances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."manual_verification_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."message_reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_insert" ON "public"."messages" FOR INSERT WITH CHECK ((("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"())) AND ("c"."status" <> 'blocked'::"public"."conversation_status")))) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks" "b"
  WHERE (("b"."blocked_id" = "auth"."uid"()) AND ("b"."blocker_id" IN ( SELECT
                CASE
                    WHEN ("c2"."builder_id" = "auth"."uid"()) THEN "c2"."trade_id"
                    ELSE "c2"."builder_id"
                END AS "builder_id"
           FROM "public"."conversations" "c2"
          WHERE ("c2"."id" = "messages"."conversation_id")))))))));



CREATE POLICY "messages_modify_own" ON "public"."messages" FOR UPDATE USING (("sender_id" = "auth"."uid"())) WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "messages_select" ON "public"."messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "messages"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"()))))));



CREATE POLICY "mvr_admin_read" ON "public"."manual_verification_requests" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "mvr_no_client_insert" ON "public"."manual_verification_requests" FOR INSERT WITH CHECK (false);



CREATE POLICY "mvr_owner_read" ON "public"."manual_verification_requests" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notification_preferences_owner" ON "public"."notification_preferences" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_admin_read" ON "public"."profiles" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



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


ALTER TABLE "public"."reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reports_insert_own" ON "public"."reports" FOR INSERT WITH CHECK ((("auth"."uid"() = "reporter_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."id" = "reports"."conversation_id") AND (("c"."builder_id" = "auth"."uid"()) OR ("c"."trade_id" = "auth"."uid"())))))));



CREATE POLICY "reports_select_own" ON "public"."reports" FOR SELECT USING (("auth"."uid"() = "reporter_id"));



ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reviews_insert_reviewer" ON "public"."reviews" FOR INSERT WITH CHECK (("auth"."uid"() = "reviewer_id"));



CREATE POLICY "reviews_select_authenticated" ON "public"."reviews" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "role_events_admin_read" ON "public"."user_role_events" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "role_events_select_own" ON "public"."user_role_events" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."saved_jobs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "saved_jobs_delete_own" ON "public"."saved_jobs" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "saved_jobs_insert_own" ON "public"."saved_jobs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "saved_jobs_select_own" ON "public"."saved_jobs" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."site_tickets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "site_tickets_select_all" ON "public"."site_tickets" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."timesheets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "timesheets_builder_select" ON "public"."timesheets" FOR SELECT TO "authenticated" USING (("builder_id" = "auth"."uid"()));



CREATE POLICY "timesheets_trade_insert" ON "public"."timesheets" FOR INSERT TO "authenticated" WITH CHECK (("trade_id" = "auth"."uid"()));



CREATE POLICY "timesheets_trade_select" ON "public"."timesheets" FOR SELECT TO "authenticated" USING (("trade_id" = "auth"."uid"()));



CREATE POLICY "timesheets_trade_update" ON "public"."timesheets" FOR UPDATE TO "authenticated" USING (("trade_id" = "auth"."uid"())) WITH CHECK (("trade_id" = "auth"."uid"()));



ALTER TABLE "public"."trade_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_categories_select_all" ON "public"."trade_categories" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."trade_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "trade_profiles_admin_read" ON "public"."trade_profiles" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "trade_profiles_insert_own" ON "public"."trade_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "trade_profiles_select_related" ON "public"."trade_profiles" FOR SELECT TO "authenticated" USING ((("auth"."uid"() = "id") OR (EXISTS ( SELECT 1
   FROM "public"."applications" "a"
  WHERE (("a"."trade_id" = "trade_profiles"."id") AND ("a"."builder_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."conversations" "c"
  WHERE (("c"."trade_id" = "trade_profiles"."id") AND ("c"."builder_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."bookings" "b"
  WHERE (("b"."trade_id" = "trade_profiles"."id") AND ("b"."builder_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."quote_requests" "q"
  WHERE (("q"."trade_id" = "trade_profiles"."id") AND ("q"."builder_id" = "auth"."uid"()))))));



CREATE POLICY "trade_profiles_update_own" ON "public"."trade_profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."user_role_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_roles_admin_read" ON "public"."user_roles" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('users.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "user_roles_insert_own" ON "public"."user_roles" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND ("role" = ANY (ARRAY['builder'::"text", 'trade'::"text"]))));



CREATE POLICY "user_roles_select_own" ON "public"."user_roles" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."verification_documents" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_documents_admin_select" ON "public"."verification_documents" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "verification_documents_insert_own" ON "public"."verification_documents" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "trade_id") AND ("status" = 'pending'::"public"."document_status") AND ("reviewed_by" IS NULL) AND ("reviewed_at" IS NULL) AND ("review_notes" IS NULL) AND ("rejection_reason" IS NULL) AND ("deleted_at" IS NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_roles" "r"
  WHERE (("r"."user_id" = "auth"."uid"()) AND ("r"."role" = ANY (ARRAY['builder'::"text", 'trade'::"text"])) AND (("verification_documents"."doc_type" IS DISTINCT FROM 'abn_certificate'::"public"."document_doc_type") OR ("r"."role" = 'builder'::"text")) AND (("verification_documents"."doc_type" IS DISTINCT FROM 'trade_licence'::"public"."document_doc_type") OR ("r"."role" = 'trade'::"text")))))));



CREATE POLICY "verification_documents_select_own" ON "public"."verification_documents" FOR SELECT USING (("auth"."uid"() = "trade_id"));



CREATE POLICY "verification_documents_update_own" ON "public"."verification_documents" FOR UPDATE USING (("auth"."uid"() = "trade_id")) WITH CHECK (("auth"."uid"() = "trade_id"));



ALTER TABLE "public"."verification_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_events_admin_read" ON "public"."verification_events" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "verification_events_no_client_insert" ON "public"."verification_events" FOR INSERT WITH CHECK (false);



CREATE POLICY "verification_events_owner_read" ON "public"."verification_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."verifications" "v"
  WHERE (("v"."id" = "verification_events"."verification_id") AND ("v"."user_id" = "auth"."uid"())))));



CREATE POLICY "verification_funnel_admin_read" ON "public"."verification_funnel_events" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



ALTER TABLE "public"."verification_funnel_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verification_funnel_insert_own" ON "public"."verification_funnel_events" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("user_id" IS NULL)));



ALTER TABLE "public"."verification_rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."verifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "verifications_admin_read" ON "public"."verifications" FOR SELECT TO "authenticated" USING (( SELECT "public"."admin_company_has_permission"('verification.read'::"text") AS "admin_company_has_permission"));



CREATE POLICY "verifications_no_client_delete" ON "public"."verifications" FOR DELETE USING (false);



CREATE POLICY "verifications_no_client_insert" ON "public"."verifications" FOR INSERT WITH CHECK (false);



CREATE POLICY "verifications_no_client_update" ON "public"."verifications" FOR UPDATE USING (false);



CREATE POLICY "verifications_owner_read" ON "public"."verifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."admin_actor_is_active"("p_actor_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_actor_is_active"("p_actor_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_broadcast"("p_title" "text", "p_body" "text", "p_audience" "text", "p_data" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_broadcast_to_user"("p_title" "text", "p_body" "text", "p_user_id" "uuid", "p_data" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_broadcast_to_user"("p_title" "text", "p_body" "text", "p_user_id" "uuid", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_broadcast_to_user"("p_title" "text", "p_body" "text", "p_user_id" "uuid", "p_data" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_company_actor_role"("p_actor_id" "uuid") FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."admin_company_assert_owner"("p_actor_id" "uuid", "p_aal" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_assert_owner"("p_actor_id" "uuid", "p_aal" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_company_guard_owner"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."admin_company_has_permission"("p_permission" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_has_permission"("p_permission" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_list"("p_resource" "text", "p_page" integer, "p_user_id" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_list"("p_resource" "text", "p_page" integer, "p_user_id" "uuid", "p_status" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_mutate"("p_resource" "text", "p_id" "uuid", "p_payload" "jsonb", "p_expected_version" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_mutate"("p_resource" "text", "p_id" "uuid", "p_payload" "jsonb", "p_expected_version" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_overview"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_overview"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_public_config"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_public_config"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_company_public_config"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_require"("p_permission" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."admin_company_search_users"("p_q" "text", "p_search_by" "text", "p_role" "text", "p_status" "text", "p_page" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_search_users"("p_q" "text", "p_search_by" "text", "p_role" "text", "p_status" "text", "p_page" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_company_session"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_company_session"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_require_active"("p_actor_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_require_active"("p_actor_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_job_status"("p_job_id" "uuid", "p_status" "text", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_user_role"("p_actor_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_expected_role" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_user_role"("p_actor_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_expected_role" "text", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_set_user_status"("p_user_id" "uuid", "p_status" "text", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_user_invitation_preflight"("p_actor_id" "uuid", "p_email" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_user_invitation_preflight"("p_actor_id" "uuid", "p_email" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_user_management_is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_user_management_is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_user_management_is_admin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_user_management_rate_limit"("p_actor_id" "uuid", "p_ip" "text", "p_action" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_user_management_rate_limit"("p_actor_id" "uuid", "p_ip" "text", "p_action" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_user_management_ready"("p_actor_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_user_management_ready"("p_actor_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_view_verification_raw"("p_verification_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."append_portfolio_url"("user_id" "uuid", "new_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "anon";
GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."applications_protect_quote"() TO "service_role";



GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."bookings_touch_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."builder_profiles_pin_verified_abn"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."builder_profiles_pin_verified_abn"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token"("event" "jsonb") TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."delete_my_account"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_my_account"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."expire_stale_verifications"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."expire_stale_verifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."forbid_identity_col_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_identity_col_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_identity_col_change"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."forbid_role_mutation"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."forbid_role_mutation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."forbid_self_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_builder_public_verification"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_inbox"("p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_conversation"("p_builder" "uuid", "p_trade" "uuid", "p_job" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_trade_public_credentials"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."guard_application_lifecycle"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guard_application_lifecycle"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_application_lifecycle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_application_lifecycle"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."guard_conversation_creation"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guard_conversation_creation"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."guard_timesheet_lifecycle"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guard_timesheet_lifecycle"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."invalidate_deleted_verification_file"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invalidate_deleted_verification_file"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."invalidate_removed_verification_evidence"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invalidate_removed_verification_evidence"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_builder_abn_verified"("p_uid" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_admin_action"("p_action" "text", "p_target_table" "text", "p_target_id" "uuid", "p_metadata" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."log_role_event"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_role_event"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."notification_category"("p_type" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."notifications_push_fanout"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notifications_push_fanout"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_builder_on_new_application"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_builder_on_new_application"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_builder_on_quote_response"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_builder_on_quote_response"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_expiring_verifications"("p_days" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_on_new_message"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_on_new_review"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_on_new_review"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_trade_on_application_status"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_trade_on_application_status"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_trade_on_quote_request"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_trade_on_quote_request"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify_trades_on_new_job"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify_trades_on_new_job"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_requests_touch_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."recompute_builder_rating"("p_builder_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."recompute_trade_rating"("p_trade_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_portfolio_url"("user_id" "uuid", "target_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."review_verification_document"("p_document_id" "uuid", "p_status" "text", "p_notes" "text", "p_confirmed_number" "text", "p_trade_class" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."reviews_sync_trade_rating"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."reviews_sync_trade_rating"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."revoke_verification"("p_user_id" "uuid", "p_kind" "text", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer, "p_apprentice" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer, "p_apprentice" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_trades"("p_lat" double precision, "p_lng" double precision, "p_radius_km" integer, "p_min_rating" numeric, "p_available_only" boolean, "p_query" "text", "p_limit" integer, "p_offset" integer, "p_apprentice" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."stamp_verification_submission"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stamp_verification_submission"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_job_application_count"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_job_application_count"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_phone_verified_at"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "service_role";
GRANT ALL ON FUNCTION "public"."sync_phone_verified_at"() TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."sync_trade_is_verified"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_trade_is_verified"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_conversation_last_message"() TO "service_role";



GRANT ALL ON TABLE "public"."admin_actions" TO "anon";
GRANT ALL ON TABLE "public"."admin_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_actions" TO "service_role";



GRANT ALL ON TABLE "public"."admin_platform_settings" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_platform_settings" TO "authenticated";



GRANT ALL ON TABLE "public"."admin_staff" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_staff" TO "authenticated";



GRANT ALL ON TABLE "public"."admin_support_cases" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_support_cases" TO "authenticated";



GRANT ALL ON TABLE "public"."admin_support_notes" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_support_notes" TO "authenticated";



GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."admin_user_directory" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_user_directory" TO "authenticated";



GRANT ALL ON TABLE "public"."admin_verification_assignments" TO "service_role";
GRANT SELECT ON TABLE "public"."admin_verification_assignments" TO "authenticated";



GRANT ALL ON TABLE "public"."applications" TO "anon";
GRANT ALL ON TABLE "public"."applications" TO "authenticated";
GRANT ALL ON TABLE "public"."applications" TO "service_role";



GRANT ALL ON TABLE "public"."jobs" TO "anon";
GRANT ALL ON TABLE "public"."jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."jobs" TO "service_role";



GRANT SELECT ON TABLE "public"."application_job_summaries" TO "authenticated";



GRANT ALL ON TABLE "public"."blocks" TO "anon";
GRANT ALL ON TABLE "public"."blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."blocks" TO "service_role";



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



GRANT ALL ON TABLE "public"."builder_profiles_public" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_profiles_public" TO "service_role";



GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "anon";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "authenticated";
GRANT ALL ON TABLE "public"."builder_unverified_acknowledgements" TO "service_role";



GRANT ALL ON TABLE "public"."contact_enquiries" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."hidden_jobs" TO "anon";
GRANT ALL ON TABLE "public"."hidden_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."hidden_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."jobs_public_browse" TO "anon";
GRANT ALL ON TABLE "public"."jobs_public_browse" TO "authenticated";
GRANT ALL ON TABLE "public"."jobs_public_browse" TO "service_role";



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



GRANT ALL ON TABLE "public"."reports" TO "anon";
GRANT ALL ON TABLE "public"."reports" TO "authenticated";
GRANT ALL ON TABLE "public"."reports" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."saved_jobs" TO "anon";
GRANT ALL ON TABLE "public"."saved_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."saved_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."site_tickets" TO "anon";
GRANT ALL ON TABLE "public"."site_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."site_tickets" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."timesheets" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,MAINTAIN,UPDATE ON TABLE "public"."timesheets" TO "authenticated";
GRANT ALL ON TABLE "public"."timesheets" TO "service_role";



GRANT ALL ON TABLE "public"."trade_categories" TO "anon";
GRANT ALL ON TABLE "public"."trade_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_categories" TO "service_role";



GRANT ALL ON TABLE "public"."verifications" TO "anon";
GRANT ALL ON TABLE "public"."verifications" TO "authenticated";
GRANT ALL ON TABLE "public"."verifications" TO "service_role";



GRANT ALL ON TABLE "public"."trade_profiles_public" TO "authenticated";
GRANT ALL ON TABLE "public"."trade_profiles_public" TO "service_role";



GRANT ALL ON TABLE "public"."user_role_events" TO "service_role";
GRANT SELECT ON TABLE "public"."user_role_events" TO "authenticated";



GRANT ALL ON TABLE "public"."verification_documents" TO "service_role";
GRANT SELECT,INSERT ON TABLE "public"."verification_documents" TO "authenticated";



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







