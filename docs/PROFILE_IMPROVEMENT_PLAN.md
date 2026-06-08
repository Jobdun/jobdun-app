# Profile Improvement Plan

> **Project:** Jobdun
> **Created:** 2026-06-08
> **Owner:** Ken
> **Status:** Proposal / suggestion catalogue — nothing built yet. This is the list to triage.
> **Companion docs:** `design-system/jobdun/pages/profile-dashboard.md` (the spec this page is *supposed* to meet), `design-system/jobdun/MASTER.md` (tokens).
>
> This file is the roadmap the profile-dashboard design doc already points at ("five-sprint roadmap for closing field coverage gaps") but which had never been written. It catalogues **every** suggestion from the 2026-06-08 audit so we can pick what actually matters before any code is touched.

---

## 1. Product thesis — what a profile is *for*

Jobdun is a two-sided marketplace. A profile is not an "account page"; it is a **trust-to-transaction instrument**. Its only job is to move one side from *"maybe"* to *"yes — I'll hire / I'll apply."*

So the design question is never "what fields exist" — it's:

> **Who reads this profile, what decision are they making, and what evidence do they need to say yes?**

### The three surfaces (and their current state)

| # | Surface | Who reads it | The decision | Status today |
|---|---------|--------------|--------------|--------------|
| 1 | **Own profile** `/profile` | The owner | "How do I look? What's costing me work?" | Built as a **settings screen** with a thin facts card |
| 2 | **Tradie seen by builder** `applicant_detail_page` | Builder | "Do I hire this person?" | The **richest** surface — about, quote, stats, verification. Missing: portfolio, reviews |
| 3 | **Builder seen by tradie** | Tradie | "Is this poster legit? Will I get paid?" | ❌ **Does not exist** — tradies apply blind |

Surface 3 is the biggest commercial gap. In trades, *"is this a real site and will I actually get paid"* is the #1 anxiety, and we give tradies nothing to vet a builder before they apply.

---

## 2. What each role actually cares about (priority order)

**A tradie's profile must prove (to a builder):**
1. Verified & licensed (trust floor)
2. Real reviews + rating **with count** (social proof)
3. **Photos of past work** (the single most persuasive element for trades)
4. Trade + years of experience
5. Rate & availability

**A builder's profile must prove (to a tradie):**
1. Legit business — ABN ✓ (already strong)
2. **Pays / treats crews well** — reviews *from tradies*
3. Track record — jobs posted, hires, in-business-since (✓)
4. Real contact + location

> Scorecard today: tradie page does 4 & 5 well, **omits 2 & 3 entirely**. Builder page does 1, 3, 4; **#2 doesn't exist at all.**

---

## 3. Audit findings (the gaps)

### 3.1 Product gaps

- **G1 — `/profile` is a settings screen, not a credibility surface.** More than half the screen is Appearance / Account / Legal settings + Sign out. It answers "manage my account," not "here's why I'm worth hiring."
- **G2 — Rich, persuasive data is modelled and editable but never displayed.** See the dead-data table below.
- **G3 — Reviews are invisible.** The whole reviews feature is built (`review_card.dart`, `reviews_provider.dart`, `/reviews` route) but the route renders **placeholder** data (`reviews_page.dart:69 _placeholderReview()`) and is **not linked** from the profile.
- **G4 — Portfolio is invisible on the view.** `PortfolioStrip` is only wired into the **edit** form (`profile_edit_form_fields.dart:390`), never the profile view.
- **G5 — Builders have zero social proof.** Builder rating/reviews are (correctly) dropped as phantom, but nothing replaces them.
- **G6 — No public builder profile.** Tradies cannot vet a job-poster before applying.
- **G7 — Spec ↔ code drift.** `profile-dashboard.md` already specifies Bio, Skills chips, Reviews section, Portfolio grid, a 3-column stats row, a 96dp own-profile avatar, and an incomplete-profile CTA. Almost none shipped.

