-- Contact enquiries from the marketing site (jobdun.com.au/contact).
--
-- Written ONLY by the contact-send edge function (service role): the form
-- posts to a Next.js route handler on the marketing site, which forwards to
-- the function with an internal token (same pattern as push-send's
-- PUSH_INTERNAL_TOKEN). No client role can read or write: RLS is enabled
-- with zero policies, plus explicit revokes so PostgREST never exposes it.
--
-- Rollback: supabase/rollbacks/20260814000001_contact_enquiries_down.sql

create table if not exists public.contact_enquiries (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null check (char_length(name) between 1 and 200),
  email text not null check (char_length(email) between 3 and 320),
  phone text check (phone is null or char_length(phone) <= 40),
  role text check (role is null or char_length(role) <= 40),
  state text check (state is null or char_length(state) <= 10),
  message text not null check (char_length(message) between 1 and 5000),
  user_agent text check (user_agent is null or char_length(user_agent) <= 512),
  -- sha256 hex of the caller IP: enough for abuse triage, no raw PII at rest.
  ip_hash text check (ip_hash is null or char_length(ip_hash) <= 64)
);

comment on table public.contact_enquiries is
  'Marketing-site contact form submissions. Service-role only (contact-send edge function).';

alter table public.contact_enquiries enable row level security;

revoke all on table public.contact_enquiries from anon, authenticated;
