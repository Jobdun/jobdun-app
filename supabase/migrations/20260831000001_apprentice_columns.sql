-- supabase/migrations/20260831000001_apprentice_columns.sql
--
-- Apprentice mode on the existing trade role. An apprentice IS a trade row:
-- primary_trade carries the apprenticeship they want (the same trade_categories
-- picker every tradie uses), about carries the description, portfolio_urls
-- carries the photos. Only these five columns are new.
--
-- Deliberately NOT a third auth role: that would touch the JWT user_role claim,
-- RLS across every table, the router, and delete_my_account, for a distinction
-- the data model can carry in one boolean.
--
-- Reversibility: SAFE -- additive columns with defaults; no data is rewritten.
-- Down: supabase/rollbacks/20260831000001_apprentice_columns_down.sql

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_apprentice        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS apprenticeship_stage text,
  ADD COLUMN IF NOT EXISTS site_tickets         text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS resume_path          text,
  ADD COLUMN IF NOT EXISTS resume_uploaded_at   timestamptz;

-- Stage stays nullable even when is_apprentice is true: "not sure yet" is a
-- real answer for a school leaver, and NOT NULL would force a bad default.
DO $$ BEGIN
  ALTER TABLE public.trade_profiles
    ADD CONSTRAINT trade_profiles_apprenticeship_stage_valid
    CHECK (apprenticeship_stage IS NULL OR apprenticeship_stage IN
      ('pre_apprentice','year_1','year_2','year_3','year_4'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS trade_profiles_is_apprentice_idx
  ON public.trade_profiles (is_apprentice) WHERE deleted_at IS NULL;

COMMENT ON COLUMN public.trade_profiles.is_apprentice IS
  'True when this trade is seeking an apprenticeship. Flips the profile to the '
  'apprentice layout (no rates, no insurance, no jobs-completed stat) and moves '
  'the row to the APPRENTICES side of search_trades.';

COMMENT ON COLUMN public.trade_profiles.site_tickets IS
  'SELF-DECLARED site ticket slugs (FK-by-convention to site_tickets.slug). A '
  'tick is a claim, NOT proof -- verified credentials live in '
  'verification_documents and surface via get_trade_public_credentials. Never '
  'merge the two lists on a display surface.';

COMMENT ON COLUMN public.trade_profiles.resume_path IS
  'private-docs path, {uid}/resume/{epoch}.{ext}. Never a public URL: reading it '
  'requires a signed URL gated by private_docs_resume_applied_builder_select.';