### 3.2 Dead data paths (modelled + editable, never shown)

| Field (`TradeProfile` / `BuilderProfile`) | Editable? | Shown on `/profile`? | Persuasion value |
|---|---|---|---|
| `about` (bio / company story) | ✅ | ❌ | High |
| `portfolioUrls` (work photos) | ✅ (`PortfolioStrip` in edit) | ❌ | **Highest (tradie)** |
| reviews / `ratingCount` | feature fully built | ❌ | **Highest** |
| `crewSize` | ✅ | ❌ | Medium |
| `serviceRadiusKm` | ✅ | ❌ | Medium (relevance) |
| `isAvailable` / `availableFrom` | ✅ | ⚠️ banner reflects *verification*, not real availability | High |
| `hireCount` (builder) | ✅ | ❌ | High (builder trust) |
| `contactName` (builder) | ✅ | ❌ | Low/Medium |

### 3.3 Engineering / standards issues

- **E1 — `addPostFrameCallback` initial load.** `profile_page.dart:46` calls `loadProfile()` via `addPostFrameCallback`; CLAUDE.md forbids this ("initial-load triggers belong inside `Notifier.build()`"). Same anti-pattern in `reviews_page.dart:29`. **⚠️ Not as trivial as it looks** — moving the load into `ProfileController.build()` via `Future.microtask` makes the background load race `saveProfile`, and `ProfileState.copyWith` resets `error` by design, so the load's terminal update clobbers a just-set save error (caught by `state_mgmt_refactor_test.dart`). A safe fix needs reentrancy-safe load or error-preserving state. **Deferred** — see §9.
- **E2 — Heavy derivation in the widget.** `_BuilderProfile.build` computes contact fallbacks, ABR formatting, phantom-rating handling inline. Lift into the notifier so the widget just renders.
- **E3 — ~~`AppColors.*` static import in features.~~** **False positive (verified 2026-06-08):** `reviews_page.dart` imports `app/theme/app_colors.dart` only for the `context.c` extension (`JColorsX`) + `AppIconSize`, with **no** `AppColors.*` static references, so `validate.sh` does not flag it. The barrel-import migration (`core/design/colors.dart`) is a separate Sprint-B task, not a profile fix. **Dropped from scope.**
- **E4 — Half-built layers.** Per CLAUDE.md ("half-built layers are deleted, not left as documentation"), the orphaned reviews/portfolio wiring must be either finished (preferred) or removed.
- **E5 — File-size budget.** `profile_page.dart` is already split into 3 `part` files. Any new sections (portfolio, reviews, skills) should land as their own widget files under a `profile_view_widgets/` folder, not grow the parts past the 400/500 LOC budget.

---

## 4. Suggestion catalogue (THE list)

IDs are stable so we can tick/cut them. **Tier** = recommended order. **New BE?** = needs backend/migration work beyond Flutter.

### Master checklist

