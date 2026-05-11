-- ============================================================
-- Migration 1: Core user identity tables
-- Columns derived from lib/features/auth/data/models/user_model.dart
-- and lib/features/auth/data/datasources/auth_remote_datasource.dart
-- ============================================================

-- profiles: one row per auth.users row (created by trigger in migration 7)
CREATE TABLE IF NOT EXISTS public.profiles (
  id                       uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name             text,
  avatar_url               text,
  onboarding_completed_at  timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

-- user_roles: drives the custom_access_token_hook JWT claim
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role       text NOT NULL DEFAULT 'trade'
               CHECK (role IN ('builder', 'trade', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- builder_profiles: extended data for builder role users
-- PK column is named 'id' (= profiles.id) to match auth_provider.dart upsert keys
-- company_name referenced by JobApplicationModel joined as builder_profiles.company_name
CREATE TABLE IF NOT EXISTS public.builder_profiles (
  id           uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  company_name text,
  abn          text,
  logo_url     text,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- trade_profiles: extended data for trade/crew role users
-- PK column is named 'id' (= profiles.id) to match auth_provider.dart upsert keys
-- full_name, primary_trade, is_verified referenced by JobApplicationModel joined as trade_profiles.*
CREATE TABLE IF NOT EXISTS public.trade_profiles (
  id               uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  full_name        text,
  primary_trade    text,
  is_verified      boolean NOT NULL DEFAULT false,
  bio              text,
  portfolio_urls   text[],
  hourly_rate      numeric(10, 2),
  day_rate         numeric(10, 2),
  years_experience int,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Auto-update updated_at on row change
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER builder_profiles_updated_at
  BEFORE UPDATE ON public.builder_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trade_profiles_updated_at
  BEFORE UPDATE ON public.trade_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

