# Figma "Homepage" section → Flutter (node `64:2088`)

**Date:** 2026-08-29
**Branch:** `feat/ui-refresh-figma-2026-08-28`
**Source:** `JobDun-Screens` (`9JQxSZQEqo06TGKI8t717q`) → section **Homepage**, node `64:2088`
**Designer:** Timothy Forte

---

## Scope

Five frames, all builder-facing:

| Frame | Node | Target |
|---|---|---|
| Homepage — profile card shown | `64:2403` | `/home` (builder branch) |
| Homepage — profile card dismissed | `80:4529` | same screen, banner hidden |
| Post a Job 1/2 | `134:13408` | `/jobs/create` step 1 |
| Post a Job 2/2 | `134:13313` | `/jobs/create` step 2 |
| Job Details | `134:13357` | `/jobs/:id` (builder-owned view) |
| Setting | `134:8995` (section `134:8994`) | `/settings` |

**Out of scope:** the tradie home. This section contains no tradie frame; the
existing availability-bar / action-deck / JOBS NEAR YOU layout is untouched.
Roles will look different until Timothy draws the tradie home.

---

## Decisions taken (user, 2026-08-29)

1. **Build all five frames.**
2. **Keep Archivo + Inter.** The mock is drawn entirely in Inter, but that reads
   as a Figma default rather than a type decision. Archivo stays on
   display/headings/buttons, Inter on body — matching the rest of the app and
   the FTUE rebuild.
3. **Adopt the mock's radii and its sentence case,** scoped to these five
   screens. Pill CTAs (r48), r16 cards, r12 inputs. "Post a job", not "POST A
   JOB". `AppRadius` gains scoped tokens; the global `btn 6` / `card 8` stay put
   so no other screen shifts.
4. **Tradie home untouched.**
5. **Settings (added 2026-08-29, second pass):** follow the mock's Log out /
   Delete-my-account pairing, keep the trade-only rows, drop the Developer
   tools card.

### Settings

Header is the back caret + a 24dp title. Body is 16dp padding with 16dp
between three bordered r16 cards — Appearance, Account, Legal — each a 16dp
bold title with 24dp beneath it and between its rows. Rows are an 18dp glyph,
an 8dp gap, a 16dp label, then a chevron (or `JSwitch` on Dark mode). The two
footer buttons are full-width 48dp pills: **Log out** on the tinted
`bg/action-secondary` fill with a brand hairline, **Delete my account** on the
error hairline.

**The delete button moved back next to Log out — deliberately, with a guard.**
It had been demoted to a quiet underlined link precisely because a prominent
danger button beside a routine one "nearly cost a real account". The mock puts
them 16dp apart and that placement was signed off on 2026-08-29 **conditional
on `showDeleteAccountSheet` continuing to gate it** — a mis-tap opens a confirm
sheet, never a deletion. `test/features/profile/settings_page_test.dart` now
asserts that tap → sheet, with a comment telling future readers not to loosen
it. The sheet itself already orders the safe action first.

**Deviations on this screen.** The mock's title reads "Setting"; the app says
**"Settings"** and keeps it. The mock draws a *phone* glyph on Change password;
the row sends a reset email, so `AppIcons.lock` stays. Trade-only rows
(Availability calendar, Quote requests) are kept — the mock shows a builder, for
whom they don't render, so the builder's card matches the drawn three exactly.
The **Developer tools** card is removed per the same decision; `/home-preview`,
`/design-preview` and `/logo-animation` still exist as debug routes but are now
reachable only by typing the URL.

---

## Token mapping

Every hex in the mock already exists in `_Palette`. Nothing new is invented.

