-- ============================================================
-- Migration: trade_categories reference table + trade_other column
--
-- Why: The /profile/edit trade picker is search-first and grouped (T2.3 of
-- the friction-reduction sprint). Sourcing the list from the DB lets us
-- edit/add categories without an app release. trade_other captures custom
-- entries when users pick "Other" — admins curate these into canonical
-- slugs over time.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.trade_categories (
  slug          text PRIMARY KEY,
  display_name  text NOT NULL,
  category      text NOT NULL
                  CHECK (category IN (
                    'electrical', 'structural', 'finishing', 'heavy_specialist'
                  )),
  sort_order    int  NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Public reference data — anyone authenticated can read.
ALTER TABLE public.trade_categories ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "trade_categories_select_all"
    ON public.trade_categories FOR SELECT
    TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Seed the canonical 19 from the old onboarding chip wall, grouped.
INSERT INTO public.trade_categories (slug, display_name, category, sort_order) VALUES
  -- Electrical
  ('electrician',    'Electrician',    'electrical',       10),
  -- Structural
  ('carpenter',      'Carpenter',      'structural',       10),
  ('bricklayer',     'Bricklayer',     'structural',       20),
  ('concreter',      'Concreter',      'structural',       30),
  ('steel_fixer',    'Steel Fixer',    'structural',       40),
  ('form_worker',    'Form Worker',    'structural',       50),
  ('welder',         'Welder',         'structural',       60),
  ('boilermaker',    'Boilermaker',    'structural',       70),
  -- Finishing
  ('plasterer',      'Plasterer',      'finishing',        10),
  ('painter',        'Painter',        'finishing',        20),
  ('tiler',          'Tiler',          'finishing',        30),
  ('cabinet_maker',  'Cabinet Maker',  'finishing',        40),
  ('roof_plumber',   'Roof Plumber',   'finishing',        50),
  ('plumber',        'Plumber',        'finishing',        60),
  -- Heavy / Specialist
  ('rigger',         'Rigger',         'heavy_specialist', 10),
  ('scaffolder',     'Scaffolder',     'heavy_specialist', 20),
  ('crane_operator', 'Crane Operator', 'heavy_specialist', 30),
  ('demolition',     'Demolition',     'heavy_specialist', 40)
ON CONFLICT (slug) DO NOTHING;

-- Custom trade entry — captured when user selects "Other" in the picker.
-- Nullable text so existing rows are unaffected.
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS trade_other text;
