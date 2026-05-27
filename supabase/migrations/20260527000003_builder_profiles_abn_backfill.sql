-- supabase/migrations/20260527000003_builder_profiles_abn_backfill.sql
--
-- One-time backfill. The original verify-abn Edge Function (pre-2026-05-27)
-- wrote successful checks to `public.verifications` only — the verified ABN
-- was never mirrored into `public.builder_profiles.abn`, so builder profile
-- screens showed "Not set" for ABN even after a successful regulator match.
--
-- The Edge Function is fixed forward-going from this date; this migration
-- repairs the rows already in the database. Same idempotent shape as the
-- trade_is_verified backfill in 20260527000002 — only writes when the
-- target field actually differs from the source.

-- Mirror verified ABN into builder_profiles for builder accounts whose
-- profile column is still NULL.
UPDATE public.builder_profiles bp
   SET abn        = v.abn,
       updated_at = now()
  FROM public.verifications v
  JOIN public.user_roles ur ON ur.user_id = v.user_id
 WHERE v.user_id   = bp.id
   AND v.kind      = 'abn'
   AND v.status    = 'verified'
   AND ur.role     = 'builder'
   AND bp.abn IS DISTINCT FROM v.abn
   AND bp.abn IS NULL;

-- Mirror ABR legal-entity name into company_name, but only when the
-- builder hasn't set their own trading name yet. Never overwrite a
-- user-chosen company_name with the ABR legal-entity name (those legitimately
-- differ for sole traders / trading-as arrangements).
UPDATE public.builder_profiles bp
   SET company_name = v.abn_entity_name,
       updated_at   = now()
  FROM public.verifications v
  JOIN public.user_roles ur ON ur.user_id = v.user_id
 WHERE v.user_id          = bp.id
   AND v.kind             = 'abn'
   AND v.status           = 'verified'
   AND ur.role            = 'builder'
   AND v.abn_entity_name IS NOT NULL
   AND bp.company_name   IS NULL;