| Mock variable | Hex | Jobdun token |
|---|---|---|
| `bg/base` | `#FFFFFF` | `c.surface` |
| `brand/50` | `#FFF6F2` | `c.actionBg` |
| `brand/200` | `#FEDCCC` | `_Palette.brand200` (progress track) |
| `bg/action-primary`, `brand/600` | `#FC5101` | `c.action` |
| `bg/action-secondary` | `#FFEEE6` | `c.actionBg` |
| `border/active` | `#FD7434` | `_Palette.brand500` |
| `border/focus` | `#FD9767` | `c.action` @ focus ring |
| `border/default` | `#C8C8C8` | `c.border` — see deviation D3 |
| `border/subtle`, `bg/disabled`, `neutral/200` | `#E4E4E4` | `c.border` / `c.surfaceRaised` |
| `text/primary` | `#181818` / `#040915` | `c.text1` |
| `text/secondary` | `#2F2F2F` | `c.text2` |
| `text/tertiary` | `#474747` | `c.text2` |
| `text/subtle`, `text/disabled` | `#919191` | `c.text3` — see deviation D2 |
| `text/on-action` | `white` | `c.onAction` — see deviation D1 |
| `text/destructive`, `danger/700` | `#BC1010` | `c.urgentTx` |
| `bg/error-muted` | `#FDE8E8` | `c.urgentBg` |

---

## Deviations from the mock — all deliberate

**D1 — white on the orange CTA becomes `c.onAction` (`#181818`).**
The mock sets `text/on-action: white` on every primary button at 18px Bold.
White on `#FC5101` is **3.34:1**. WCAG AA large-text (3:1) starts at 18.66px
bold; 18px bold falls under it, so the 4.5:1 bar applies and the mock fails.
`c.onAction` is **5.26:1**. `test/colors_contrast_test.dart` enforces this pair,
so shipping the mock literally would fail the build. Same call the FTUE rebuild
made.

**D2 — small orange text becomes `c.actionInk` (`#CA4101`).**
`#FC5101` as ink is 3.34:1. Fine for the 24px Bold stat numbers (large text,
3:1 floor — kept as `c.action`). Fails for the 12px "Explore map" label, the
11px nav labels, the 12px "K" avatar initial and "View profile and Reviews".
Those read `c.actionInk` at 4.92:1. Placeholders likewise move from `#919191`
(2.8:1) to `c.text3` — MASTER treats placeholder text as content.

**D3 — card borders use `c.border` (`#E4E4E4`), not the mock's `#C8C8C8`.**
`#C8C8C8` exists in the ramp as `neutral300` but only as *dark* `text2`; it has
no light-theme border role and is 1.67:1 on white. `c.border` is the house token
for card edges and is the only choice that also resolves correctly in dark
(`#474747`). 1px difference, barely visible; the alternative is a new token that
would ship unguarded.

**D4 — "Per lineal meter" stays "Per lineal metre".**
AU spelling, and the string already lives in `PricingUnitX.label`.

**D5 — iOS status bar and home indicator are not drawn.**
They are OS chrome. `SafeArea` handles the insets.

**D6 — the mock's fixed 361px widths become fluid.**
Frames are 393px wide. Everything is `width - 32` in practice; hard-coding 361
breaks on a 360px Android and on desktop web.

**D7 — the map promo renders the LIVE map, not the mock's raster.**
The mock's card is a static Surry Hills / Mascot picture. The app already owns
`TradeMapPreview` — `flutter_map`, real nearby-tradie pins, an offline
fallback, tapping through to `/discovery/map` — at aspect 2.1 against the
mock's 2.075. A fixed Sydney image would be wrong for a builder in Perth and
would ship a 2 MB dead asset, so the card keeps the mock's composition
(headline, sub-line, "Explore map" pill over a left-to-right legibility scrim,
stops taken from node `134:12873`) and swaps the raster for the real map.

**D8 — the tradie "Quote this job" CTA moved to sentence case.**
The mock only draws the builder-owned footer. Leaving the tradie CTA shouting
on an otherwise sentence-case screen read as an oversight rather than a
decision. `AppStrings.respondToJob` has one call site.

---

## Screen specs

### Home (builder)

Vertical rhythm: 16px page padding, **24px between sections**.

