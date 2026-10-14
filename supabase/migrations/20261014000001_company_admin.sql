-- Company staff scopes. No marketplace identity is inferred from staff role.
-- Apply with the matching Edge release before enabling admin_mfa_required.
BEGIN;
CREATE SCHEMA company_admin_private;
REVOKE ALL ON SCHEMA company_admin_private FROM PUBLIC, anon, authenticated, service_role;
CREATE TABLE company_admin_private.original_functions(signature text PRIMARY KEY, definition text NOT NULL, name text NOT NULL);
INSERT INTO company_admin_private.original_functions
SELECT oid::regprocedure::text, pg_get_functiondef(oid), proname FROM pg_proc
WHERE pronamespace='public'::regnamespace AND proname IN
('admin_set_user_status','admin_actor_is_active','admin_require_active','admin_user_management_is_admin','admin_user_management_ready',
 'admin_broadcast','admin_broadcast_to_user','admin_set_job_status','admin_view_verification_raw',
 'review_verification_document','revoke_verification','log_admin_action');
CREATE TABLE company_admin_private.original_policies AS
SELECT n.nspname AS schema_name,c.relname AS table_name,p.polname AS policy_name,
 pg_get_expr(p.polqual,p.polrelid) AS expression,
 array_to_string(ARRAY(SELECT CASE WHEN x=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(x)) END FROM unnest(p.polroles) x),',') AS roles
FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','storage') AND
(coalesce(pg_get_expr(p.polqual,p.polrelid),'') LIKE '%admin_user_management_is_admin%'
 OR (n.nspname='storage' AND p.polname LIKE '%admin%'));
CREATE TABLE company_admin_private.original_view AS SELECT pg_get_viewdef('public.admin_user_directory'::regclass,true) AS definition;

CREATE TABLE public.admin_staff (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid UNIQUE NOT NULL REFERENCES public.profiles(id),
 staff_role text NOT NULL CHECK(staff_role IN ('owner','operations','verification','support','read_only')),
 active boolean NOT NULL DEFAULT true, version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.admin_staff(user_id,staff_role)
 SELECT r.user_id,'owner' FROM public.user_roles r JOIN public.profiles p ON p.id=r.user_id
 WHERE r.role='admin' AND p.user_status='active';
CREATE TABLE public.admin_support_cases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES public.profiles(id),
 subject text NOT NULL CHECK(length(btrim(subject)) BETWEEN 1 AND 200),
 priority text NOT NULL DEFAULT 'normal' CHECK(priority IN ('low','normal','high','urgent')),
 assignee_id uuid REFERENCES public.admin_staff(user_id),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','in_progress','resolved','closed')),
 version integer NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_support_cases_user_idx ON public.admin_support_cases(user_id);
CREATE TABLE public.admin_support_notes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), case_id uuid NOT NULL REFERENCES public.admin_support_cases(id),
 author_id uuid NOT NULL REFERENCES public.profiles(id),
 body text NOT NULL CHECK(length(btrim(body)) BETWEEN 1 AND 5000), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_support_notes_case_idx ON public.admin_support_notes(case_id,created_at);
CREATE TABLE public.admin_platform_settings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), key text UNIQUE NOT NULL,
 value jsonb NOT NULL, version integer NOT NULL DEFAULT 1, updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(key IN ('maintenance_notice','minimum_android_version','minimum_ios_version','marketplace_enabled','registration_enabled','admin_mfa_required'))
);
INSERT INTO public.admin_platform_settings(key,value) VALUES
 ('maintenance_notice','""'),('minimum_android_version','"0.0.0"'),('minimum_ios_version','"0.0.0"'),
 ('marketplace_enabled','true'),('registration_enabled','true'),('admin_mfa_required','false');
