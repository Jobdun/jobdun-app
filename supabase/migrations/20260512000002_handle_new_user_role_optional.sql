-- ============================================================
-- Migration: handle_new_user — role is now optional
--
-- Why: SSO sign-ups (Google/Apple) don't pass role in user_metadata.
-- The previous trigger silently defaulted them to 'trade', surfacing
-- a role the user never picked. Friction-reduction sprint T1.2 makes
-- the trigger insert into user_roles ONLY when a valid role is supplied.
-- For SSO users, the missing JWT claim drives RoleSelectionSheet on
-- first home visit (lib/features/auth/presentation/widgets/role_selection_sheet.dart).
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
  v_display_name := NEW.raw_user_meta_data->>'full_name';
  v_role         := NEW.raw_user_meta_data->>'role';

  -- Profile row always created (email lives in auth.users)
  INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, v_display_name)
    ON CONFLICT (id) DO NOTHING;

  -- Role + stub profile only when a valid role was supplied
  IF v_role IN ('builder', 'trade', 'admin') THEN
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

-- Trigger definition is unchanged; the function body is what we're updating.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