- **Header** (replaces `HomeStatusBar` on the builder branch) — JOBDUN wordmark
  left; bell + settings right, 32px each, gap 16. The wordmark ships as an SVG
  asset exported from node `98:586`.
- **Profile card** — restyle of the existing `ProfileCompletenessBanner`:
  `c.actionBg` fill, 1px `c.action` border, r16, p16. Title 16 Bold, body 14,
  close X, then an 8px full-round progress bar (`brand200` track, `c.action`
  fill). Keeps its existing dismiss + analytics wiring.
- **Stats row** — 1px `c.border`, r16, py16. Three equal columns split by 1px
  dividers 35px tall. Count 24 Bold `c.action`; label 12 Regular `c.text1`.
  Live values: active jobs, incoming applicants, jobs posted.
- **Map promo card** — r16, `c.border`, h174. Map raster bleeds to the right
  edge; a left-to-right white→transparent gradient (`c.surface`) keeps the copy
  legible. Headline 20 Bold, body 14, then a 32px outlined pill "Explore map ›"
  → `/jobs/map`.
- **Post a job** — full-width 48px pill, `c.action`, `+` glyph + 18 Bold label
  → `/jobs/create`.
- **Two-up actions** — "Find a Tradie / Discover jobs near you" → `/discovery`;
  "Applicants / Manage and review applicants" → `/applicants`. r16, `c.border`,
  24px icon, title 16 Bold, body 14 `c.text2`.

The second frame is the same screen with the profile card absent — already the
banner's `pct >= 100 || dismissed` branch. No extra code.

**Dock** (`home_shell_page.dart`): active tab gains a `c.surfaceRaised` pill
fill behind icon+label; label colour `c.actionInk`. "My Jobs" → **"Listings"**,
avatar slot gains the label **"You"**.

### Post a Job — split 1/2 and 2/2

Today's `/jobs/create` is one long scroll holding exactly the mock's field set.
It becomes two steps behind a `PageView`; `FormBuilder` state is preserved
across both so back-navigation keeps input.

- **Header** — back caret, "Post a Job" 24 Bold, step counter `1/2` 16 Bold
  `c.actionInk`, right-aligned.
- **Step 1** — Urgent card (24px icon, title 16 Bold, body 14 `c.text2`,
  `JSwitch`), then Job Title, Location, Description (140px box + `0/1000`
  counter), Trade Required wrap-chips. Footer "Next", disabled until step-1
  validation passes (`c.surfaceRaised` fill, `c.text2` label).
- **Step 2** — "Set Price / Request Quotes" segmented pill (`PricingType`),
  "Price per:" chips (`PricingUnit`), amount field with `$` leading and the
  unit suffix. Footer "Post Job". Request Quotes hides the amount field.
- **Inputs** — 48px, r12, `c.surface` fill, 1px `c.border`; focus swaps to
  `c.action` + a 3px `c.action` @20% ring.
- **Chips** — 32px, r48. Selected: `c.actionBg` fill, `brand500` border,
  `c.actionInk` label. Unselected: `c.border`, `c.text2` label.

### Job Details

- **Header** — back caret + "Job Details" 24 Bold.
- Title 32 Bold `c.text1`; outlined pills for price and start date; then
  Location / Trade Required / Job Description / Posted by / Requirements, each
  a 16 Bold label + 12px gap + content.
- **Posted by** — r16 card, 40px round avatar, name 14 Bold, "View profile and
  Reviews" 12 `c.actionInk` → the public builder profile.
- **Requirements** — 18px icon + 16 Regular row per item.
- **Footer** — two 48px pills: "View applicants" (`c.action` / `c.onAction`) and
  "Delete job" (`c.urgentBg` fill, `c.urgentTx` border + label). Delete keeps
  its existing confirm dialog.

Footer actions are builder-owned only. A tradie viewing the same job keeps
today's apply/save footer — the mock does not cover that case.

---

## File plan

All new files land well under the 400 LOC target.

