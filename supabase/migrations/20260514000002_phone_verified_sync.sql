-- ============================================================
-- Migration: sync auth.users.phone_confirmed_at → profiles.phone_verified_at
--
-- Why: the T1 banner credits "phone verified" as a slot (25% builder /
-- 20% trade). Supabase Auth marks phone confirmation on auth.users; the
-- mobile app and the profile_completeness view both read profiles. Without
-- this mirror, every successful OTP verify still leaves the banner showing
-- "you're missing a phone" forever.
--
-- The trigger fires on every auth.users INSERT/UPDATE. When the column
-- transitions from NULL → timestamp, we mirror it. When the column is
-- nulled (admin un-confirm), we mirror that too so the banner re-surfaces.
--
-- AU retention note: phone_verified_at is a verification timestamp, not
-- the phone number. The number lives on auth.users.phone and is mirrored
-- to profiles.phone via the existing flow; this column only records when
-- it was confirmed. Cascades on auth.users delete via profiles' FK.
--
-- Idempotent: function uses CREATE OR REPLACE, trigger is dropped+recreated.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_phone_verified_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert path: profiles row may not exist yet (handle_new_user fires on
  -- the same INSERT). Use UPDATE-or-skip rather than UPSERT so we don't
  -- accidentally create a half-formed profile row.
  IF (TG_OP = 'INSERT' AND NEW.phone_confirmed_at IS NOT NULL)
     OR (TG_OP = 'UPDATE'
         AND NEW.phone_confirmed_at IS DISTINCT FROM OLD.phone_confirmed_at) THEN
    UPDATE public.profiles
       SET phone_verified_at = NEW.phone_confirmed_at
     WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_phone_confirmed ON auth.users;

CREATE TRIGGER on_auth_user_phone_confirmed
  AFTER INSERT OR UPDATE OF phone_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_phone_verified_at();

-- One-shot backfill so anyone who already confirmed before this migration
-- ran gets credited on next /home visit. Cheap — single indexed UPDATE.
UPDATE public.profiles p
   SET phone_verified_at = u.phone_confirmed_at
  FROM auth.users u
 WHERE u.id = p.id
   AND u.phone_confirmed_at IS NOT NULL
   AND p.phone_verified_at IS DISTINCT FROM u.phone_confirmed_at;