CREATE TABLE public.admin_verification_assignments (
 id uuid PRIMARY KEY REFERENCES public.verification_documents(id), assignee_id uuid REFERENCES public.admin_staff(user_id),
 version integer NOT NULL DEFAULT 1, updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reports ADD COLUMN version integer NOT NULL DEFAULT 1;
ALTER TABLE public.site_tickets ADD COLUMN version integer NOT NULL DEFAULT 1;
ALTER TABLE public.trade_categories ADD COLUMN version integer NOT NULL DEFAULT 1;

CREATE FUNCTION public.admin_company_actor_role(p_actor_id uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT s.staff_role FROM public.admin_staff s JOIN public.user_roles r ON r.user_id=s.user_id
 JOIN public.profiles p ON p.id=s.user_id
 WHERE s.user_id=p_actor_id AND s.active AND r.role='admin' AND p.user_status='active'
$$;
CREATE FUNCTION public.admin_company_has_permission(p_permission text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
CREATE FUNCTION public.admin_company_require(p_permission text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 -- Serialize revocations with privileged writes. Current membership is re-read.
 PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles',0));
 IF NOT public.admin_company_has_permission(p_permission) THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501';
 END IF;
END $$;
CREATE FUNCTION public.admin_company_session() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_role text:=public.admin_company_actor_role(auth.uid()); v_mfa boolean;
BEGIN
 IF v_role IS NULL THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
 SELECT value='true'::jsonb INTO v_mfa FROM public.admin_platform_settings WHERE key='admin_mfa_required';
 RETURN jsonb_build_object('staffRole',v_role,'mfaRequired',coalesce(v_mfa,false));
END $$;
CREATE FUNCTION public.admin_company_assert_owner(p_actor_id uuid,p_aal text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' OR public.admin_company_actor_role(p_actor_id) IS DISTINCT FROM 'owner'
 OR (EXISTS(SELECT 1 FROM public.admin_platform_settings WHERE key='admin_mfa_required' AND value='true'::jsonb)
     AND p_aal IS DISTINCT FROM 'aal2') THEN
  RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501';
 END IF;
 RETURN true;
END $$;
-- Legacy unscoped helpers fail closed for non-owners. Individually scoped
-- entrypoints below use their own permissions and do not rely on JWT admin claims.
CREATE OR REPLACE FUNCTION public.admin_actor_is_active(p_actor_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_company_actor_role(p_actor_id)='owner'
$$;
CREATE OR REPLACE FUNCTION public.admin_require_active(p_actor_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
CREATE OR REPLACE FUNCTION public.admin_user_management_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.admin_company_has_permission('users.read')
$$;
-- Replace only the reviewed guard seam; preserve the full manual verification
-- lifecycle, evidence checks, notification behavior and atomic audit.
DO $$ DECLARE f record; permission text; definition text;
BEGIN
 FOR f IN SELECT o.signature,o.definition,o.name FROM company_admin_private.original_functions o WHERE o.signature LIKE '%(%' LOOP
  permission:=CASE f.name
   WHEN 'admin_broadcast' THEN 'communications.send' WHEN 'admin_broadcast_to_user' THEN 'communications.send'
   WHEN 'admin_set_job_status' THEN 'marketplace.manage'
   WHEN 'admin_view_verification_raw' THEN 'verification.read'
   WHEN 'review_verification_document' THEN 'verification.manage' WHEN 'revoke_verification' THEN 'verification.manage'
   WHEN 'log_admin_action' THEN 'session' ELSE NULL END;
  IF permission IS NOT NULL THEN
   definition:=replace(f.definition,'PERFORM public.admin_require_active(auth.uid());',
    format('PERFORM public.admin_company_require(%L);',permission));
   EXECUTE definition;
  END IF;
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_set_user_status(p_user_id uuid,p_status text,p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
-- Direct participant access is retained; only administrative expansion changes.
DO $$ DECLARE p record; permission text;
BEGIN
 FOR p IN SELECT * FROM company_admin_private.original_policies LOOP
  permission:=CASE p.table_name
   WHEN 'verification_documents' THEN 'verification.read' WHEN 'verifications' THEN 'verification.read'
   WHEN 'verification_events' THEN 'verification.read' WHEN 'verification_funnel_events' THEN 'verification.read'
   WHEN 'manual_verification_requests' THEN 'verification.read' WHEN 'builder_unverified_acknowledgements' THEN 'verification.read'
   WHEN 'objects' THEN 'verification.read' WHEN 'admin_actions' THEN 'audit.read'
   WHEN 'applications' THEN 'marketplace.read' WHEN 'jobs' THEN 'marketplace.read'
   ELSE 'users.read' END;
  EXECUTE format('ALTER POLICY %I ON %I.%I TO authenticated USING (%s)',p.policy_name,p.schema_name,p.table_name,
   CASE WHEN p.schema_name='storage' THEN format('bucket_id = ''private-docs'' AND (SELECT public.admin_company_has_permission(%L))',permission)
    ELSE format('(SELECT public.admin_company_has_permission(%L))',permission) END);
 END LOOP;
END $$;
CREATE OR REPLACE VIEW public.admin_user_directory WITH (security_invoker=true) AS
 SELECT p.id,p.display_name,p.avatar_url,p.created_at,p.user_status,p.phone,r.role
 FROM public.profiles p LEFT JOIN public.user_roles r ON r.user_id=p.id
 WHERE (SELECT public.admin_company_has_permission('users.read'));

CREATE FUNCTION public.admin_company_guard_owner() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
CREATE TRIGGER company_staff_owner_guard BEFORE UPDATE OR DELETE ON public.admin_staff FOR EACH ROW EXECUTE FUNCTION public.admin_company_guard_owner();
CREATE TRIGGER company_profile_owner_guard BEFORE UPDATE OR DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.admin_company_guard_owner();
CREATE TRIGGER company_role_owner_guard BEFORE UPDATE OR DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION public.admin_company_guard_owner();

DO $$ DECLARE t text; scope text;
BEGIN
 FOREACH t IN ARRAY ARRAY['admin_staff','admin_support_cases','admin_support_notes','admin_platform_settings','admin_verification_assignments'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
  scope:=CASE t WHEN 'admin_staff' THEN 'staff.read' WHEN 'admin_platform_settings' THEN 'platform.read'
   WHEN 'admin_verification_assignments' THEN 'verification.read' ELSE 'support.read' END;
  EXECUTE format('CREATE POLICY company_scoped_read ON public.%I FOR SELECT TO authenticated USING ((SELECT public.admin_company_has_permission(%L)))',t,scope);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
 END LOOP;
END $$;

-- Additional administrative reads. Existing participant policies remain intact.
DO $$ DECLARE entry text; BEGIN
 FOREACH entry IN ARRAY ARRAY[
  'applications:marketplace.read','quote_requests:marketplace.read','timesheets:marketplace.read',
  'reviews:marketplace.read','reports:support.read','contact_enquiries:support.read'] LOOP
  EXECUTE format('CREATE POLICY company_scoped_read ON public.%I FOR SELECT TO authenticated USING ((SELECT public.admin_company_has_permission(%L)))',
    split_part(entry,':',1),split_part(entry,':',2));
 END LOOP;
END $$;

-- The list function selects only fields explicitly used by the console.
CREATE FUNCTION public.admin_company_list(p_resource text,p_page integer DEFAULT 1,p_user_id uuid DEFAULT NULL,p_status text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;

CREATE FUNCTION public.admin_company_search_users(p_q text,p_search_by text,p_role text DEFAULT 'all',p_status text DEFAULT 'all',p_page integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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

CREATE FUNCTION public.admin_company_overview() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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

-- A public-facing configuration endpoint exposes only marketplace controls.
CREATE FUNCTION public.admin_company_public_config() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb) FROM public.admin_platform_settings
 WHERE key IN ('maintenance_notice','minimum_android_version','minimum_ios_version','marketplace_enabled','registration_enabled')
$$;

CREATE FUNCTION public.admin_company_mutate(p_resource text,p_id uuid,p_payload jsonb,p_expected_version integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;

-- Explicit grants only. Helper internals cannot be invoked through PostgREST.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT oid::regprocedure AS signature FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND proname LIKE 'admin_company_%' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_company_session() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_list(text,integer,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_search_users(text,text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_mutate(text,uuid,jsonb,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_public_config() TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_company_assert_owner(uuid,text) TO service_role;
COMMIT;