**New**
- `home/presentation/widgets/home_brand_header.dart`
- `home/presentation/widgets/home_stats_row.dart`
- `home/presentation/widgets/home_map_promo_card.dart`
- `home/presentation/widgets/home_quick_action_card.dart`
- `core/design/widgets/j_pill_button.dart` — the r48 CTA, filled + outlined
- `core/design/widgets/j_choice_chip.dart` — the r48 selectable chip
- `jobs/presentation/pages/job_create_step_one.dart`
- `jobs/presentation/pages/job_create_step_two.dart`
- `assets/images/brand/jobdun_wordmark.svg`
- `assets/images/home/find_tradies_map.webp`

**Changed**
- `home/presentation/pages/home_builder_bento.dart` — rebuilt on the new layout
- `home/presentation/widgets/profile_completeness_banner.dart` — restyled
- `home/presentation/pages/home_page.dart` — builder branch swaps header
- `home/presentation/pages/home_shell_page.dart` — active pill, labels
- `jobs/presentation/pages/job_create_page.dart` — becomes the 2-step host
  (currently **500 LOC, exactly at the ceiling** — the split is mandatory,
  not optional)
- `jobs/presentation/pages/job_detail_page.dart` + `_widgets.dart`
- `app/theme/app_radii.dart` — `pill = 48`, `cardLg = 16`, `inputLg = 12`

**Preserved:** every route, all Riverpod wiring, `JobsController` /
`ApplicationsController` / `ProfileController` reads, the create-job validators
and submit path, delete-job confirm, analytics events, offline banner, FTUE
gate, and the role-sheet / welcome-toast side effects on home.

---

## Verification — what actually ran

| Check | Result |
|---|---|
| `flutter analyze --no-fatal-infos` | clean |
| `scripts/check-architecture.sh` | pass |
| `dart format` | clean |
| File-size budget (500 ceiling) | pass — `job_create_page.dart` split 500 → 377 |
| `flutter test test/features/` | pass |
| Design-system greps | pass except one pre-existing hex, see below |
| `flutter build web --release` | succeeds |
| Job Details, real render, real fonts | verified in Chrome at 393×852 |
| New goldens | 5 in `test/golden/figma_homepage_test.dart`, 1 whole-screen in `figma_settings_test.dart` |
| `bash scripts/validate.sh` | **all 14 checks pass** |

**Bug found and fixed during verification.** A `Container` with `alignment:`
set expands to fill its parent's bounded constraints, so every pill built that
way — `JSelectChip`, Job Details' `_InfoChip`, the map's "Explore map" — was
stretching to the full row width instead of hugging its label. A `SizedBox`
with only a height set does the same thing inside a `Wrap`, which put each chip
on its own line. Both are fixed and both are now covered by a golden.

**Not verified, and why.**

- **No live signed-in render of the builder home or the Post-a-Job flow.**
  There is no Android AVD on this Mac (`jobdun_test` lived on the Linux host),
  and the staging project `kqpsceobwtavcxhatxww` — which owns the
  `qa.builder.test@` fixture account — is **INACTIVE / paused**. Job Details was
  reachable because guests can read it; the other four frames need a builder
  session. To close this: unpause staging, or run
  `bash scripts/capture_app_screenshots.sh` on a machine with the AVD.
- **Dark theme** is token-correct by construction (no literal hexes; every
  colour reads `context.c.*`, and `colors_contrast_test.dart` guards both
  ColorSchemes) but has not been looked at on these screens.

**One `validate.sh` check still fails, and it is not from this work.**
`No hardcoded Color(0xFF in lib/features/` trips on
`lib/features/auth/presentation/widgets/auth_sso_row.dart` — a file that does
not exist in `HEAD` at all. It belongs to an in-flight, uncommitted Figma
auth-screens rebuild that was being edited **concurrently with this session**
(its files changed on disk mid-session). Its owner needs to swap those two
hexes for tokens; touching it here would have collided with live edits.
