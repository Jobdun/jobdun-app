# Apprentice profiles — design spec

**Date:** 2026-08-30
**Status:** Draft, awaiting user review
**Branch target:** `feat/apprentice-profiles` (off `main`)
**Skills applied:** `superpowers:brainstorming`, `impeccable shape` (product register), `ui-ux-pro-max` + `design-system/jobdun/MASTER.md` + `pages/profile-dashboard.md`

---

## 1. Feature summary

Apprentices and pre-apprentices are a real slice of the Australian trades market that Jobdun
currently has no shape for. A first-year chippy has no ABN, no public liability, no trade
licence and no hourly rate, so every field the trade profile asks for is either blank or wrong.
They churn.

This feature gives them a profile that fits: what apprenticeship they want, what stage they are
at, a written description, a resume, a checklist of site tickets, and photos of themselves,
their work and their tools. It then makes that profile findable by builders.

**Primary user action:** an apprentice fills in enough that a builder can decide "worth a call"
in under ten seconds of scrolling.

---

## 2. Decisions taken (confirmed with the user 2026-08-30)

| # | Decision | Chosen |
|---|---|---|
| D1 | Role architecture | **Apprentice mode inside the existing Trade role.** No third auth role, no new JWT claim, no RLS/router/account-deletion churn. |
| D2 | Ticket trust model | **Two tiers.** Self-declared tick = grey chip. Uploaded + human-reviewed = green Verified chip. Tapping a self-declared ticket that has a review path offers upload. |
| D3 | Resume access | **Relationship-gated.** Private by default; a builder can open it only once the apprentice has applied to one of their jobs. |
| D4 | Ticket vocabulary | **Split EWP into the two real AU tickets** (Yellow Card under 11m, WP high-risk licence 11m+). Nine tickets total. |
| D5 | Discovery | **Toggle inside the existing Discovery screen** (`TRADES` / `APPRENTICES`), not a new tab. |
| D6 | Apprenticeship job postings | **Phase 2.** Phase 1 ships the profile and findability only. |
| D7 | Job gates | **`open_to_apprentices` flag on jobs.** See the correction in §3. |

---

## 3. Correction to the D7 framing

D7 was presented as "the flag waives the `requires_verified` / `requires_public_liability`
gates for apprentices". That framing was wrong, and the spec must not carry it forward.

`requires_verified` and `requires_public_liability` are **stored and displayed but never
enforced**. `grep` across `lib/features/applications` and `lib/features/jobs/presentation`
finds no apply-time check; the columns are read by `JobModel` and rendered on the job card, and
that is all. There is no gate to waive.

So `open_to_apprentices` is not a waiver. It is an **invitation signal**:

- Builder ticks it when posting → job card carries an `OPEN TO APPRENTICES` chip.
- Apprentices get a feed filter for those jobs.
- Nothing is blocked for anyone, which matches the platform's stated marketplace posture
  ("trust signals, never gates" — `20260610000006_trade_public_credentials.sql`).

This is simpler than the waiver design and needs no gate logic. Separately worth flagging to
the user: **the job card currently advertises requirements the platform never checks.** That is
a pre-existing honesty gap, out of scope here, and should be tracked.

---

## 4. Data model

### 4.1 Reuse, do not duplicate

Four of the six things the user asked for already exist and must not be rebuilt:

| Asked for | Already exists |
|---|---|
| Their name | `trade_profiles.full_name` |
| Description | `trade_profiles.about` |
| What apprenticeship they want | `trade_profiles.primary_trade` + `trade_categories` (the existing search-first picker) |
| Photos of them / work / tools | `trade_profiles.portfolio_urls` + `PortfolioStrip` + `ImageUploadService.pickCropCompress(ImageAspect.portfolio)` |

`primary_trade` carries the apprenticeship target. An apprentice picks "Carpenter" from the
same picker every tradie uses; `is_apprentice` + `apprenticeship_stage` qualify it into
"2nd-year carpentry apprentice". This keeps Discovery, `displayTrade`, and all trade matching
working with zero new code paths.

### 4.2 New columns on `trade_profiles`

