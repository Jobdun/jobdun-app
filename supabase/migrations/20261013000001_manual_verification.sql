-- Manual document review is independent from Auth phone verification.
-- Apply after the October 11 admin safety and October 12 workflow guards.
BEGIN;

REVOKE INSERT (phone_verified_at), UPDATE (phone_verified_at)
 ON public.profiles FROM PUBLIC, anon, authenticated;
-- Table-level privileges override column grants. Retain the existing safe
-- owner profile fields and Auth/service-role SECURITY DEFINER writes.
REVOKE INSERT, UPDATE ON public.profiles FROM PUBLIC, anon, authenticated;

-- Only the review RPC may produce review metadata. Owners retain soft-delete.
REVOKE ALL ON public.verification_documents FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.verification_documents TO authenticated;
GRANT UPDATE (deleted_at) ON public.verification_documents TO authenticated;
ALTER POLICY verification_documents_insert_own ON public.verification_documents
 TO authenticated WITH CHECK (
  auth.uid() = trade_id AND status = 'pending'
  AND reviewed_by IS NULL AND reviewed_at IS NULL AND review_notes IS NULL
  AND rejection_reason IS NULL AND deleted_at IS NULL
  AND EXISTS (SELECT 1 FROM public.user_roles r WHERE r.user_id=auth.uid()
    AND r.role IN ('builder','trade')
    AND (doc_type IS DISTINCT FROM 'abn_certificate' OR r.role='builder')
    AND (doc_type IS DISTINCT FROM 'trade_licence' OR r.role='trade'))
 );

-- Client-supplied future timestamps must not let old evidence bypass the stale
-- review check. Authenticated uploads use the database receipt time.
CREATE FUNCTION public.stamp_verification_submission()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF auth.role() = 'authenticated' THEN
  NEW.created_at := clock_timestamp();
  NEW.submitted_at := NEW.created_at;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.stamp_verification_submission() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER verification_documents_stamp_submission BEFORE INSERT
 ON public.verification_documents FOR EACH ROW
 EXECUTE FUNCTION public.stamp_verification_submission();

-- The RPC writes exactly the same timestamp into receipt.reviewed_at and
-- credential.verified_at (the previous RPC did too). That pair links the
-- current manual decision to its evidence without invalidating a newer manual
-- decision or an independent regulator check when an old receipt is removed.
CREATE FUNCTION public.invalidate_removed_verification_evidence()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
REVOKE ALL ON FUNCTION public.invalidate_removed_verification_evidence() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER verification_documents_invalidate_removed_evidence AFTER UPDATE OF deleted_at OR DELETE
 ON public.verification_documents FOR EACH ROW
 EXECUTE FUNCTION public.invalidate_removed_verification_evidence();

-- Removing Storage bytes must invalidate the receipt as well as the current
-- manual credential. A rejected receipt cannot be resurrected by re-uploading
-- different bytes at the same path and restoring deleted_at. Preserve the
-- original reviewer notes/attribution; this is a system evidence removal.
CREATE FUNCTION public.invalidate_deleted_verification_file()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
REVOKE ALL ON FUNCTION public.invalidate_deleted_verification_file() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER verification_storage_invalidate_deleted_file AFTER DELETE ON storage.objects
 FOR EACH ROW EXECUTE FUNCTION public.invalidate_deleted_verification_file();

CREATE OR REPLACE FUNCTION public.review_verification_document(
 p_document_id uuid, p_status text, p_notes text DEFAULT NULL,
 p_confirmed_number text DEFAULT NULL, p_trade_class text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
 PERFORM public.admin_require_active(auth.uid());
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
$$;
REVOKE ALL ON FUNCTION public.review_verification_document(uuid,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_verification_document(uuid,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.revoke_verification(p_user_id uuid,p_kind text,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
 v_id uuid;
 v_reason text := nullif(regexp_replace(p_reason,'^[[:space:]]+|[[:space:]]+$','','g'),'');
BEGIN
 PERFORM public.admin_require_active(auth.uid());
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
$$;
REVOKE ALL ON FUNCTION public.revoke_verification(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_verification(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_builder_abn_verified(p_uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.verifications WHERE user_id=p_uid
  AND kind='abn' AND status='verified' AND (expires_at IS NULL OR expires_at>now()));
$$;

CREATE OR REPLACE FUNCTION public.get_trade_public_credentials(p_user_id uuid)
RETURNS TABLE(user_id uuid,doc_type text,expires_at date,credential_status text,captured_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT vd.trade_id,vd.doc_type::text,vd.expiry_date,
  CASE WHEN vd.expiry_date IS NULL OR vd.expiry_date>=current_date THEN 'current' ELSE 'expired' END,
  vd.reviewed_at FROM public.verification_documents vd
 JOIN public.trade_profiles tp ON tp.id=vd.trade_id
 WHERE vd.trade_id=p_user_id AND vd.status='approved' AND vd.deleted_at IS NULL
  AND vd.doc_type IN ('white_card','public_liability') AND tp.deleted_at IS NULL;
$$;
-- Public badges evaluate expiry on read, even between maintenance sweeps.
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
    EXISTS (SELECT 1 FROM public.verifications v WHERE v.user_id=tp.id AND v.kind='licence' AND v.status='verified' AND (v.expires_at IS NULL OR v.expires_at>now())) AS "is_verified",
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
-- Reconcile matching evidence removed before this migration installed the
-- trigger. Keep newer manual decisions and independent regulator checks.
UPDATE public.verifications v SET status='failed',failure_reason='manual_evidence_removed',
 manual_fallback_allowed=true,last_checked_at=clock_timestamp(),updated_at=clock_timestamp()
WHERE v.status='verified' AND v.register_source='admin_manual' AND EXISTS (
 SELECT 1 FROM public.verification_documents d WHERE d.trade_id=v.user_id
  AND d.status='approved' AND d.deleted_at IS NOT NULL AND d.reviewed_at=v.verified_at
  AND d.doc_type=CASE v.kind WHEN 'abn' THEN 'abn_certificate'::public.document_doc_type
   WHEN 'licence' THEN 'trade_licence'::public.document_doc_type END
);
-- Existing receipts also lose trust when their recorded bytes no longer
-- exist or belong to another account, including previously hidden receipts.
-- Reconcile core timestamps above before replacing old approval status.
UPDATE public.verification_documents d SET deleted_at=coalesce(deleted_at,clock_timestamp()),status='rejected',
 rejection_reason='Evidence file missing. Upload a new document.'
WHERE d.status IN ('pending','approved')
 AND (d.file_path IS NULL OR split_part(d.file_path,'/',1)<>d.trade_id::text
  OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='private-docs' AND o.name=d.file_path));
COMMIT;
