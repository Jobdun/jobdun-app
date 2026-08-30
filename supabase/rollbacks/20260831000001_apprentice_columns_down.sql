-- Down for 20260831000001_apprentice_columns.sql
DROP INDEX IF EXISTS public.trade_profiles_is_apprentice_idx;
ALTER TABLE public.trade_profiles
  DROP CONSTRAINT IF EXISTS trade_profiles_apprenticeship_stage_valid;
ALTER TABLE public.trade_profiles
  DROP COLUMN IF EXISTS is_apprentice,
  DROP COLUMN IF EXISTS apprenticeship_stage,
  DROP COLUMN IF EXISTS site_tickets,
  DROP COLUMN IF EXISTS resume_path,
  DROP COLUMN IF EXISTS resume_uploaded_at;
