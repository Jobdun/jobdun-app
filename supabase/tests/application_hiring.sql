-- LOCAL DATABASE ONLY: transactional synthetic fixtures, never send real notifications.
BEGIN;
SELECT set_config('request.jwt.claim.role', 'service_role', true);
INSERT INTO auth.users (id) VALUES
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000003');
INSERT INTO public.profiles(id) SELECT id FROM auth.users WHERE id::text LIKE '10000000-%';
INSERT INTO public.user_roles(user_id,role) VALUES
 ('10000000-0000-0000-0000-000000000001','builder'),
 ('10000000-0000-0000-0000-000000000002','trade'),
 ('10000000-0000-0000-0000-000000000003','trade');
INSERT INTO public.jobs(id,builder_id,title,description,trade_type_required,suburb,state,postcode,status,pricing_type,pricing_unit,budget_amount)
 VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
 'Test carpentry position','Local test position only','Carpenter','Sydney','NSW','2000','open','builder_set','hourly',25.75);
UPDATE public.jobs SET job_kind='apprenticeship', open_to_apprentices=true
 WHERE id='20000000-0000-0000-0000-000000000001';
DO $$ BEGIN
  BEGIN
    UPDATE public.jobs SET pricing_unit='per_job' WHERE id='20000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'FAIL: apprenticeship accepted contractor pricing';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.jobs SET open_to_apprentices=false WHERE id='20000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'FAIL: apprenticeship declined apprentices';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
INSERT INTO public.trade_profiles(id,full_name,primary_trade,is_apprentice,about,site_tickets,resume_path,portfolio_urls,base_suburb)
 VALUES ('10000000-0000-0000-0000-000000000002','Alex Test','Carpenter',true,
 'Learning carpentry',ARRAY['white_card'],'test/resume/cv.pdf',ARRAY['test/photo.jpg'],'Sydney');
INSERT INTO public.applications(id,job_id,builder_id,trade_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003');
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.jobs_public_browse
    WHERE job_kind='apprenticeship' AND open_to_apprentices AND budget_amount=25.75) THEN
    RAISE EXCEPTION 'FAIL: guest apprenticeship projection missing';
  END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF (SELECT completeness_pct FROM public.profile_completeness) IS DISTINCT FROM 100 THEN
    RAISE EXCEPTION 'FAIL: apprentice completeness requires qualified credentials';
  END IF;
END $$;
DO $$ BEGIN
  BEGIN
    UPDATE public.applications SET status='hired' WHERE id='30000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'FAIL: applicant could self-hire';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
UPDATE public.applications SET status='shortlisted' WHERE id='30000000-0000-0000-0000-000000000001';
UPDATE public.applications SET status='hired' WHERE id='30000000-0000-0000-0000-000000000001';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.jobs WHERE id='20000000-0000-0000-0000-000000000001'
     AND status='filled' AND hired_trade_id='10000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'FAIL: hire did not assign the job';
  END IF;
  BEGIN
    UPDATE public.applications SET status='hired' WHERE id='30000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'FAIL: second hire accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
ROLLBACK;