| ID | Tier | Suggestion | Role | Reuse / build | New BE? |
|----|------|------------|------|---------------|---------|
| S1 | 0 | Render `about` / company story | both | new `_AboutSection` | no |
| S2 | 0 | Wire `PortfolioStrip` (read-only grid) onto tradie view | tradie | reuse `portfolio_strip.dart` + `photo_view` | no |
| S3 | 0 | Real reviews preview on profile (kill placeholder) | both* | reuse `reviewsControllerProvider`, `ReviewCard` | no (tradie) / yes (builder) |
| S4 | 0 | Drive availability banner from real `isAvailable`/`availableFrom` | tradie | existing fields | no |
| S5 | 0 | Show `hireCount` + `contactName` on builder card | builder | existing fields | no |
| S6 | 1 | Split page: **My Profile (credibility)** vs **Settings** | both | restructure + maybe `/settings` route | no |
| S7 | 1 | Credibility header to spec (96dp avatar, verified ring, stats row w/ dividers) | both | per `profile-dashboard.md` | no |
| S8 | 1 | Incomplete-profile CTA banner (specific missing item) | both | uses `profile_completeness` | no |
| S9 | 2 | Skills / trade-category chips | tradie | reuse trade-category model | maybe (multi-select store) |
| S10 | 2 | Service area + radius + crew size line | both | existing fields | no |
| S11 | 2 | Rating block with star bar + **review count** | tradie | `flutter_rating_bar` + `ratingCount` | no |
| S12 | 2 | "Preview my public profile" affordance | both | reuses surface 2/3 | depends on S13 |
| S13 | 3 | **Public builder profile** a tradie opens from a job | builder→tradie | new route/page | yes |
| S14 | 3 | Builder reviews *from tradies* (social proof) | builder | rating trigger + UI | **yes** |
| S15 | 3 | Portfolio + reviews on `applicant_detail_page` | tradie→builder | reuse S2/S3 widgets | no |
| E1–E5 | ⚙️ | Engineering/standards fixes (section 3.3) | — | — | — |

\* Tradie reviews work today (real data via `reviewsControllerProvider`); builder reviews depend on S14.

---

### Tier 0 — Finish what's already built (highest payoff, lowest risk)

These are mostly *connecting existing code*. Big perceived-quality jump for little new surface area.

- **S1 — About / company story section.** Render `profile.about`. Tradie label `ABOUT`; builder label `ABOUT THE COMPANY`. Use `FieldLabel` + `bodyLarge` at `height: 1.55` (mirror the pattern already in `applicant_detail_page.dart:156`). Expandable past ~4 lines via the `expandable` package. Empty → hide section (no "add a bio!" begging copy — anti-pattern).
- **S2 — Portfolio grid on the tradie view.** Reuse `PortfolioStrip` (already built) as a read-only horizontal strip, or a 3-col grid for the owner. Each thumb wrapped in `Hero(tag: 'portfolio:<id>')` opening `PhotoViewGallery` (house rule). This is the **single highest-value tradie addition** — photos sell trades work.
- **S3 — Real reviews preview.** Replace the `_placeholderReview()` path. On profile, show the **top 2–3** `ReviewCard`s via `reviewsControllerProvider.loadFor(userId)` + a "SEE ALL (n)" row → existing `/reviews` route. Empty state: the existing `_Empty` ("No reviews yet"). *Tradie = ready now; builder = blocked on S14.*
- **S4 — Truthful availability banner.** The current banner conflates verification with availability. Split: a **verified** chip (its own thing) and an **availability** line driven by `isAvailable` / `availableFrom` ("Available now" / "Available from 12 Jun"). Amber `c.warning` for "booked until," green `c.available` for "available now."
- **S5 — Builder trust line.** Surface `hireCount` ("12 hires") as a third `JStatBadge` and `contactName` in the COMPANY DETAILS card.

### Tier 1 — Restructure the page (credibility first, settings last)

- **S6 — Separate credibility from settings.** Lead with the credibility block; push Appearance / Account / Legal to the bottom **or** move them to a dedicated `/settings` route reached from a single gear action in the header. Sign out lives in settings, not mid-profile. This is the structural fix behind G1.
- **S7 — Header + stats to spec.** Per `profile-dashboard.md`: 96dp own-profile avatar with a 2dp verified ring (`c.action` verified / `c.border` not), name in Oswald `titleLarge`, role/trade chip, and a **3-column stats row with 1dp dividers** (Inter Black numerics via `AppTypography.numeric()`). Optional count-up on enter (`flutter_animate`, 600ms) — respect reduced motion.
- **S8 — Incomplete-profile CTA.** The spec already designs it: a single card, 4dp orange left border, "YOUR PROFILE IS INCOMPLETE." + the **one** most-impactful missing item ("Add your licence to get more jobs.") + inline "ADD NOW". Drive from `profile_completeness`. **No progress rings inside the profile** (spec anti-pattern; the ring lives only on the `/home` banner).

