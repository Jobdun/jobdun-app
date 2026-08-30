-- supabase/migrations/20260831000002_site_tickets.sql
--
-- Reference table for site tickets / high-risk-work licences, modelled on
-- trade_categories so the list is editable from the dashboard without an app
-- release.
--
-- doc_type maps a ticket to the verification_documents review path. Only
-- white_card has one today: it is the single ticket with a working end-to-end
-- flow (ManualDocKind.whiteCard -> verification_documents -> admin review ->
-- get_trade_public_credentials). The other eight are self-declared only, and
-- the "upload to verify" nudge renders solely where doc_type IS NOT NULL, so
-- there are no dead-end taps.
--
-- EWP is split into the two real Australian tickets. The Yellow Card is an
-- industry VOC card for boom lifts under 11m; WP is a high risk work licence
-- for 11m and above. Sites ask for them separately, so one merged "EWP" row
-- would be unfilterable for a builder hiring a 20m boom.
--
-- Reversibility: SAFE -- new table only.
-- Down: supabase/rollbacks/20260831000002_site_tickets_down.sql

CREATE TABLE IF NOT EXISTS public.site_tickets (
  slug         text PRIMARY KEY,
  display_name text NOT NULL,
  short_name   text NOT NULL,
  category     text NOT NULL
                 CHECK (category IN ('induction','safety','licence','transport')),
  doc_type     text,
  sort_order   int  NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Public reference data -- anyone authenticated can read, nobody can write.
ALTER TABLE public.site_tickets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "site_tickets_select_all"
    ON public.site_tickets FOR SELECT
    TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

INSERT INTO public.site_tickets
  (slug, short_name, display_name, category, doc_type, sort_order) VALUES
  ('white_card',         'White Card',         'White Card (Construction Induction, CPCCWHS1001)', 'induction', 'white_card', 10),
  ('first_aid',          'First Aid',          'First Aid (HLTAID011)',                            'safety',    NULL,         10),
  ('working_at_heights', 'Working at Heights', 'Working at Heights (RIIWHS204E)',                  'safety',    NULL,         20),
  ('confined_space',     'Confined Space',     'Confined Space (RIIWHS202E)',                      'safety',    NULL,         30),
  ('ewp_yellow_card',    'EWP Yellow Card',    'EWP Yellow Card (boom under 11m)',                 'licence',   NULL,         10),
  ('ewp_wp_licence',     'EWP Licence (WP)',   'EWP High Risk Work Licence (WP, boom 11m+)',       'licence',   NULL,         20),
  ('dogging',            'Dogging',            'Dogging Licence (DG)',                             'licence',   NULL,         30),
  ('rigging',            'Rigging',            'Rigging Licence (RB / RI / RA)',                   'licence',   NULL,         40),
  ('drivers_licence',    'Driver Licence',     'Australian Driver Licence',                        'transport', NULL,         10)
ON CONFLICT (slug) DO NOTHING;

COMMENT ON TABLE public.site_tickets IS
  'Reference list of site tickets an apprentice or tradie can self-declare. '
  'doc_type non-null means the ticket has a verification_documents review path '
  'and can reach the VERIFIED tier; null means self-declared only.';
