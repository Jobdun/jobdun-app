-- Only loaded in the disposable, network-disabled container by the runner.
-- Replace push delivery with a transaction-local database sink; retain the
-- real notification trigger and exercise all notification-producing RPCs.
BEGIN;
CREATE TABLE public.admin_test_delivery_sink (notification_id uuid);
CREATE OR REPLACE FUNCTION public.notifications_push_fanout()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.admin_test_delivery_sink VALUES (NEW.id);
  RETURN NEW;
END;
$$;
SELECT set_config('request.jwt.claim.role', 'service_role', false);
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'admin1@example.invalid', '{}'),
  ('a0000000-0000-0000-0000-000000000002', 'admin2@example.invalid', '{}'),
  ('a0000000-0000-0000-0000-000000000003', 'suspended@example.invalid', '{}'),
  ('a0000000-0000-0000-0000-000000000004', 'banned@example.invalid', '{}'),
  ('b0000000-0000-0000-0000-000000000001', 'builder@example.invalid', '{}'),
  ('b0000000-0000-0000-0000-000000000002', 'trade@example.invalid', '{}');
INSERT INTO public.profiles(id, display_name) SELECT id, 'Synthetic local account' FROM auth.users;
INSERT INTO public.user_roles(user_id, role) SELECT id,
  CASE WHEN id::text LIKE 'a%' THEN 'admin'
       WHEN id::text LIKE '%0001' THEN 'builder' ELSE 'trade' END FROM auth.users;
UPDATE public.profiles SET user_status = 'suspended' WHERE id = 'a0000000-0000-0000-0000-000000000003';
UPDATE public.profiles SET user_status = 'banned' WHERE id = 'a0000000-0000-0000-0000-000000000004';
INSERT INTO public.builder_profiles(id) VALUES ('b0000000-0000-0000-0000-000000000001');
INSERT INTO public.trade_profiles(id) VALUES ('b0000000-0000-0000-0000-000000000002');
INSERT INTO public.jobs(id, builder_id, title, description, trade_type_required, suburb, state, postcode, status, budget_amount)
VALUES ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
  'Synthetic listing', 'Local testing only', 'Carpenter', 'Sydney', 'NSW', '2000', 'draft', 100);
INSERT INTO public.verification_documents(id, trade_id, doc_type, file_path, document_number)
VALUES ('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002',
  'white_card', 'b0000000-0000-0000-0000-000000000002/local.pdf', 'SYNTHETIC');
INSERT INTO public.verifications(id, user_id, kind, status)
VALUES ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'abn', 'verified');
INSERT INTO storage.objects(bucket_id, name) VALUES
  ('private-docs', 'b0000000-0000-0000-0000-000000000002/local.pdf'),
  ('other-private-bucket', 'not-a-verification.pdf');
COMMIT;