### Tier 2 — New credibility content

- **S9 — Skills / trade chips.** Render selected trade categories as non-interactive chips (`c.surfaceRaised` bg, `c.text2`, wrap layout). Needs the data to be a multi-select; today `primaryTrade` is single + `tradeOther`. Decide: keep single-trade or add a `skills`/`secondary_trades` field (backend).
- **S10 — Service area line.** "Services within 50 km of Parramatta" from `serviceRadiusKm` + base suburb; crew size ("Crew of 3") from `crewSize`. Cheap relevance/scale signals.
- **S11 — Rating block.** `flutter_rating_bar` (star `c.star`, empty `c.border`) + numeric average + **`(24 reviews)`**. Today only the bare number shows; the count is the credibility multiplier.
- **S12 — "Preview public profile."** A header affordance so owners see exactly what the other side sees (drives them to fill gaps). Depends on the public surfaces existing.

### Tier 3 — Close the marketplace trust gap (multi-sprint)

- **S13 — Public builder profile.** New route (e.g. `/builders/:id` or a sheet) opened from a job card / job detail **before** a tradie applies: company, ABN ✓, in-business-since, jobs posted, hires, location, about, and (once S14 lands) reviews from tradies. This is the missing surface 3.
- **S14 — Builder reviews from tradies.** Extend the rating trigger to write `builder_profiles.average_rating` / `rating_count` (today it only updates `trade_profiles`). Without this, builders have no social proof — the biggest tradie-side trust hole. **Backend migration required.**
- **S15 — Enrich `applicant_detail_page`.** Once S2/S3 widgets exist, drop portfolio + reviews into the builder's view of a tradie (currently it shows about/quote/stats/verification but no work photos or reviews). Also resolves the `TODO(availability-calendar)` at `applicant_detail_page.dart:179`.

### Engineering / standards (do alongside, not after)

- **E1** — Move `loadProfile()` into the notifier's `build()` (`Future.microtask` pattern); drop `addPostFrameCallback`. Same for `reviews_page.dart`.
- **E2** — Lift `_BuilderProfile` derivation into the profile notifier / a view-model so the widget only renders.
- **E3** — Replace the `AppColors.*` import in `reviews_page.dart` with `context.c` tokens.
- **E4** — Decide finish-vs-delete on each orphaned widget; this plan assumes **finish**.
- **E5** — New sections land as their own files under `profile_view_widgets/`; keep every file under the 400/500 LOC budget.

---

## 5. Target layout (after Tier 0–2)

**Tradie — own profile**
```
[ ← gear/settings ]                         (settings moved out of body)
[ Avatar 96dp (verified ring) | Name | Trade chip ]
[ Verified ✓ · Available now ]              (S4 — two distinct signals)
[ Stats: Rating(n)  |  Jobs done  |  Yrs exp ]   (S7, S11)
[ ⚠ Incomplete-profile CTA (if any) ]        (S8)
[ ABOUT (expandable) ]                       (S1)
[ Skills chips ]                             (S9)
[ PORTFOLIO (grid → PhotoView) ]             (S2)
[ REVIEWS (top 3 + SEE ALL n) ]              (S3, S11)
[ TRADE DETAILS card (rate, licence, area) ] (existing + S10)
[ WHAT'S BEEN CHECKED (VerificationReceipts)](existing)
```

**Builder — own profile**
```
[ Logo 96dp | Company | Industry chip ]
[ ABN ✓ · In business since 2013 ]
[ Stats: Jobs posted | Hires | Since ]       (S5)
[ ABOUT THE COMPANY (expandable) ]           (S1)
[ COMPANY DETAILS card (ABN, contact, area) ](existing + S5)
[ REVIEWS from tradies ]                     (S3 + S14)
[ WHAT'S BEEN CHECKED ]                      (existing)
```

