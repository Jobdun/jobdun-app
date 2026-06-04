-- =============================================================================
-- verify_builder.sql — manually mark a builder as ABN-verified (bypass wizard)
-- =============================================================================
-- Run in the Supabase SQL Editor (service-role — RLS does not block you).
-- Work top to bottom: STEP 1 checks the user, STEP 2 verifies them, STEP 3 confirms.
--
-- The only thing that lets a builder post jobs is one row in public.verifications
-- with kind='abn' AND status='verified' (enforced by is_builder_abn_verified() in
-- migration 20260604000002). ABN rows never expire (the expiry sweep only touches
-- kind='licence'), so this sticks permanently.
--
-- The builder id is set once below — change it to re-use this file.
-- =============================================================================

-- Builder being verified:
--   dc5028cc-3503-4aaa-93db-7be64e8d3eeb


-- -----------------------------------------------------------------------------
-- STEP 1 — Check the user FIRST (who they are + why they're blocked)
-- -----------------------------------------------------------------------------

-- 1a. Account + role + does it currently pass the job-posting gate?
-- (Inline EXISTS instead of is_builder_abn_verified() — that function ships in
--  migration 20260604000002, which may not be applied to this DB yet.)
select
  p.id,
  p.display_name,
  bp.company_name,
  ur.role,
  exists (
    select 1 from public.verifications v
    where v.user_id = p.id and v.kind = 'abn' and v.status = 'verified'
  ) as can_post_jobs                                       -- false = blocked
from public.profiles p
left join public.user_roles ur on ur.user_id = p.id
left join public.builder_profiles bp on bp.id = p.id
where p.id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb';

-- 1b. Existing verification rows (this is where the block lives)
select id, kind, status, abn, verified_at, expires_at, failure_reason, updated_at
from public.verifications
where user_id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb';


-- -----------------------------------------------------------------------------
-- STEP 2 — Force the builder to ABN-verified (idempotent — safe to re-run)
-- -----------------------------------------------------------------------------
-- Updates the existing abn row to verified, or inserts one if none exists.
-- (No UNIQUE(user_id, kind) on the table, so this is update-else-insert, not ON CONFLICT.)

with upd as (
  update public.verifications
     set status          = 'verified',
         verified_at     = now(),
         last_checked_at = now(),
         failure_reason  = null,
         expires_at      = null,        -- ABN doesn't expire; never swept
         updated_at      = now()
   where user_id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb'
     and kind    = 'abn'
  returning id
)
insert into public.verifications (user_id, kind, status, verified_at, last_checked_at)
select 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb', 'abn', 'verified', now(), now()
where not exists (select 1 from upd);


-- -----------------------------------------------------------------------------
-- STEP 3 — Confirm it worked (expect: true)
-- -----------------------------------------------------------------------------

select exists (
  select 1 from public.verifications
  where user_id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb'
    and kind = 'abn' and status = 'verified'
) as can_post_jobs;


-- -----------------------------------------------------------------------------
-- OPTIONAL — show real ABN details on the profile card instead of "Not set".
-- Only run if you have the real ABN. Replace the placeholders first.
-- -----------------------------------------------------------------------------

-- update public.verifications
--    set abn = '11111111111', abn_entity_name = 'ACME BUILDING PTY LTD'
--  where user_id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb' and kind = 'abn';

-- update public.builder_profiles
--    set abn = '11111111111', updated_at = now()
--  where id = 'dc5028cc-3503-4aaa-93db-7be64e8d3eeb';
