-- supabase/migrations/20260527000004_profile_phone_sync.sql
--
-- Extends the existing phone-sync trigger to mirror the phone *number*
-- (auth.users.phone) into public.profiles.phone, not just the
-- phone_confirmed_at timestamp.
--
-- Background. 20260514000002 set up a trigger that mirrors phone_confirmed_at
-- → profiles.phone_verified_at so the completeness banner credits the slot.
-- The original audit note claimed the phone number itself was already
-- mirrored "via the existing flow" — that flow never actually existed.
-- Result: after a successful OTP, profiles.phone_verified_at flips to now()
-- but profiles.phone stays NULL, so any UI reading profiles.phone (e.g. the
-- COMPANY DETAILS card's Contact / Phone row) shows "Not set" even though
-- the account has a verified number.
--
-- This migration:
--   1. Replaces the function to also mirror phone alongside phone_confirmed_at
--   2. Updates the trigger to fire on `phone` OR `phone_confirmed_at` changes
--   3. Backfills profiles.phone for existing accounts (single indexed UPDATE)

CREATE OR REPLACE FUNCTION public.sync_phone_verified_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- INSERT path: profiles row may not exist yet (handle_new_user fires on the
  -- same INSERT). Use UPDATE-or-skip rather than UPSERT so we don't create
  -- a half-formed profile row from a transient state.
  IF TG_OP = 'INSERT' THEN
    IF NEW.phone IS NOT NULL OR NEW.phone_confirmed_at IS NOT NULL THEN
      UPDATE public.profiles
         SET phone             = NEW.phone,
             phone_verified_at = NEW.phone_confirmed_at,
             updated_at        = now()
       WHERE id = NEW.id
         AND (phone IS DISTINCT FROM NEW.phone
              OR phone_verified_at IS DISTINCT FROM NEW.phone_confirmed_at);
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE path: only write when something actually changed, so updated_at
  -- doesn't thrash on unrelated auth.users updates (session refreshes etc).
  IF NEW.phone             IS DISTINCT FROM OLD.phone
     OR NEW.phone_confirmed_at IS DISTINCT FROM OLD.phone_confirmed_at THEN
    UPDATE public.profiles
       SET phone             = NEW.phone,
           phone_verified_at = NEW.phone_confirmed_at,
           updated_at        = now()
     WHERE id = NEW.id
       AND (phone IS DISTINCT FROM NEW.phone
            OR phone_verified_at IS DISTINCT FROM NEW.phone_confirmed_at);
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_phone_verified_at() IS
  'Mirrors auth.users.phone + phone_confirmed_at into public.profiles.phone '
  '+ phone_verified_at so cross-user views and the profile UI read a single '
  'consistent value without needing auth.users access. Service-role isolated '
  'via SECURITY DEFINER + search_path = public.';

-- Refire the trigger on both columns. The 20260514 trigger only watched
-- phone_confirmed_at; we widen it to include phone so a phone-update path
-- (e.g. updateUser(phone:) before OTP confirm) also mirrors immediately.
DROP TRIGGER IF EXISTS on_auth_user_phone_confirmed ON auth.users;

CREATE TRIGGER on_auth_user_phone_confirmed
  AFTER INSERT OR UPDATE OF phone, phone_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_phone_verified_at();

-- Backfill: anyone who already has auth.users.phone set but a NULL
-- profiles.phone gets credited. Idempotent — IS DISTINCT FROM filters out
-- rows that already match.
UPDATE public.profiles p
   SET phone      = u.phone,
       updated_at = now()
  FROM auth.users u
 WHERE u.id = p.id
   AND u.phone IS NOT NULL
   AND p.phone IS DISTINCT FROM u.phone;
