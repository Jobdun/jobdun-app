DO $$ DECLARE expected jsonb; actual jsonb; BEGIN
 SELECT fingerprint INTO expected FROM company_admin_test.baseline;
 SELECT jsonb_build_object(
 'functions',(SELECT coalesce(jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,
  'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text,'owner',p.proowner::text)
  ORDER BY p.oid::regprocedure::text),'[]'::jsonb) FROM pg_proc p
  WHERE p.pronamespace='public'::regnamespace AND p.proname IN
  ('admin_set_user_status','admin_actor_is_active','admin_require_active','admin_user_management_is_admin','admin_user_management_ready',
   'admin_broadcast','admin_broadcast_to_user','admin_set_job_status','admin_view_verification_raw',
   'review_verification_document','revoke_verification','log_admin_action')),
 'policies',(SELECT coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
  'name',p.polname,'roles',p.polroles::text,'command',p.polcmd,'permissive',p.polpermissive,
  'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid))
  ORDER BY n.nspname,c.relname,p.polname),'[]'::jsonb)
  FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('public','storage')),
 'view',(SELECT jsonb_build_object('definition',pg_get_viewdef('public.admin_user_directory'::regclass,true),
  'options',c.reloptions::text) FROM pg_class c WHERE c.oid='public.admin_user_directory'::regclass)) INTO actual;
 IF actual IS DISTINCT FROM expected THEN RAISE EXCEPTION 'rollback changed original definitions, grants, view, or policies'; END IF;
 IF to_regclass('public.admin_staff') IS NOT NULL OR to_regprocedure('public.admin_company_session()') IS NOT NULL
 OR EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name IN ('reports','site_tickets','trade_categories') AND column_name='version')
 THEN RAISE EXCEPTION 'rollback left company objects'; END IF;
END $$;
