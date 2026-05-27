-- supabase/migrations/20260527000006_handle_new_user_coalesce_metadata.sql
--
-- Replaces handle_new_user() to capture display_name + avatar_url from the
-- metadata shape that each auth provider actually sends. The previous version
-- (20260516000002) only read raw_user_meta_data->>'full_name', which is the
-- key our own email signup writes — but Google/Apple/phone signups never set
-- that key, so SSO + phone users ended up with NULL display_name and a
-- nameless profile until they edited it manually.
--
-- Key map per provider (verified against Supabase Auth's metadata mapping):
--   Email (our own)  : raw_user_meta_data.full_name           (already worked)
--   Google           : raw_user_meta_data.name                (OIDC standard)
--                    + raw_user_meta_data.given_name + family_name (fallback)
--                    + raw_user_meta_data.picture             (avatar URL)
--                    + raw_user_meta_data.avatar_url          (also written
--                      by some Supabase Auth versions)
--   Apple            : raw_user_meta_data.name.firstName + .lastName
--                      (nested object on FIRST signin only — Apple privacy)
--                    + Apple does not provide an avatar URL
--   Phone (OTP)      : no metadata at all → display_name stays NULL
--                      (the unified completion sheet collects it post-auth)
--
-- The handle_new_user trigger runs on EVERY auth.users INSERT, so this fires
-- once per signup. Idempotent via ON CONFLICT DO NOTHING.
--
-- Also includes a one-shot backfill for existing SSO/phone users whose
-- profile.display_name is NULL but whose auth.users metadata carries a name
-- the previous trigger missed.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name text;
  v_avatar_url   text;
  v_role         text;
  v_meta         jsonb := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
BEGIN
  -- Display name: try every key the four signup paths actually populate,
  -- in priority order. NULLIF + trim handles whitespace-only entries.
  v_display_name := COALESCE(
    NULLIF(trim(v_meta->>'full_name'), ''),
    NULLIF(trim(v_meta->>'name'), ''),
    NULLIF(trim(
      coalesce(v_meta->>'given_name', '') || ' ' ||
      coalesce(v_meta->>'family_name', '')
    ), ''),
    -- Apple sends {"name":{"firstName":"...","lastName":"..."}} on first
    -- signin only. The string "null null" can arise if both inner fields
    -- are missing — guard against it explicitly.
    NULLIF(trim(
      coalesce(v_meta->'name'->>'firstName', '') || ' ' ||
      coalesce(v_meta->'name'->>'lastName', '')
    ), ''),
    null
  );

  -- Avatar URL: only Google supplies one (via the OIDC `picture` claim,
  -- which Supabase maps to either `picture` or `avatar_url` depending on
  -- version). Apple + phone leave this NULL.
  v_avatar_url := COALESCE(
    NULLIF(v_meta->>'avatar_url', ''),
    NULLIF(v_meta->>'picture', ''),
    null
  );

  v_role := v_meta->>'role';

  INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (NEW.id, v_display_name, v_avatar_url)
    ON CONFLICT (id) DO NOTHING;

  -- admin role intentionally NOT accepted from client metadata
  -- (see 20260516000002_forbid_self_admin.sql — F-RLS-01 lockdown).
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id)
        VALUES (NEW.id)
        ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name)
        ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Fires on auth.users INSERT. Mirrors display_name + avatar_url from the '
  'provider-specific metadata keys (Google: name/picture, Apple: nested '
  'name.firstName/lastName, email: full_name). Phone signups leave both '
  'NULL — the unified onboarding completion sheet collects them post-auth.';

-- One-shot backfill: any existing user whose profiles.display_name is NULL
-- but whose auth.users metadata actually carries a name. Captures the
-- Google/Apple users who signed up before this migration landed.
UPDATE public.profiles p
   SET display_name = sub.captured_name,
       avatar_url   = COALESCE(p.avatar_url, sub.captured_avatar),
       updated_at   = now()
  FROM (
    SELECT u.id,
           COALESCE(
             NULLIF(trim(u.raw_user_meta_data->>'full_name'), ''),
             NULLIF(trim(u.raw_user_meta_data->>'name'), ''),
             NULLIF(trim(
               coalesce(u.raw_user_meta_data->>'given_name', '') || ' ' ||
               coalesce(u.raw_user_meta_data->>'family_name', '')
             ), ''),
             NULLIF(trim(
               coalesce(u.raw_user_meta_data->'name'->>'firstName', '') || ' ' ||
               coalesce(u.raw_user_meta_data->'name'->>'lastName', '')
             ), '')
           ) AS captured_name,
           COALESCE(
             NULLIF(u.raw_user_meta_data->>'avatar_url', ''),
             NULLIF(u.raw_user_meta_data->>'picture', '')
           ) AS captured_avatar
    FROM auth.users u
  ) sub
 WHERE p.id = sub.id
   AND sub.captured_name IS NOT NULL
   AND (p.display_name IS NULL OR p.display_name = '');
