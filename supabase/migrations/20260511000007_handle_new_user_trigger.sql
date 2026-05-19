-- ============================================================
-- Migration 7: handle_new_user trigger
-- Auto-inserts into profiles + user_roles when a new auth.users row is created.
-- Required for every sign-up path (email, Google, Apple, phone/OTP).
-- Must exist BEFORE any sign-up is attempted.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name text;
  v_role         text;
BEGIN
  -- Pull metadata set during sign-up (e.g. data: {'full_name': ..., 'role': ...})
  v_display_name := NEW.raw_user_meta_data->>'full_name';
  v_role         := COALESCE(NEW.raw_user_meta_data->>'role', 'trade');

  -- Normalise role — reject anything unexpected
  IF v_role NOT IN ('builder', 'trade', 'admin') THEN
    v_role := 'trade';
  END IF;

  -- Core profile row (email lives in auth.users, not here)
  INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, v_display_name)
    ON CONFLICT (id) DO NOTHING;

  -- Role row (drives JWT claim via custom_access_token_hook)
  INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, v_role)
    ON CONFLICT (user_id) DO NOTHING;

  -- Stub role-specific profile so joins never return NULL
  -- PK is 'id' (= profiles.id) to match auth_provider.dart upsert shape
  IF v_role = 'builder' THEN
    INSERT INTO public.builder_profiles (id)
      VALUES (NEW.id)
      ON CONFLICT (id) DO NOTHING;
  ELSE
    INSERT INTO public.trade_profiles (id, full_name)
      VALUES (NEW.id, v_display_name)
      ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop and recreate to keep this idempotent on re-run
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
