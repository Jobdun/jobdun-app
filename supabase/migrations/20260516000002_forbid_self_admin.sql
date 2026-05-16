-- ============================================================
-- Migration: forbid self-assigned admin (F-RLS-01)
-- Closes the signup-trigger admin backdoor. Defence in depth:
--   1. handle_new_user no longer honours role='admin' from metadata
--   2. forbid_self_admin trigger blocks ANY non-superuser admin INSERT
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

  INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, v_display_name)
    ON CONFLICT (id) DO NOTHING;

  -- admin role intentionally NOT accepted from client metadata (F-RLS-01).
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;

    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id)
        VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name) ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Defence in depth: nothing self-serve may write an admin role row.
CREATE OR REPLACE FUNCTION public.forbid_self_admin()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role = 'admin' THEN
    RAISE EXCEPTION 'admin role cannot be self-assigned'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_roles_forbid_self_admin ON public.user_roles;
CREATE TRIGGER user_roles_forbid_self_admin
  BEFORE INSERT ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.forbid_self_admin();
