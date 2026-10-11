-- October 11 admin audit repairs. Apply after 20261007000001.
-- No data backfill or notification is sent by this migration.
BEGIN;

-- Keep mobile name/avatar/onboarding writers working; moderation fields are
-- writable only by trusted definers/service_role. Table grants override column
-- grants, so revoke the table privilege first (including anon/PUBLIC).
REVOKE INSERT, UPDATE ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT INSERT (id, display_name, avatar_url, created_at, updated_at, phone, phone_verified_at)
  ON public.profiles TO authenticated;
GRANT UPDATE (id, display_name, avatar_url, created_at, updated_at, phone, phone_verified_at)
  ON public.profiles TO authenticated;
REVOKE INSERT (user_status, status_reason), UPDATE (user_status, status_reason)
  ON public.profiles FROM PUBLIC, anon, authenticated;

-- One current database predicate; never trust an old JWT user_role claim.
-- The argument-taking helper is internal, to avoid exposing role lookups.
CREATE OR REPLACE FUNCTION public.admin_actor_is_active(p_actor_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
    WHERE r.user_id = p_actor_id AND r.role = 'admin' AND p.user_status = 'active'
  );
$$;
REVOKE ALL ON FUNCTION public.admin_actor_is_active(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_user_management_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.admin_actor_is_active(auth.uid());
$$;
REVOKE ALL ON FUNCTION public.admin_user_management_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_user_management_is_admin() TO authenticated;

-- Share the October role-change lock across every privileged operation. Actor
-- rows stay locked until commit, so suspension/demotion cannot race a write.
-- Lock first, then check with a fresh statement snapshot. The helper is only
-- callable from trusted definer routines, never through authenticated RPC.
CREATE OR REPLACE FUNCTION public.admin_require_active(p_actor_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('admin-users:roles', 0));
  PERFORM 1 FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
    WHERE r.user_id = p_actor_id FOR UPDATE OF r, p;
  IF NOT public.admin_actor_is_active(p_actor_id) THEN
    RAISE EXCEPTION 'not_admin' USING ERRCODE = '42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_require_active(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_user_management_ready(p_actor_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' OR p_actor_id IS NULL THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_active(p_actor_id);
  RETURN true;
END;
$$;

-- Existing ordinary owner/public read policies remain in place. Only the
-- administrative expansion of access depends on active admin membership.
ALTER POLICY "profiles_admin_read" ON public.profiles
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "builder_profiles_admin_read" ON public.builder_profiles
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "trade_profiles_admin_read" ON public.trade_profiles
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "user_roles_admin_read" ON public.user_roles
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "jobs_admin_read" ON public.jobs
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "applications_admin_read" ON public.applications
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "Admins read all acceptances" ON public.legal_acceptances
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "buak_admin_read" ON public.builder_unverified_acknowledgements
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "mvr_admin_read" ON public.manual_verification_requests
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "admin_actions_admin_read" ON public.admin_actions
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "verification_documents_admin_select" ON public.verification_documents
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "verification_events_admin_read" ON public.verification_events
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "verification_funnel_admin_read" ON public.verification_funnel_events
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
ALTER POLICY "verifications_admin_read" ON public.verifications
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
-- Review decisions go through audited definers. The owner deleted_at grant and
-- policy remain; admin membership must not enable arbitrary soft-delete/restore.
DROP POLICY verification_documents_admin_update ON public.verification_documents;

-- Role history is append-only through log_role_event, including for admins.
-- RLS alone cannot stop TRUNCATE, so remove the direct table write grants too.
DROP POLICY role_events_admin_all ON public.user_role_events;
CREATE POLICY role_events_admin_read ON public.user_role_events FOR SELECT
  TO authenticated USING ((SELECT public.admin_user_management_is_admin()));
REVOKE ALL ON public.user_role_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_role_events TO authenticated;
ALTER POLICY private_docs_admin_select ON storage.objects
  TO authenticated USING (bucket_id = 'private-docs' AND (SELECT public.admin_user_management_is_admin()));

-- Join/filter before PostgREST pagination; no giant client-side role-id IN list.
CREATE VIEW public.admin_user_directory WITH (security_invoker = true) AS
SELECT p.id, p.display_name, p.avatar_url, p.created_at, p.user_status, p.phone, r.role
FROM public.profiles p LEFT JOIN public.user_roles r ON r.user_id = p.id
WHERE (SELECT public.admin_user_management_is_admin());
REVOKE ALL ON public.admin_user_directory FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_user_directory TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_user_status(
  p_user_id uuid, p_status text, p_reason text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_old_status public.user_status;
  v_reason text := regexp_replace(p_reason, '^[[:space:]]+|[[:space:]]+$', '', 'g');
BEGIN
  PERFORM public.admin_require_active(auth.uid());
  IF p_user_id IS NULL OR p_status IS NULL OR p_status NOT IN ('active','suspended','banned')
    OR (p_reason IS NOT NULL AND char_length(v_reason) NOT BETWEEN 1 AND 500) THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;
  IF p_user_id = auth.uid() AND p_status <> 'active' THEN
    RAISE EXCEPTION 'self_status_change' USING ERRCODE = 'P0001';
  END IF;
  SELECT user_status INTO v_old_status FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001'; END IF;
  IF v_old_status = 'active' AND p_status <> 'active'
    AND EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'admin')
    AND (SELECT count(*) FROM public.user_roles r JOIN public.profiles p ON p.id = r.user_id
         WHERE r.role = 'admin' AND p.user_status = 'active') <= 1 THEN
    RAISE EXCEPTION 'last_active_admin' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.profiles SET user_status = p_status::public.user_status,
    status_reason = v_reason WHERE id = p_user_id;
  PERFORM public.log_admin_action('set_user_status', 'profiles', p_user_id,
    jsonb_build_object('status', p_status, 'old_status', v_old_status, 'reason', v_reason));
END;
$$;

-- Three arguments is the reviewed admin workflow. No default keeps PostgREST
-- overload resolution unambiguous for the two-argument legacy Flutter caller.
CREATE OR REPLACE FUNCTION public.admin_set_job_status(p_job_id uuid, p_status text, p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_old_status public.job_status;
  v_reason text := regexp_replace(p_reason, '^[[:space:]]+|[[:space:]]+$', '', 'g');
BEGIN
  PERFORM public.admin_require_active(auth.uid());
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
$$;

CREATE OR REPLACE FUNCTION public.admin_set_job_status(p_job_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Preserve legacy clients while marking the absent reviewer reason honestly.
  PERFORM public.admin_set_job_status(p_job_id, p_status, 'Legacy client: reason not supplied');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_broadcast(
  p_title text, p_body text, p_audience text, p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_title text := regexp_replace(p_title, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_body text := regexp_replace(p_body, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  v_user_id uuid;
  v_count integer;
BEGIN
  PERFORM public.admin_require_active(auth.uid());
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
$$;

-- Separate RPC preserves SINGLE USER intent at the SQL boundary; a group token
-- can never be interpreted as a recipient. The original RPC remains compatible.
CREATE OR REPLACE FUNCTION public.admin_broadcast_to_user(
  p_title text, p_body text, p_user_id uuid, p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM public.admin_require_active(auth.uid());
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023'; END IF;
  RETURN public.admin_broadcast(p_title, p_body, p_user_id::text, p_data);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action       text,
  p_target_table text DEFAULT NULL,
  p_target_id    uuid DEFAULT NULL,
  p_metadata     jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  PERFORM public.admin_require_active(auth.uid());

  INSERT INTO public.admin_actions (actor_id, action, target_table, target_id, metadata)
  VALUES (auth.uid(), p_action, p_target_table, p_target_id, COALESCE(p_metadata, '{}'::jsonb))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_view_verification_raw(p_verification_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_raw jsonb;
BEGIN
  PERFORM public.admin_require_active(auth.uid());

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

CREATE OR REPLACE FUNCTION public.review_verification_document(
  p_document_id      uuid,
  p_status           text,
  p_notes            text DEFAULT NULL,
  p_confirmed_number text DEFAULT NULL,
  p_trade_class      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_doc       public.verification_documents%ROWTYPE;
  v_kind      text;
  v_existing  uuid;
  v_doc_label text;
BEGIN
  PERFORM public.admin_require_active(auth.uid());

  IF p_status IS NULL OR p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'invalid_status: %', p_status;
  END IF;

  UPDATE public.verification_documents
     SET status       = p_status::public.document_status,
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

CREATE OR REPLACE FUNCTION public.revoke_verification(
  p_user_id uuid,
  p_kind    text,
  p_reason  text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  PERFORM public.admin_require_active(auth.uid());

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

CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_actor_id uuid, p_user_id uuid, p_role text, p_expected_role text, p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
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

-- Preserve October service-only grants; every client-facing RPC is authenticated
-- only. Explicit revokes avoid CREATE FUNCTION's default PUBLIC execute grant.
REVOKE ALL ON FUNCTION public.admin_user_management_ready(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_management_ready(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid,uuid,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid,uuid,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION public.admin_set_user_status(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_job_status(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_job_status(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_job_status(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_job_status(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_broadcast(text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_broadcast(text,text,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_broadcast_to_user(text,text,uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_to_user(text,text,uuid,jsonb) TO authenticated;
-- Only privileged action definers call this helper. Direct client execution
-- would fabricate an audit event without its corresponding state change.
REVOKE ALL ON FUNCTION public.log_admin_action(text,text,uuid,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_view_verification_raw(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_view_verification_raw(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.review_verification_document(uuid,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_verification_document(uuid,text,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.revoke_verification(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_verification(uuid,text,text) TO authenticated;

COMMIT;