```sql
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_apprentice        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS apprenticeship_stage text,
  ADD COLUMN IF NOT EXISTS site_tickets         text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS resume_path          text,
  ADD COLUMN IF NOT EXISTS resume_uploaded_at   timestamptz;

ALTER TABLE public.trade_profiles
  ADD CONSTRAINT trade_profiles_apprenticeship_stage_valid
  CHECK (apprenticeship_stage IS NULL OR apprenticeship_stage IN
    ('pre_apprentice','year_1','year_2','year_3','year_4'));

CREATE INDEX IF NOT EXISTS trade_profiles_is_apprentice_idx
  ON public.trade_profiles (is_apprentice) WHERE deleted_at IS NULL;
```

`apprenticeship_stage` stays nullable even when `is_apprentice` is true — "not sure yet" is a
real answer for a school leaver, and a NOT NULL constraint would force a bad default.

### 4.3 New reference table `site_tickets`

Modelled on `trade_categories` so the list is editable without an app release.

```sql
CREATE TABLE IF NOT EXISTS public.site_tickets (
  slug         text PRIMARY KEY,
  display_name text NOT NULL,          -- full, with the unit code
  short_name   text NOT NULL,          -- chip label
  category     text NOT NULL CHECK (category IN
                 ('induction','safety','licence','transport')),
  doc_type     text,                   -- maps to verification_documents.doc_type, NULL = no review path yet
  sort_order   int  NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);
```

RLS: enabled, single `SELECT` policy to `authenticated` (`USING (true)`), matching
`trade_categories_select_all`.

Seed (D4 vocabulary):

| slug | short_name | display_name | category | doc_type |
|---|---|---|---|---|
| `white_card` | White Card | White Card (Construction Induction, CPCCWHS1001) | induction | `white_card` |
| `first_aid` | First Aid | First Aid (HLTAID011) | safety | — |
| `working_at_heights` | Working at Heights | Working at Heights (RIIWHS204E) | safety | — |
| `confined_space` | Confined Space | Confined Space (RIIWHS202E) | safety | — |
| `ewp_yellow_card` | EWP Yellow Card | EWP Yellow Card (boom under 11m) | licence | — |
| `ewp_wp_licence` | EWP Licence (WP) | EWP High Risk Work Licence (WP, boom 11m+) | licence | — |
| `dogging` | Dogging | Dogging Licence (DG) | licence | — |
| `rigging` | Rigging | Rigging Licence (RB / RI / RA) | licence | — |
| `drivers_licence` | Driver Licence | Australian Driver Licence | transport | — |

**Only `white_card` has a `doc_type` in phase 1.** It is the one ticket with a working
end-to-end review path today (`ManualDocKind.whiteCard` → `verification_documents` → admin
review → `get_trade_public_credentials`). The other eight ship self-declared only, and the
"upload to get verified" nudge renders only where `doc_type IS NOT NULL`. This is honest and it
makes phase 2 (light up the other eight) an obvious, isolated next step.

Deliberately **not** doing in phase 1: adding a `ticket_slug` column to
`verification_documents`. Laying down a column nothing reads is exactly the half-built layer
`CLAUDE.md` says to delete rather than leave as documentation.

### 4.4 New column on `jobs`

```sql
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS open_to_apprentices boolean NOT NULL DEFAULT false;
```

### 4.5 Resume storage and access

- Bucket: **`private-docs`** (exists, not public).
- Path: `{uid}/resume/{epoch}.{ext}` — the existing `private_docs_owner_*` policies key on
  `(storage.foldername(name))[1] = auth.uid()`, so the owner already has full CRUD with no
  change.
- Formats: PDF, DOC, DOCX. Cap 5 MB.

Builder read access is an **additive SELECT policy** on `storage.objects`. Postgres OR-s
policies, so this widens read without touching the owner-only rule:

```sql
CREATE POLICY "private_docs_resume_applied_builder_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'private-docs'
    AND (storage.foldername(name))[2] = 'resume'
    AND EXISTS (
      SELECT 1
      FROM public.job_applications ja
      JOIN public.jobs j ON j.id = ja.job_id
      WHERE ja.trade_id::text = (storage.foldername(name))[1]
        AND j.builder_id = auth.uid()
    )
  );
```

