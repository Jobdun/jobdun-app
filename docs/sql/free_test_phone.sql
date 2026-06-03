-- ============================================================================
-- Jobdun · demo/admin helper — free a phone number / delete a test account
-- ----------------------------------------------------------------------------
-- HOW TO USE: paste this WHOLE file into the Supabase SQL editor and run.
-- It is paste-safe — every note is a "--" comment, so nothing throws a syntax
-- error. By DEFAULT only the PREVIEW (section 1) runs. The destructive
-- statements (sections 2-4) are commented out: uncomment the ONE you want,
-- then run again.
--
-- Target number: change it below if needed. Supabase stores auth.users.phone
-- as E.164 digits WITHOUT the leading "+", e.g.  61412250579
-- ============================================================================


-- ── 1) PREVIEW — who owns this number right now? (safe, read-only) ──────────
select
  u.id, u.email, u.phone, ur.role, p.display_name, u.created_at,
  exists(select 1 from public.builder_profiles b where b.id = u.id) as has_builder_profile,
  exists(select 1 from public.trade_profiles   t where t.id = u.id) as has_trade_profile,
  (select count(*) from public.verifications v where v.user_id = u.id)           as verifications,
  (select count(*) from public.verification_documents d where d.trade_id = u.id) as docs
from auth.users u
left join public.profiles   p  on p.id = u.id
left join public.user_roles ur on ur.user_id = u.id
where u.phone like '%412250579%';


-- ── 2) OPTION A — DELETE the whole account (frees the number completely) ────
-- Use this when section 1 shows a throwaway/test account. It cascades to
-- profiles, user_roles, builder/trade profiles, verifications, docs, jobs,
-- messages, reviews… everything tied to that user. Uncomment to run:
--
-- delete from auth.users where phone = '61412250579';


-- ── 3) OPTION B — keep the account, just DETACH the phone ───────────────────
-- Use this when that account is real and you only want to unbind the number.
-- Uncomment the whole block to run:
--
-- update auth.users
--    set phone = null, phone_confirmed_at = null,
--        phone_change = '', phone_change_token = ''
--  where phone = '61412250579';
--
-- delete from auth.identities
--  where provider = 'phone'
--    and (identity_data->>'phone') = '61412250579';


-- ── 4) BONUS — clear verification details (to re-demo the verify flow) ──────
-- ONE user, by email — uncomment to run:
--
-- delete from public.verification_documents
--  where trade_id = (select id from auth.users where email = 'someone@example.com');
-- delete from public.verifications
--  where user_id = (select id from auth.users where email = 'someone@example.com');
--
-- ALL users — uncomment to run (trade_profiles.is_verified resets via trigger):
--
-- delete from public.verification_documents;
-- delete from public.verifications;
