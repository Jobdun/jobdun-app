# Design System Audit — Jobdun (web · Android · iOS)

**Date:** 2026-05-30 · **Scope:** whole design system across all three surfaces — admin **web** (`lib/admin/`), **Android + iOS** mobile (`lib/`), the spec docs (`design-system/jobdun/`), and the token layer (`lib/app/theme/`). · **Type:** findings only, zero code changed.

This audit benchmarks Jobdun's design system against design-system first principles (token tiers, perceptual color, WCAG contrast, modular type, the 8pt grid, the full component state matrix, elevation, motion, platform conventions, and the design→code bridge), translated to **Flutter-pragmatic** terms — where web tooling (OKLCH-in-CSS, DTCG/Style Dictionary, shadcn/Radix) doesn't map, the Dart-native equivalent is named instead. It was prompted by the question *"is the design system actually working perfectly, or does it need work before we can say so?"*

Every claim is pinned to `file:line` or `MASTER.md §` and is provable from source. **Contrast ratios are computed** (WCAG 2.x relative-luminance formula), not estimated — the script is reproducible and the inputs are the literal token hexes in `app_colors.dart`.

**Severity legend** (research P0–P3 mapped to the repo's house words):
**P0 / Critical** — blocks a real user or breaks accessibility on a primary path · **P1 / High** — visible WCAG-AA violation a real user hits · **P2 / Med** — inconsistency or edge-case gap · **P3 / Low** — hygiene / future-proofing.

> **Companion docs:** the fix proposals live in [`DESIGN_SYSTEM_SUGGESTIONS.md`](./DESIGN_SYSTEM_SUGGESTIONS.md). This audit **supersedes** the design-relevant parts of the 2026-05-20 [`archive/DESIGN_SYSTEM_FOUNDATION_AUDIT.md`](./archive/DESIGN_SYSTEM_FOUNDATION_AUDIT.md) and [`archive/UI_UX_INCONSISTENCY_AUDIT.md`](./archive/UI_UX_INCONSISTENCY_AUDIT.md): those did the token-vs-code and screen-vs-theme reconciliation (and largely shipped — `JButton`, `AppSpacing/Radius/Motion`, the barrel, `PageHeader` all exist now). This one goes one layer deeper, to the *quality* of the tokens themselves.

---

## 1. Audit Health Score

| # | Dimension | Score | Key finding |
|---|-----------|:-----:|-------------|
| 1 | Accessibility | **2 / 4** | Primary CTA text fails WCAG contrast (2.80:1); `text3` + enabled borders fail across the board; no Dynamic Type clamp |
| 2 | Performance (design lens) | **4 / 4** | Flat by design — no shadows/blur/gradients; skeleton loaders; paginated feeds; no expensive effects |
| 3 | Theming | **4 / 4** | One `JColors` ThemeExtension shared by mobile + admin, zero feature drift, smooth `lerp` |
| 4 | Responsive | **3 / 4** | Admin has real breakpoints; mobile scales-not-reflows; `SafeArea` inconsistent; no large-screen story |
| 5 | Anti-Patterns / AI-slop | **4 / 4** | Genuinely distinctive — dark, aggressive, flat. Not a purple-gradient SaaS clone |
| | **Total** | **17 / 20** | **Good** — one weak dimension (Accessibility) is dragging an otherwise strong system |

**Rating band: Good (14–17).** The architecture and enforcement are genuinely strong; **accessibility is the single weak pillar**, and almost all of it traces to one root cause (§8): *the spec has no accessibility section, so contrast/scaling/motion-safety were never requirements and never got built.*

---

## 2. Anti-Patterns / AI-slop verdict — **PASS**

Run honestly against the slop tells: purple→blue gradient on white, generic geometric sans, hero-metric template, identical icon-card grids, glassmorphism-by-default, gradient text, side-stripe borders. **Jobdun exhibits none of them.** The dark-slate `#0F172A` ground, the safety-orange single accent, Oswald's condensed industrial weight, flat border-defined cards, and ALL-CAPS declarative buttons read as a *deliberate, category-appropriate identity* for trades workers — not a training-data reflex. You could not guess this design from "job-matching app" alone, which is the test it passes. The one gradient (`AppGradients.brandFlame`) is correctly fenced to the logo wordmark.

The irony the rest of this audit documents: the very thing that makes it distinctive — committing hard to the bright safety-orange with white text — is also its biggest accessibility liability.

---

## 3. Benchmark matrix — first principles vs Jobdun

| Module | Principle | Jobdun status | Evidence |
|--------|-----------|:-------------:|----------|
| **Tokens** | primitive → semantic → component tiers | ⚠️ semantic only | `JColors` is a 42-token semantic layer, but raw hex is inlined into it — no primitive ramp (`app_colors.dart:140-164`). No DTCG/pipeline (fine for Flutter). |
| **Color — system** | perceptually-uniform ramp | ⚠️ hand-picked hex | Tailwind-slate-derived but not a generated ramp; tinted-pair bgs (`actionBg`,`verifiedBg`…) hand-chosen, not derived. |
| **Color — contrast** | 4.5:1 text / 3:1 large+UI | ❌ multiple fails | **§5 contrast table** — CTA 2.80:1, `text3` 3.07:1, borders 1.41:1. |
| **Color — on-color** | guaranteed-legible foreground | ⚠️ present but failing | `onAction`/`onSurface` pattern exists (`app_theme.dart:58-84`) but `onAction=white` fails on `action`. |
| **Typography — scale** | modular ratio, named roles | ✅ mostly | 13 named `textTheme` roles; ratios ~1.2–1.33 (`app_theme.dart:90-166`). |
| **Typography — floor** | ≥12px web / ≥11pt iOS body | ⚠️ too small at the bottom | `labelSmall` 10sp, `bodySmall`/caption/input-label 11sp (`app_theme.dart:143,160,255`). |
| **Typography — measure/leading** | 45–75ch, 1.4–1.6 line-height | ⚠️ partial | `bodyLarge`/`titleMedium` set `height:1.6`; `bodyMedium` (most-used) has no `height` → ~1.36 (`:138`). |
| **Spacing & grid** | 4/8pt grid | ✅ strong | `AppSpacing` 4/8/16/24/32/48 (`app_spacing.dart`); **0** raw `SizedBox` in features. |
| **Radius** | small, consistent | ✅ strong | `AppRadius` 4/6/6/8/6/8, all in the 4–8 band (`app_radii.dart`). |
| **Components & states** | default/hover/focus/active/disabled/loading/empty/error | ✅ strong | `JSkeletonList`, `EmptyState`, paged error/empty builders; focus = orange border. |
| **Elevation / z-index** | small scale + z token scale | ⚠️ N/A by design | Deliberately flat (no shadows). No z-index token scale (low impact in Flutter's tree model). |
| **Motion** | tokens + `prefers-reduced-motion` | ⚠️ partial | `AppMotion` 150/200ms `easeOutCubic`, no bounce; reduced-motion honored **only** in `JStaggeredList`. |
| **Icons / imagery** | one library, single seam, `currentColor` | ✅ strong | `AppIcons` is the sole `phosphor_flutter` seam; **0** direct phosphor in features; `AdaptiveIcon` for iOS. |
| **Accessibility** | WCAG AA as a floor | ❌ weak | contrast fails (§5), no Dynamic Type clamp, `Semantics` on ~16 sites, no a11y section in spec. |
| **Platform (M3/HIG/web)** | follow nav/gesture/target conventions | ⚠️ Material-only | Material on both iOS+Android by choice; `AdaptiveIcon` only; touch floor coded to 48 (`app_theme.dart:176`). |
| **Design→code bridge** | single source of truth, no drift | ✅ strong (mobile) | `MASTER.md` ⇄ `lib/app/theme/` ⇄ barrel ⇄ features; **admin partially bypasses** (§6.1). |

---

## 4. Patterns & systemic issues

These recur across findings and matter more than any single line:

1. **The spec has no accessibility section.** `MASTER.md` covers color/type/spacing/components/motion/anti-patterns but says **nothing** about contrast targets, touch-target sizes, Dynamic Type, or reduced motion. A11y was never a written requirement, so it was never built or enforced. This is the root cause of every P0/P1 below. *(Fix is a doc change first, code second.)*
2. **Brand-vibrancy was prioritized over contrast, and locked.** The prior Foundation Audit declared white-on-orange a "non-negotiable" (`archive/DESIGN_SYSTEM_FOUNDATION_AUDIT.md §11.2`) and flipped `onAction` from near-black to white — reasoning *"MASTER says white"* without ever computing the ratio. The computation (§5) shows that decision fails WCAG on the app's most-used control.
3. **`validate.sh` enforces *placement* but not *quality*.** It catches "raw hex in a feature file" (great — 0 violations) but cannot catch "the token's hex value itself fails contrast." Enforcement is one layer too shallow.
4. **Admin web is the unpoliced surface.** It reuses the theme but calls `GoogleFonts.*` **115×** directly (`lib/admin/`), the source of the red `validate.sh`, and its page-spec (`admin-web.md`) describes a marketing page that doesn't exist.

---

## 5. Detailed findings by severity

### Computed contrast table (dark theme — the production theme)

Inputs are the literal hexes in `lib/app/theme/app_colors.dart:140-164`. ✅ = passes, ❌ = fails.

| Foreground | On background | Ratio | Normal 4.5 | Large/UI 3.0 | Where it's used |
|-----------|---------------|:-----:|:----------:|:------------:|-----------------|
| `text1 #F1F5F9` | surface `#1E293B` | 13.35 | ✅ | ✅ | headlines, body |
| `text2 #94A3B8` | surface | 5.71 | ✅ | ✅ | `bodyMedium`, metadata |
| `text2 #94A3B8` | **raised `#334155`** | **4.04** | ❌ | ✅ | body on selected/elevated cards |
| `text3 #64748B` | background `#0F172A` | **3.75** | ❌ | ✅ | eyebrows, hints, muted links |
| `text3 #64748B` | **surface** | **3.07** | ❌ | ✅ | `labelSmall`, input labels, placeholders |
| `text3 #64748B` | **raised** | **2.18** | ❌ | ❌ | eyebrow on raised surface |
| **`onAction #FFFFFF`** | **`action #F97316`** | **2.80** | ❌ | ❌ | **every primary CTA label/icon** |
| `onAction #FFFFFF` | `urgent #EF4444` | 3.76 | ❌ | ✅ | URGENT badge text, error fills |
| `border #334155` | surface | **1.41** | ❌(UI) | ❌(UI) | input/card border, dividers |
| `action #F97316` | surface | 5.22 | ✅ | ✅ | focus border, loaders, links |
| `verified #22C55E` | surface | 6.42 | ✅ | ✅ | verified checks |
| `actionTx #FED7AA` | `actionBg #431407` | 11.56 | ✅ | ✅ | toast/pending pairs |
| `verifiedTx #86EFAC` | `verifiedBg #052E16` | 10.62 | ✅ | ✅ | verified pairs |
| `urgentTx #FCA5A5` | `urgentBg #450A0A` | 8.51 | ✅ | ✅ | error pairs |
| `availableTx #93C5FD` | `availableBg #1E3A5F` | 6.38 | ✅ | ✅ | availability pairs |

**Takeaway:** `text1` and every *tinted-pair* status color are excellent. The failures cluster in three places: **the primary CTA, the `text3` role, and resting borders.**

---

- **[P0 / Critical] White text on the safety-orange CTA fails WCAG contrast (2.80:1)**
  - **Location:** `app_colors.dart:153` (`onAction: Color(0xFFFFFFFF)`), consumed by `j_button.dart:99-101` (primary), the `ColorScheme.onPrimary` wiring (`app_theme.dart:61`), role chips (`profile_page.dart` role chip), URGENT chips.
  - **Category:** Accessibility · **Standard:** WCAG 1.4.3 (4.5:1 normal text); fails even 1.4.11 / large-text 3:1.
  - **Impact:** The most-tapped control in the app — LOG IN, APPLY NOW, POST JOB, HIRE — renders its label below the *large-text* floor. Button text is `labelLarge` 14sp bold (`app_theme.dart:148`), which is "normal text" by WCAG (not ≥18.66px bold), so the bar is 4.5:1 and the gap is wide. Outdoors in sunlight (the literal use case for tradies) this is materially harder to read.
  - **Recommendation:** Use a **dark** foreground on orange (`#0F172A` = 6.37:1, or legacy `#1A0A03` = 6.88:1). This reverses the prior "non-negotiable" but is the only fully WCAG-clean option that keeps the bright brand orange. Alternatives (darken the orange so white passes; the brand cost) are laid out in the suggestions doc. **This re-opens a locked decision and is the user's call** — see `DESIGN_SYSTEM_SUGGESTIONS.md §2`.
  - **Suggested command:** `/impeccable colorize`

- **[P1 / High] The `text3` role fails AA contrast everywhere it's used**
  - **Location:** `app_colors.dart:148` (`text3 #64748B`); consumed by `labelSmall` (`app_theme.dart:160`), input `labelStyle` (`:255`), `hintStyle`/placeholder (`:267`), `prefix/suffixIconColor` (`:277`), default `iconTheme` (`:294`), `FieldLabel`, and the muted-link pattern.
  - **Category:** Accessibility · **Standard:** WCAG 1.4.3 (3.07:1 on surface, 3.75:1 on bg — both < 4.5).
  - **Impact:** Eyebrow labels, field labels, **input placeholder text**, and hints are below the readable floor. Placeholders especially: a placeholder is content the user must read to use the form. On raised surfaces it drops to 2.18:1 (illegible).
  - **Recommendation:** Lighten `text3` to ≥ `#8B98AB` (5.0:1 surface / 6.1:1 bg — verified) and add the rule "small/secondary text sits on `background` or `surface`, never `surfaceRaised`." Details in suggestions doc.
  - **Suggested command:** `/impeccable colorize`

- **[P1 / High] Enabled input/card borders fail the 3:1 non-text contrast floor**
  - **Location:** `app_colors.dart:145` (`border #334155`); used as `enabledBorder`/`border` on inputs (`app_theme.dart:227-234`), card outline (`:290`), `DividerTheme` (`:293`).
  - **Category:** Accessibility · **Standard:** WCAG 1.4.11 (3:1 for UI component boundaries) — measured **1.41:1** on surface, **1.72:1** on bg.
  - **Impact:** A resting input field's boundary is essentially invisible against its own fill; users locate fields only by the fill tint. The *focused* border is orange (5.22:1 — fine), so the field "appears" only on focus. Card hairlines are more decorative (lower stakes), but interactive field boundaries are in-scope for 1.4.11.
  - **Recommendation:** Introduce a distinct stronger border for interactive boundaries (~`#708096`, 3.63:1 verified) while keeping `#334155` as the subtle divider/card hairline. See suggestions doc.
  - **Suggested command:** `/impeccable colorize`

- **[P1 / High] No Dynamic Type / `textScaler` clamp — large OS font sizes can break fixed-height layouts**
  - **Location:** app root (`lib/app/app.dart` `ScreenUtilInit`, `lib/admin/app/admin_app.dart`); **0** `textScaler`/`MediaQuery.text*` references in `lib/` (grep). Fixed heights at `j_button.dart:55-58` (56/40dp), `app_theme.dart:24,40` (Pinput 56), dense list rows.
  - **Category:** Accessibility / Responsive · **Standard:** WCAG 1.4.4 (resize text) + Apple Dynamic Type + Android font-size.
  - **Impact:** Flutter passes the OS text-scale through by default, but it's never **clamped or tested**. At iOS AX-sizes / Android "largest", `.sp` text inside fixed-height buttons and dense rows will clip or overflow — and nothing caps the scale. (Conversely, the `.sp`×OS-scale interplay can double-scale.) Today this is untested territory, not a verified crash — but it's unbounded.
  - **Recommendation:** Clamp `MediaQuery.textScaler` to a tested band (e.g. 0.9–1.3) at both app roots and audit fixed heights to grow with text. See suggestions doc.
  - **Suggested command:** `/impeccable adapt`

- **[P2 / Med] `text2` body text dips below AA on raised surfaces (4.04:1)**
  - **Location:** `app_colors.dart:147`; `bodyMedium`/`bodySmall` default to `text2` (`app_theme.dart:141,146`), shown on `surfaceRaised` selected/elevated cards.
  - **Category:** Accessibility · **Standard:** WCAG 1.4.3. Passes on bg/surface; only the raised case fails.
  - **Recommendation:** Either lift `text2` slightly or forbid body copy on `surfaceRaised` (use it for chrome only). Lower stakes than `text3`.

- **[P2 / Med] Type scale floor is below the legibility minimum**
  - **Location:** `labelSmall` 10sp (`app_theme.dart:160`), input `labelStyle`/`errorStyle` 11sp (`:255,:272`), `bodySmall`/caption 11sp (`:143`).
  - **Category:** Typography · **Standard:** 12px web / 11pt iOS body floor. 10sp eyebrows + `text3` color compound into "tiny and faint."
  - **Recommendation:** Raise the floor to 11sp minimum for labels and 12sp for body-small; reserve 10sp for nothing. See suggestions doc.
  - **Suggested command:** `/impeccable typeset`

- **[P2 / Med] White-on-red URGENT/error fills fail AA for small text (3.76:1)**
  - **Location:** `ColorScheme.onError = white` (`app_theme.dart:73`), URGENT chip (`job_detail_page.dart` urgent chip), any white label on `urgent`.
  - **Category:** Accessibility · **Standard:** WCAG 1.4.3 (passes large/UI 3:1, fails normal 4.5). Prefer the `urgentTx`-on-`urgentBg` tinted pattern (8.51:1) for error text instead of white-on-solid-red.

- **[P2 / Med] `prefers-reduced-motion` honored in only one place**
  - **Location:** `JStaggeredList` respects `MediaQuery.disableAnimations` (per `MASTER §220`); `flutter_animate` micro-interactions and GoRouter transitions are not gated.
  - **Category:** Accessibility / Motion · **Standard:** reduced-motion is non-negotiable for vestibular safety. Coverage is partial.
  - **Suggested command:** `/impeccable animate`

- **[P2 / Med] Compact buttons render below the iOS 44pt visible target**
  - **Location:** `j_button.dart:57-58` (compact 40dp), `:133` (text-compact 36dp).
  - **Category:** Touch · **Standard:** iOS 44pt / Android 48dp visible; WCAG 2.5.8 (24px) is met and the hit area is padded to 48 via `MaterialTapTargetSize.padded` (`app_theme.dart:176,188`), so this is a *visible-size* polish issue, not a tap-area failure. Used for in-row REJECT/SHORTLIST/HIRE where space is tight — an accepted trade-off, worth a second look on the smallest phones.

- **[P3 / Low] No primitive token tier**
  - **Location:** `app_colors.dart:140-164` — raw hex is embedded directly in the semantic `JColors.dark`.
  - **Category:** Theming · The semantic layer is excellent, but there's no underlying primitive ramp (`_slate900`, `_orange500`…). Adding one (Dart-native, no DTCG needed) would make the gated light theme and any future re-tinting consistent and would make the contrast fixes above one-line ramp edits. Low urgency.

- **[P3 / Low] `bodyMedium` (most-used secondary body) has no explicit line-height**
  - **Location:** `app_theme.dart:138-142` — no `height`, so Open Sans ~1.36, below the 1.4–1.5 comfort band. `bodyLarge`/`titleMedium` correctly set 1.6.

- **[P3 / Low] Stale doc comment: `brandDisplay` says "Inter Black 900" but renders Oswald 700**
  - **Location:** `app_theme.dart:14` comment vs `:16` code (`GoogleFonts.oswald`, w700).

- **[P3 / Low] Gated light theme is untested dead-ish code**
  - **Location:** `app_colors.dart:167-191` — `JColors.light` exists but the app is dark-only (`AppTheme.dark()` everywhere). Its `text3 #94A3B8` on `surface #FFFFFF` etc. has never been contrast-checked and will rot. Either wire it (with its own contrast pass) or delete it.

---

## 6. Per-surface findings

### 6.1 Web (admin, `lib/admin/`)

- ✅ Reuses `AppTheme.dark()` + `JColors` wholesale — **zero token fork** (`admin_app.dart` mirrors `app.dart`).
- ✅ Real responsive structure: `LayoutBuilder` breakpoints (1024 sidebar-collapse, 720/1100 grid columns), modal `maxWidth` constraints (440/480/720).
- ❌ **115 direct `GoogleFonts.*` calls** in `lib/admin/` bypass the centralized `textTheme` — the source of the red `validate.sh` (also flagged in memory as pre-existing debt). Admin text is not guaranteed to track the type scale.
- ⚠️ Hover/focus delegated entirely to Material defaults — acceptable, but no explicit `focus-visible` ring story for keyboard/desktop users (WCAG 2.4.7/2.4.13).
- ⚠️ No dense data-table component; admin lists are stacked rows — fine now, a scale question later.
- All the §5 contrast failures **also apply to admin** (same tokens), and matter *more* on a desktop content-density surface.

### 6.2 Android + iOS (mobile)

- **Material-only by design** — no Cupertino widgets; `AdaptiveIcon` (`adaptive_icon.dart`) swaps icon glyphs on iOS but interaction is Material on both. This is an intentional, defensible brand decision (`MASTER` "Jobdun owns the experience"), not drift — but it means iOS users don't get native gestures/affordances, and that should be a *documented* choice.
- **`SafeArea` used 33×** but inconsistently — some simple pages omit it. No single page-scaffold primitive enforces it.
- **Touch floor coded to 48dp** globally (`app_theme.dart:176,188`) — better than the 44pt iOS minimum; good.
- Dynamic Type (§5, P1) is the main mobile-specific gap.
- No tablet/large-screen layout — ScreenUtil scales 390×844 up proportionally rather than reflowing. Aligns with "mobile-first hand-held tradie tool"; note it as a deliberate boundary.

### 6.3 Spec docs (`design-system/jobdun/`)

- ❌ **No accessibility section in `MASTER.md`** — see §4.1. The biggest spec gap.
- ⚠️ **`MASTER §70` (button letter-spacing 1.5) still conflicts with the §117 code sample (1.0).** The prior Foundation Audit (§3f) said the Sprint-C doc pass would fix it; it didn't. Code uses 1.5 (`app_theme.dart:151`) — so update the sample.
- ⚠️ **`MASTER §71`** documents Label as 12sp but the theme has both `labelMedium` 12sp and an undocumented `labelSmall` 10sp.
- ❌ **`admin-web.md` is wrong, not just stale** — it describes a *marketing dashboard* ("dynamic hero personalized," "tailored testimonials," "smart CTA," "A/B test color per segment") that has nothing to do with the actual admin console, and documents none of the real breakpoints/sidebar/modals in `lib/admin/`.
- ⚠️ `messaging.md` is a near-empty generated template.
- ⚠️ `MASTER §227` mandates Lottie empty states; only 7 lottie references exist and `EmptyState` is icon+text — partial adherence (acceptable, but the spec overstates reality).

---

## 7. What's solid (preserve these)

1. **One shared `JColors` ThemeExtension** across mobile + admin, with smooth `lerp` (`app_colors.dart:245-272`). Textbook semantic-token + on-color theming.
2. **Centralized icon seam** — `AppIcons` is the sole `phosphor_flutter` import; **0** direct phosphor and **0** raw Material `Icons.` in features.
3. **Genuinely enforced placement rules** — `validate.sh` keeps features clean: **0** raw `SizedBox` spacing, **0** `Color(0xFF)`, **0** `showModalBottomSheet`, **0** `GoogleFonts` in `lib/features/`.
4. **Complete component state matrix** — `JSkeletonList` (loading), `EmptyState` (empty), paged error/empty builders, visible orange focus border.
5. **The 4/8 spacing grid and 4–8 radius band match `MASTER` exactly** — no drift, no t-shirt-size sprawl.
6. **`text1` and every tinted status pair pass contrast with large margins** (§5) — the system *can* do accessible color; it just didn't apply that discipline to the three failing roles.
7. **Motion discipline** — 150/200ms, `easeOutCubic`, no bounce/spring.
8. **A distinctive, anti-slop identity** that survives the category-reflex test.

---

## 8. Method & confidence

- **Read:** `MASTER.md` + all 5 page overrides; `lib/app/theme/*` (colors, theme, spacing, radii, motion); `j_button.dart`; the three exploration sweeps across `lib/features/`, `lib/admin/`, `lib/core/`; the two prior archived audits; `VERIFICATION_FLOW_AUDIT.md` (house format).
- **Computed:** all contrast ratios via the WCAG relative-luminance formula over the literal token hexes — reproducible, not estimated.
- **Grepped:** drift counts (admin GoogleFonts 115, feature inline `TextStyle` 69, `Semantics` 16, raw `SizedBox` 0, `Color(0xFF)` 0, `showModalBottomSheet` 0, `textScaler` 0).
- **Not done:** runtime device/emulator rendering, screen-reader (VoiceOver/TalkBack) passes, real Dynamic Type stress at AX sizes. The Dynamic Type finding (P1) is "unbounded and untested," provable from source; the exact overflow point needs a device run.
- **Confidence:** High for token/contrast/spec facts (static + computed). Medium for the runtime behavior of Dynamic Type and admin hover/focus.

**Bottom line:** the design system is **well-built and well-enforced** — the bones are good. It is *not yet* "working perfectly" because **accessibility was never a written requirement**, which left contrast failures baked into the tokens (most critically white-on-orange) and Dynamic Type unbounded. Fixing the spec's a11y gap and the three failing color roles moves this from 17/20 to a defensible 19–20.