Settings (Appearance / Account / Legal / Sign out) → bottom of page or `/settings`.

---

## 6. Suggested phasing

| Sprint | Contains | Theme |
|--------|----------|-------|
| **P1** | S1, S2, S4, S5 + E1, E3 | Finish built widgets; instant credibility lift |
| **P2** | S6, S7, S8 + E2, E5 | Restructure: credibility-first page |
| **P3** | S3 (tradie), S11, S10, S12 | Reviews + ratings + relevance |
| **P4** | S9 (if multi-trade approved) | Skills |
| **P5** | S13, S14, S15, S3 (builder) | Public profiles + builder social proof (backend-heavy) |

---

## 7. Open decisions (need Ken's call)

1. **Settings:** move to a dedicated `/settings` route, or keep at the bottom of `/profile`?
2. **Skills (S9):** stay single-trade, or add multi-select `skills` / `secondary_trades` (needs a migration)?
3. **Builder reviews (S14):** in scope now, or defer? It's the biggest backend lift and gates builder social proof.
4. **Public builder profile (S13):** build now, or after the own-profile redesign ships?
5. **Scope for *this* round:** confirm which Tier(s) / sprint(s) we actually execute first.

---

## 9. P1 — shipped (2026-06-08)

Built TDD-first (tests written + watched fail before each implementation). Full suite green: **369 pass / 6 skip / 0 fail**, `flutter analyze` clean, `check-architecture.sh` all 7 PASS, format + design grep gates clean.

| ID | What shipped | Files | Tests |
|----|--------------|-------|-------|
| S4 | Honest availability banner — real `isAvailable`/`availableFrom` (search semantics: `isAvailable \|\| availableFrom <= today`), verified signal split into its own pill | `widgets/profile_availability_banner.dart` (pure `availabilityDisplay` + widget) | `profile_availability_test.dart` (5) |
| S2 | Read-only portfolio grid on the tradie view (`PortfolioStrip(readOnly: true)` — no ADD/remove, tap-to-zoom kept); section hides when empty | `widgets/portfolio_strip.dart` (+`readOnly`) | `portfolio_strip_test.dart` (+2) |
| S3 | Reviews preview — `reviewsForUserProvider` family (no manual load trigger), top 3 `ReviewCard`s + "SEE ALL n" → `/reviews`; hides when empty (no placeholder) | `widgets/profile_reviews_preview.dart`, `reviews_provider.dart` (+family) | `profile_reviews_preview_test.dart` (3) |
| S1 | About / "ABOUT THE COMPANY" bio block; hides when blank | `widgets/profile_about_section.dart` | `profile_about_section_test.dart` (3) |
| S5 | Builder trust line — **Hires** stat badge (`hireCount`) + **Contact** row (`contactName`) in COMPANY DETAILS | `pages/profile_page_sections.dart` | covered by suite |

**Deferred from P1:**
- **E1** — reverted (see §3.3). The `addPostFrameCallback` load trigger stays for now; the correct fix is its own small task (make `loadProfile` reentrancy-safe, or stop `copyWith` from nulling a live error).
- **E3** — dropped (false positive, see §3.3).

**Net new widgets are all small** (40–142 LOC); `profile_page_sections.dart` grew 439 → 442 (the inline banner extraction offset the additions), still under the 500 ceiling.

---

## 8. Definition of done (per shipped item)

- Uses `context.c` tokens, `Theme.textTheme` roles, `Gap`, `AppIcons`, `AppIconSize` — passes `validate.sh` + `check-architecture.sh`.
- No fabricated values — empty fields hide their section (no begging microcopy; MASTER anti-pattern).
- New widgets are one-per-file under budget; no `addPostFrameCallback` load triggers.
- Loading via `JSkeletonList`; images via `CachedNetworkImage` + `photo_view` Hero.
- A11y: 48dp targets, ≥4.5:1 text contrast, reduced-motion branch on any entrance animation.
```
