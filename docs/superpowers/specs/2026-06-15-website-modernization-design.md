# Jobdun marketing site — modernization & light/dark redesign

**Date:** 2026-06-15
**Branch:** `feat/website-marketing-site`
**Surface:** `lib/website/` (Flutter Web, `jobdun.com.au`) — separate entrypoint from the mobile app and admin console.
**Process:** `superpowers:brainstorming` + `ui-ux-pro-max` (+ `impeccable` taste pass during build).

## Goal

Turn the existing single-page marketing site into a modern, accessible, light/dark
website tuned for reach in the Australian construction-trades market — without
abandoning Jobdun's brand DNA.

## Approved decisions (user, 2026-06-15)

1. **Theme default — follow system + toggle.** First visit respects the visitor's
   OS light/dark preference. A sun/moon toggle in the nav overrides it; the override
   is persisted (browser `localStorage` via `shared_preferences`).
2. **Visual register — "Refined flat+".** Flat stays the base (honours the app's
   aggressive-flat DNA). Selective, tasteful depth is added only where it earns
   attention: a frosted-glass floating nav, a subtle hover-lift on cards (no resting
   shadow), and exactly one soft orange radial glow behind the hero phone.
3. **Trust / social proof — added.** New animated stat band + AU trade-category chips
   + testimonial cards. Figures and quotes are clearly-labelled placeholders the
   client can swap for real ones.

## Design direction — "Job-site precision, marketing polish"

Brand DNA kept: safety orange `#F97316`, Oswald (display) + Open Sans (body), the
blueprint-grid motif, AU-trades voice ("only verified, no timewasters", "the people
who actually build Australia").

### Section flow

```
Glass floating nav (theme toggle live)
  → Hero (soft orange glow behind phone)
  → Trust stat band            (NEW — animated count-up)
  → Built for
  → Values strip
  → How it works
  → Roles
  → Trade categories + testimonials  (NEW)
  → App gallery
  → Bottom CTA
  → Footer
```

## Architecture

- **`presentation/providers/theme_mode_provider.dart`** — `Notifier<ThemeMode>`.
  Builds with `ThemeMode.system`; `Future.microtask` loads the saved override from
  `shared_preferences`. `toggle()` cycles light↔dark and persists. (Riverpod 3
  `NotifierProvider`, matching `active_section_provider.dart`.)
- **`app/website_app.dart`** — `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()`,
  `themeMode: ref.watch(themeModeProvider)`. (`AppTheme.light()` already exists and is
  WCAG-verified by `test/colors_contrast_test.dart`.)
- **`main_website.dart`** — stop hardcoding a dark system-overlay; let the app theme
  drive the status/nav bar so a light-mode visitor doesn't get a dark bar.
- **New widgets (one per file, ≤400 LOC each):**
  - `widgets/theme_toggle.dart` — accessible sun/moon button (Semantics, focusable, 44px).
  - `widgets/reveal_on_scroll.dart` — fade-slide reveal via `flutter_animate`, gated by
    `MediaQuery.disableAnimations` / `prefers-reduced-motion`.
  - `widgets/count_up_text.dart` — animated integer count-up (reduced-motion → final value).
  - `sections/trust_stats_section.dart`, `sections/trade_categories_section.dart`,
    `sections/testimonials_section.dart`.

## Constraints honoured

- **Design lint** (`scripts/validate.sh`) greps target `lib/features/` only — the website
  at `lib/website/features/website/` is out of scope, so the gradient/shadow/hardcoded-color
  bans don't block the glass nav or orange glow. The `GoogleFonts.` ban covers all of
  `lib/`, so website code uses `Theme.of(context).textTheme` only — never `GoogleFonts.*`.
- **File-size budget** (≤400 target / 500 hard ceiling) and **single-widget-per-file** apply
  to website files via the `find lib` loop + `analysis_options.yaml`.
- **No new packages** — `shared_preferences`, `flutter_animate`, and `gap` are already deps.

## Accessibility (target WCAG 2.2 AA)

- All four colour pairs already pass the contrast guard in both themes.
- `Semantics` headers for section titles; `Semantics(image, label:)` / alt text on every
  screenshot; visible focus rings; 44px+ targets; readable line-length (≤75ch).
- All motion gated behind reduced-motion. Count-up + reveal skip to final state when disabled.

## Verification

`flutter analyze --no-fatal-infos`, `dart format`, `flutter test test/colors_contrast_test.dart`,
file-size check on new files, rebuild on `localhost:8088`, screenshot light + dark.

---

## Competitive research (2026-06-15) — what the AU market does, and the gap

Researched the platforms a tradie or builder actually compares Jobdun against:

| Platform | Model | What tradies pay | Verification |
|----------|-------|------------------|--------------|
| **hipages** (#1) | Homeowner → tradie leads | $200–600/mo subscription **+ $30–80+ per lead**; lead sold to 3+ tradies | ABN + licence + 2 references + ID + insurance |
| **Oneflare** | Pay-per-lead | Per accepted lead | Verified-tradie badge |
| **ServiceSeeking** | Subscription | From ~$66/mo unlimited quoting | Profile checks |
| **Airtasker** | Task marketplace | **~15% service fee** on completed task | Light (ratings-based) |
| **Yakka / Hiya Mate / Rank First** | Builder ↔ crew labour marketplace (closest to Jobdun) | Varies | "Verified workers", compliance |

**The gap.** Every major platform monetises the tradie — lead fees, subscriptions, or a cut of pay
— which is the #1 documented tradie complaint. Verification is table-stakes everyone claims but
few *prove*. Jobdun's "no fees, no take rate, verified before contact" is the strongest wedge, and
the page asserted it once without backing it up.

**Additions driven by the research (both grounded, no competitor names — "lead-buying platforms"):**
- `sections/comparison_section.dart` — two cards (Jobdun vs typical lead-buying platforms) across 6
  rows: free to apply, no subscription, 0% take rate, lead not shared, talk to the builder direct,
  licence + ABN verified before contact. Placed after the features grid (proves "no fees").
- `sections/trust_safety_section.dart` — "What 'verified' actually means": a concrete checklist
  (licence cross-checked vs the national register, current ABN, ID confirmed, insurance on file,
  reviews from real completed jobs). Turns the repeated verification claim into proof. Placed after
  the built-for editorial.

Sources: hipages (Thriday/CaptainFI breakdowns), tradiescaler hipages-vs-oneflare, Choice find-a-tradie
review, reviewrumble platform comparison, tdqs/tradielead app round-ups, Yakka/Hiya Mate/Rank First.