The client then calls `createSignedUrl(path, 3600)` with the anon key and Storage enforces the
policy. **No Edge Function is needed** — this was the alternative considered and rejected as
unnecessary ceremony. Admin reviewers already have a `private-docs` SELECT policy from
`20260527000001_verification_documents_admin_review.sql`.

### 4.6 `search_trades` signature change

`search_trades` is `SECURITY DEFINER` with a fixed `RETURNS TABLE`. Adding columns **cannot**
use `CREATE OR REPLACE` — Postgres refuses a return-type change. The migration must
`DROP FUNCTION public.search_trades(...)` with the full existing argument list, then recreate.
Re-grant `EXECUTE` to `authenticated` after; the drop takes the grant with it.

New parameter, appended last so existing positional callers are unaffected:

```
p_apprentice boolean DEFAULT false
```

`false` → only rows where `is_apprentice = false` (**preserves today's Discovery result set
exactly**). `true` → only apprentices. Projection gains `is_apprentice`,
`apprenticeship_stage`, `site_tickets`. Rates stay gated by `hourly_rate_visible` as they are
now.

### 4.7 `profile_completeness`

The view gains apprentice-aware slots so the existing completeness banner does not tell an
apprentice to add an hourly rate. When `is_apprentice`: count `about`, `site_tickets` non-empty,
`resume_path` present, `portfolio_urls` non-empty; drop the rate slot.

---

## 5. Design direction

**Register:** product (`PRODUCT.md`). Design serves the task; the tool disappears into it.

**Color strategy:** Restrained, per the product register floor. Orange `c.action` stays on the
save CTA only. The one place color carries meaning is the ticket tier, and it is never color
alone (§7).

**Scene sentence:** A seventeen-year-old sits on the tailgate of a ute at 6:40am in flat
overcast light, phone in one hand, filling this in before the gate opens, hoping it is enough
to get a callback. That forces **light theme canonical** (matches the shipped default), high
contrast, large targets, and zero decorative motion.

**Anchor references:** the existing Jobdun verification wizard (the tone to match), Seek's
profile completeness rail (the progress logic, not the look), a physical site induction
clipboard (the ticket checklist's mental model).

**Visual direction probes: skipped.** The gating condition in `impeccable shape` Phase 1.5 is
that the work be directionally ambiguous. It is not — the visual lane is fully pinned by the
Figma-derived design system (`MASTER.md` tokens, Archivo/Inter ramp, Aggressive Flat, the
`AppRadius` split). Generating alternate lanes would be exploring a decision that is already
locked.

**Taste-skill note:** `gpt-taste`, `design-taste-frontend`, `high-end-visual-design` and
`stitch-design-taste` were reviewed and are **not** applied. They target landing pages,
portfolios and GSAP-driven web motion; `design-taste-frontend` explicitly scopes itself out of
"dashboards, data tables, multi-step product UI". Applying them here would fight both
`PRODUCT.md` and `MASTER.md`.

---

## 6. Screens and layout

### 6.1 Profile edit hub (`profile_edit_hub_page.dart`)

Rows are conditional on `is_apprentice`:

```
Identity & photo              Ken Garcia
Trade & experience            Carpenter · 2nd year          ← gains the apprentice toggle + stage
Rates                         $45–55/hr                     ← HIDDEN when is_apprentice
Tickets & licences            4 tickets · 1 verified        ← NEW, shown for all trades
Resume                        resume-ken.pdf                ← NEW, apprentices only in v1
Base location                 Blacktown, NSW
About                         Second year chippy, keen to…
```

`Tickets & licences` is deliberately shown to **every** trade, not just apprentices. Qualified
tradies hold these tickets too, and scoping it to apprentices would be an arbitrary limit.

### 6.2 Apprentice toggle and stage (inside `trade_details_sheet.dart`)

```
TRADE
[ Carpenter                                ▾ ]

[✓] I'm looking for an apprenticeship

STAGE
( ) Pre-apprentice      ( ) 1st year
(•) 2nd year            ( ) 3rd year
( ) 4th year
```

The stage group appears only when the toggle is on, with a 150ms height transition. When the
toggle flips **off**, `apprenticeship_stage` is cleared in the same patch so a stale stage
cannot resurface later.

### 6.3 Tickets sheet — the checklist

The user asked for "maybe like a dropdown with some tick options". **Building a grouped
checklist in a bottom sheet instead**, and the reason matters: a dropdown holding nine items
with labels as long as "EWP High Risk Work Licence (WP, boom 11m+)" truncates on a phone, hides
the verified state, and gives a 24dp hit target. A 48dp list row shows the full label, the unit
code, and the tier badge at once. Same tick-the-boxes mental model, correct control for the
platform. `showJSheet`, never `showModalBottomSheet`.

```
┌─────────────────────────────────────────────┐
│              Tickets & licences             │
│  Tick what you hold. Upload to verify.      │
│                                             │
│  INDUCTION                                  │
│  [✓] White Card                 ┌─────────┐ │
│      Construction Induction     │VERIFIED │ │  ← locked on, green
│      CPCCWHS1001                └─────────┘ │
│                                             │
│  SAFETY                                     │
│  [✓] First Aid                              │
│      HLTAID011                              │
│  [✓] Working at Heights                     │
│      RIIWHS204E                             │
│  [ ] Confined Space                         │
│      RIIWHS202E                             │
│                                             │
│  LICENCES                                   │
│  [ ] EWP Yellow Card       boom under 11m   │
│  [ ] EWP Licence (WP)      boom 11m+        │
│  [ ] Dogging (DG)                           │
│  [ ] Rigging (RB / RI / RA)                 │
│                                             │
│  TRANSPORT                                  │
│  [✓] Driver Licence                         │
│                                             │
│         [    SAVE TICKETS    ]              │
└─────────────────────────────────────────────┘
```

- Tick box: sharp square, `AppRadius.badge` (4r), `c.borderStrong` unticked, `c.action` fill
  ticked with `c.onAction` glyph. Not Material's rounded checkbox.
- A verified row's tick is **locked on** and shows the green `VERIFIED` chip. Tapping it
  explains why it cannot be unticked rather than silently ignoring the tap.
- Group headers use `labelSmall` (Inter 700 / 11 / +0.5 tracking), `c.text3`.
- Rows are 48dp minimum. Long labels wrap to a second line rather than ellipsing.

### 6.4 Ticket display on the profile — two tiers

Shared widget used on the apprentice's own profile, the public profile, and the applicant
detail page.

```
TICKETS & LICENCES

┌──────────────────┐  ┌──────────────────┐
│ ✓ WHITE CARD     │  │ ○ FIRST AID      │
└──────────────────┘  └──────────────────┘
   green, verified       grey, self-declared

┌──────────────────────┐  ┌──────────────────┐
│ ○ WORKING AT HEIGHTS │  │ ○ DRIVER LICENCE │
└──────────────────────┘  └──────────────────┘

Grey tickets are self-declared. Sight the card before site induction.
```

- Verified: `c.verifiedBg` fill + `c.verifiedTx` text + filled tick glyph + the word VERIFIED in
  the accessible label. Never `withValues(alpha:)` — `MASTER.md` bans that, it lands near 2:1.
- Self-declared: `c.surfaceRaised` fill + `c.text1` text + hollow ring glyph.
- Verified chips sort first.
- The disclaimer line renders **only for the builder-facing view**, once, in `bodySmall` /
  `c.text2`. `MASTER.md` bans handholding microcopy; this earns its place as a safety line, so
  it stays one factual sentence with no hedging.

### 6.5 Resume row

```
RESUME

┌───────────────────────────────────────────┐
│  📄  resume-ken.pdf                       │
│      Uploaded 30 Aug 2026 · 240 KB        │
│                          REPLACE   REMOVE │
└───────────────────────────────────────────┘

Only builders you've applied to can open this.
```

Empty state: filled `UPLOAD RESUME` button plus the same privacy line. The line is required
copy, not decoration — a user uploading a document with their home address needs to know who
sees it before they tap.

**Gotcha, already hit once in this repo:** `file_picker` returns `bytes` and a null `path` on
web (see the comment in `manual_upload_sheet.dart:127`). The upload path must branch, exactly
as that sheet does, or the admin/web build breaks.

### 6.6 Apprentice profile view

Branches inside the existing `trade_public_profile_page.dart` rather than forking a new page.

```
[ Avatar ]  Ken Garcia
            2ND-YEAR CARPENTRY APPRENTICE        ← chip, c.surfaceRaised
            Blacktown, NSW · 4 km away

[ ✓ WHITE CARD ] [ ○ FIRST AID ] [ ○ DRIVER LICENCE ]

LOOKING FOR
Carpentry apprenticeship · Available from 15 Sep

ABOUT
Second year chippy at TAFE NSW, two days a week on site…

TICKETS & LICENCES        (§6.4 two-tier block)

PHOTOS                    (existing PortfolioStrip, readOnly)

RESUME                    [ VIEW RESUME ]  or  locked state

REVIEWS                   (empty until they complete work)
```

Suppressed for apprentices: hourly rate, public liability, crew size, and the **jobs-completed
stat**. A hard "0 JOBS COMPLETED" on a first-year's profile is a discouraging number that
carries no information. Replaced with ticket count and available-from.

### 6.7 Discovery toggle

```
┌─────────────┬─────────────┐
│   TRADES    │ APPRENTICES │     ← segmented, selected = c.action
└─────────────┴─────────────┘

● Jake M.                    4 km
  Carpentry · 2nd year
  ✓ White Card  ○ +3 tickets

● Sam T.                    11 km
  Electrical · 1st year
  ○ 3 tickets
```

The toggle drives `TradeSearchFilter.apprenticesOnly`, which maps to `p_apprentice`. Switching
modes resets pagination and refetches. Existing filters (radius, rating, available-only) apply
unchanged; the rating filter is a no-op in apprentice mode in practice since apprentices have
no reviews yet, so it is hidden there.

---

## 7. Accessibility

Non-negotiable per `MASTER.md` and `PRODUCT.md`; WCAG 2.2 AA.

- **Never color alone.** Verified vs self-declared is carried by glyph (filled tick vs hollow
  ring) **and** by text in the semantic label, not just green vs grey.
- Semantic pairs only: `c.verifiedBg` / `c.verifiedTx`, `c.surfaceRaised` / `c.text1`. No alpha
  compositing on chips.
- **Anything sitting on `c.surfaceRaised` carries `c.text1` only.** `app_colors.dart:105,110`
  pins `text2` at 4.04:1 and `text3` at 3.54:1 on that ground, both below the 4.5 body floor.
  This binds the self-declared ticket chip, the `2ND-YEAR CARPENTRY APPRENTICE` header chip, and
  the resume row. Group headers in the tickets sheet may use `c.text3` because the sheet ground
  is `c.surface`, not `c.surfaceRaised`.
- 48dp minimum on every ticket row, toggle, and segmented control segment.
- Text scale honoured (clamped 0.9–1.3 globally); ticket rows must grow with it, so no fixed
  row heights — use `constraints: BoxConstraints(minHeight: 48)`.
- Reduced motion: the stage-group reveal and the segmented-control slide both need a
  `MediaQuery.disableAnimations` branch.
- Screen reader: each ticket row announces "White Card, verified, selected" / "First Aid,
  self-declared, not selected".
- No new color tokens are expected. If one is added, `test/colors_contrast_test.dart` fails
  until it has a guard pair in both themes.

---

## 8. Key states

| Surface | State | Behaviour |
|---|---|---|
| Tickets sheet | Loading | `JSkeletonList` shaped like ticket rows. Never a spinner. |
| Tickets sheet | Reference fetch failed | Inline retry row; the sheet still shows already-selected slugs from the profile so nothing looks lost. |
| Tickets sheet | Unsaved changes + drag-dismiss | `discard_changes_sheet.dart`, wired from first build (`modal_bottom_sheet` drag bypasses `PopScope` — the known trap from the quick-edit sheets work). |
| Tickets block | Empty | Hidden entirely on the public profile. On the owner's profile: single `ADD TICKETS` row. |
| Resume | Uploading | Inline determinate `LinearPercentIndicator`, not a page spinner. |
| Resume | Too large / wrong type | Inline error under the row, naming the actual limit ("PDF, DOC or DOCX up to 5 MB"). |
| Resume | Viewer has no relationship | Locked row: "Resume available after they apply to one of your jobs." No button. |
| Resume | Signed URL expired mid-session | Re-mint on tap rather than surfacing a 403. |
| Discovery | Apprentice mode, no results | Lottie + `NO APPRENTICES NEARBY` + `WIDEN SEARCH` CTA. Never blank, never text-only. |
| Profile | Toggle on, nothing else filled | Completeness banner lists the apprentice slots, not the rate slot. |

---

## 9. Copy

Voice per `MASTER.md`: declarative, no hedging, no friendly microcopy, ALL CAPS on buttons
applied by widget transform (never typed into the string).

| Surface | Copy |
|---|---|
| Toggle | `I'm looking for an apprenticeship` |
| Stage options | `Pre-apprentice` · `1st year` · `2nd year` · `3rd year` · `4th year` |
| Header chip | `2ND-YEAR CARPENTRY APPRENTICE` |
| Tickets sheet title | `Tickets & licences` |
| Tickets sheet subtitle | `Tick what you hold. Upload to verify.` |
| Save button | `SAVE TICKETS` |
| Builder disclaimer | `Grey tickets are self-declared. Sight the card before site induction.` |
| Verify nudge | `Upload your White Card to get the verified badge` |
| Resume empty | `UPLOAD RESUME` |
| Resume privacy | `Only builders you've applied to can open this.` |
| Resume locked | `Resume available after they apply to one of your jobs.` |
| Job chip | `OPEN TO APPRENTICES` |
| Discovery empty | `NO APPRENTICES NEARBY` / `WIDEN SEARCH` |

Banned here as everywhere: "You're all set!", "Almost there!", "Great job!", em dashes in UI
strings.

---

## 10. Module breakdown

Every file targets ≤ 400 LOC, hard ceiling 500. `presentation/` imports `domain/` only; the
provider file is the sole seam that wires `data/` in. Use cases return
`Future<Either<Failure, T>>`.

### Migrations (`supabase/migrations/`, rollbacks in `supabase/rollbacks/`)

1. `20260830000001_apprentice_columns.sql` — §4.2
2. `20260830000002_site_tickets.sql` — §4.3 table, RLS, seed
3. `20260830000003_resume_storage_access.sql` — §4.5 additive policy
4. `20260830000004_search_trades_apprentices.sql` — §4.6 DROP + recreate + re-GRANT
5. `20260830000005_jobs_open_to_apprentices.sql` — §4.4
6. `20260830000006_profile_completeness_apprentice.sql` — §4.7

### Profile feature

**domain/** `entities/site_ticket.dart`, `entities/apprenticeship_stage.dart` (enum +
exhaustive label extension), extend `entities/trade_profile.dart` (5 fields, all added to
`props`), extend `entities/profile_patches.dart` (`ApprenticeshipPatch`, `TicketsPatch`,
`ResumePatch`), `usecases/get_site_tickets.dart`, `usecases/save_tickets.dart`,
`usecases/upload_resume.dart`, `usecases/delete_resume.dart`, `usecases/get_resume_url.dart`,
extend the repository contract.

**data/** `models/site_ticket_model.dart`, extend `models/trade_profile_model.dart`, extend
`models/profile_patch_mappers.dart`, `datasources/site_tickets_remote_datasource.dart`, extend
`datasources/profile_remote_datasource.dart` (resume upload / delete / signed URL), extend
`repositories/profile_repository_impl.dart`.

**presentation/** `providers/site_tickets_provider.dart` (public provider, overridable), extend
`providers/profile_provider.dart`, `widgets/edit_sheets/tickets_sheet.dart` +
`tickets_sheet_rows.dart` (split up front — one sheet with nine grouped rows and two tiers will
exceed 400 LOC otherwise), `widgets/edit_sheets/resume_sheet.dart`,
`widgets/ticket_chip_wall.dart`, `widgets/ticket_chip.dart`, `widgets/resume_row.dart`,
`widgets/apprentice_header_chip.dart`, extend `pages/profile_edit_hub_page.dart`,
`pages/trade_public_profile_page.dart`, `pages/profile_page_trade.dart`, and
`widgets/edit_sheets/trade_details_sheet.dart`.

One widget per file. No methods returning `Widget`.

### Discovery feature

Extend `entities/trade_search_filter.dart` (`apprenticesOnly`),
`entities/trade_search_result.dart` (`isApprentice`, `apprenticeshipStage`, `siteTickets`), the
datasource, repo, and use case; add `widgets/discovery_mode_toggle.dart`; extend
`pages/discovery_page.dart` and `widgets/discovery_tradie_tile.dart`.

### Jobs feature

Extend `entities/job.dart` and `models/job_model.dart` (`openToApprentices`), the create-job
form, and the job card chip. **`job_remote_datasource.dart:32` hand-writes its column
projection** — the new column must be added there or `JobModel.fromJson` reads a missing key.
This is the exact class of bug already recorded in the jobs field gotchas.

### Tests (written first, per `superpowers:test-driven-development`)

- `trade_profile_model_test.dart` — round-trip including the five new fields and an empty
  `site_tickets`.
- `apprenticeship_stage_test.dart` — label totality; adding an enum value must fail the test.
- `site_ticket_model_test.dart` — DB row → entity, including null `doc_type`.
- `tickets_sheet_test.dart` — tick/untick, verified row locked, discard-changes on drag.
- `ticket_chip_test.dart` — verified vs self-declared render distinctly **without** relying on
  color (glyph + semantics label assertions).
- `resume_upload_test.dart` — size and type rejection, web `bytes` branch.
- `discovery_apprentice_filter_test.dart` — `apprenticesOnly` maps to `p_apprentice`, and the
  default filter still excludes apprentices.
- `job_model_test.dart` — `open_to_apprentices` round-trip, default false.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| `search_trades` DROP + recreate briefly breaks Discovery mid-deploy | Single transaction; migration runs during a quiet window. Rollback script recreates the old signature. |
| Adding apprentices to Discovery's default result set would silently change today's screen | `p_apprentice` defaults to `false`, which filters to `is_apprentice = false`. Covered by a test asserting the default excludes apprentices. |
| Only White Card can reach Verified in phase 1, so eight chips are permanently grey | Accepted and stated in the UI. Phase 2 lights up the rest. The nudge renders only where `doc_type IS NOT NULL`, so no dead-end taps. |
| Resume holds a minor's PII | Private bucket + relationship-gated policy + explicit privacy copy at the point of upload. |
| Ticket sheet grows past 500 LOC | Split into sheet + rows from the first commit, not after. |
| `file_picker` null `path` on web | Branch on `bytes`, mirroring `manual_upload_sheet.dart`. |
| No Android emulator on this Mac (per prior sessions) | `CLAUDE.md` mandates real emulator screenshots for UI changes. **Resolve before implementation starts** — see Open questions. |

---

## 12. Out of scope (phase 2)

- Builders posting a dedicated "Apprenticeship" job type and apprentices getting a filtered feed.
- Verified review paths for the remaining eight tickets (`ticket_slug` on
  `verification_documents` + admin console support in the separate `jobdun-admin-web` repo).
- Ticket expiry dates and lapse warnings.
- Resume parsing or auto-fill.
- Apprentice-specific reviews or RTO / TAFE enrolment verification.
- Making `requires_verified` / `requires_public_liability` actually enforce (§3) — a
  pre-existing gap, tracked separately.

---

## 13. Open questions

1. **Emulator access.** `CLAUDE.md` requires real emulator screenshots before any UI change is
   called done, and prior sessions recorded no AVD on this Mac. Confirm whether
   `scripts/capture_app_screenshots.sh` can run here, or whether verification happens on the
   physical iPhone via `scripts/deploy-iphone.sh`.
2. **Staging backend.** Prior sessions recorded the staging project as paused. These six
   migrations need somewhere to be exercised before prod. Confirm staging is resumable.
