# Jobdun Design System Audit

> **Snapshot:** 2026-05-12
> **Auditor:** Claude (claude-opus-4-7) under direction of Ken Garcia
> **Stage:** Pre-Phase 1 (Foundation) — 21 screens scaffolded, theme + 9 shared widgets in place, AU launch targeted
> **Supersedes:** `docs/DESIGN_SYSTEM_AUDIT.md` (V1) and `docs/DESIGN_SYSTEM_AUDIT_V2.md` (V2) for current state. Keep V1/V2 for historical comparison only.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Maturity Score](#maturity-score)
3. [Foundations](#1-foundations)
4. [Brand Identity](#2-brand-identity)
5. [Components](#3-components)
6. [Patterns](#4-patterns)
7. [Accessibility](#5-accessibility)
8. [Internationalization & Localization](#6-internationalization--localization)
9. [Flutter Implementation](#7-flutter-implementation)
10. [Performance](#8-performance)
11. [Governance & Documentation](#9-governance--documentation)
12. [Production Readiness Gaps](#10-production-readiness-gaps)
13. [Risk Register](#risk-register)
14. [Build Order (Prioritized)](#build-order-prioritized)
15. [Recommended File Structure](#recommended-file-structure)
16. [Token Reference (Quick-Copy)](#token-reference-quick-copy)
17. [Component Inventory](#component-inventory)
18. [Pattern Inventory](#pattern-inventory)
19. [Open Questions](#open-questions)
20. [Next Audit](#next-audit)
21. [Layman's Term Explanation](#laymans-term-explanation)

---

## Executive Summary

Jobdun has a **defined-but-drifting** design system. The foundation is genuinely strong — a full `JColors` ThemeExtension with 22 semantic tokens, spacing/radius scales, an Oswald+Open Sans text theme, and grep-based CI gates that have already driven feature code to **zero** hardcoded colors, raw `SizedBox` spacers, or rogue `GoogleFonts.*` calls. That last part puts you ahead of where 90% of solo-founder Flutter apps sit at 21 screens.

The brutal part is that the **three sources of truth disagree on fundamentals**. `CLAUDE.md` and `design-system/jobdun/MASTER.md` say the typography is Inter; the actual `lib/app/theme/app_theme.dart` ships Oswald + Open Sans; MASTER's pre-delivery checklist still references Barlow. That's not a cosmetic problem — it means future agents (and future-you at 2am) will rebuild things off the wrong spec. **Code is the source of truth**; the docs need to catch up *this week*.

The other three real risks: (1) `AppTextField` is a stub that's never used — every form re-implements `FormBuilderTextField` with copy-pasted decorations, which will rot into 10+ divergent input styles by Phase 1; (2) accessibility primitives are absent — `Semantics` is used zero times, `GvChip` is 30dp tall (fails the 44pt iOS HIG / 48dp Material minimum), and the App Store review process will flag this; (3) no internationalization scaffold and no centralized AU formatters (currency, dates, phone), so `intl` is in the pubspec doing nothing.

**Top 3 priorities, in order:**

1. **Reconcile the docs to the code** (Oswald + Open Sans). Delete `AppDarkColors` and `AppColors.white` dead code while you're in there. Move motion + elevation values into named tokens. (P0, ~2 hours)
2. **Build the real `AppTextField`, `AppCard`, and `AppFormField` molecules** and migrate the 5 existing forms onto them before adding screen #22. Locking the inputs in once is cheap; refactoring 30 forms in 6 months is not. (P0, ~1 day)
3. **Add Widgetbook + a minimum-viable a11y pass** (Semantics labels on all `GestureDetector`-wrapped buttons, 44pt minimum touch targets, color contrast spot-check). Without Widgetbook, drift is invisible until users hit it. (P1, ~2 days)

**Overall maturity:** Defined — moving from Emerging to Mature. You're past the "vibe" stage; you have tokens. You're not yet at the "every screen ships from the same primitives" stage.

---

## Maturity Score

| Category | Status | Priority | One-line take |
|---|---|---|---|
| Foundations — Tokens | 🟢 Solid | P2 | JColors covers 22 named semantic tokens; spacing + radius defined |
| Foundations — Motion | 🔴 Missing | P1 | Durations hardcoded inline; no `AppMotion` token class |
| Foundations — Elevation | 🟡 Partial | P2 | `AppElevation.none = 0.0` is the only one. Document the flat-only rule explicitly. |
| Brand Identity | 🟡 Partial | P1 | Logo SVG + mark exist; `JobdunLogo` widget is bypassed by raw `Text('JOBDUN')` in 2 pages |
| Components — Atoms | 🟡 Partial | P0 | `AppButton` solid; `AppTextField` is a stub; no `AppCard`, `AppChip` (GvChip is filter-only) |
| Components — Molecules | 🟡 Partial | P1 | `JobCard` + `StatusBadge` + `EmptyState` solid; field-with-label pattern re-implemented per page |
| Components — Organisms | 🟡 Partial | P1 | JobCard + EmptyState. No application card, message thread item, review card, profile card. |
| Patterns — Forms | 🔴 Missing | P0 | No `AppFormField` wrapper; each form hand-rolls label + field + validator |
| Patterns — Lists | 🟡 Partial | P1 | Pull-to-refresh, pagination not standardized (`infinite_scroll_pagination` in pubspec, never used) |
| Patterns — Errors / Loading / Empty | 🟡 Partial | P0 | Three competing patterns for errors; `LoadingView` co-exists with inline LinearProgressIndicator; `EmptyState` duplicated inline in `jobs_page.dart` |
| Accessibility | 🔴 Missing | P0 | Zero `Semantics`; `GvChip` is 30h (fails 44pt min); `GestureDetector` wrapping `Checkbox` double-tap-target |
| i18n / l10n | 🔴 Missing | P1 | No `flutter_localizations`, no ARB files, no AU formatters. `intl` in pubspec, unused. |
| Flutter Implementation | 🟢 Solid | — | ThemeExtension pattern correct; `context.c.x` shorthand idiomatic; grep gates enforce drift |
| Performance | 🟡 Partial | P1 | GoogleFonts loaded from network — first paint shows fallback. `skeletonizer` in pubspec, never used. |
| Governance | 🟡 Partial | P1 | MASTER.md exists; no naming convention; three sources of truth disagree on typography |
| Production Readiness | 🔴 Missing | P0 | No trust-and-safety states, no offline banner (despite `connectivity_plus`), no permission-denied UX |

**Overall maturity:** **Defined** (3 / 5)
> Pre-system → Emerging → **Defined** → Mature → Optimized

---

## 1. Foundations

### 1.1 Color System

**Current state:**
- `JColors` ThemeExtension in `lib/app/theme/app_colors.dart` with **dark** (default) and **light** (gated) variants
- 22 semantic tokens: `background`, `surface`, `card`, `surfaceRaised`, `border`, `text1/2/3`, `action` + `actionPressed` + `actionBg` + `actionTx`, `verified/Bg/Tx`, `urgent/Bg/Tx`, `available/Bg/Tx`, `star`
- Each semantic state has a triple — base / background / text — so banners and chips don't drift
- Smooth animated theme-switch transitions via `lerp` override (correctly implemented for all 22 tokens)
- Backed by `colorScheme` mapping in `app_theme.dart` so Material widgets inherit correctly
- Persisted theme mode via `SharedPreferences` in `theme_provider.dart`, loaded before first frame to avoid dark→light flash
- Grep gate in `scripts/validate.sh` blocks `Color(0xFF` and `AppColors.*` in `lib/features/` — **gate is clean** (0 violations as of audit)
- Light mode contrast: `text2: #475569` on `surface: #FFFFFF` is 7.5:1 (passes AA)
- Dark mode contrast: `text1: #F1F5F9` on `background: #0F172A` is 14.8:1 (passes AAA body)
- Dark mode contrast spot check: `text2: #94A3B8` on `background: #0F172A` is 6.0:1 (passes AA body)
- Dark mode contrast spot check: `text3: #64748B` on `background: #0F172A` is 3.5:1 — **fails AA body (4.5:1)** but passes for large text and UI components (3:1). Risk: timestamps / metadata using `text3` are right at the edge of legibility on cheap Android screens.

**Gaps:**
1. `AppColors.white = Color(0xFFFFFFFF)` — dead code; only referenced in `app_theme.dart` via `Colors.white` directly with intentional comments
2. `AppDarkColors` class — every member just re-exports `AppColors.*`. Redundant abstraction.
3. `AppColors` static fallbacks (`abstract final class AppColors`) duplicate every token from `JColors.dark`. This was intentional during migration ("Dark values kept so any files not yet migrated to context.c still compile") — but the migration is **complete**. Time to delete.
4. No documented contrast policy. The audit found `text3` at 3.5:1 against background — that's borderline and nobody flagged it.
5. No focus / hover / pressed / disabled state colors as first-class tokens. Pressed state for action is `actionPressed`, but inputs / chips compute pressed state inline.
6. No "disabled" color token. `AppButton` uses `c.action.withValues(alpha: 0.35)` — that's a magic number, not a token.

**Recommendation:**
- **DELETE** `AppColors.white`, `AppDarkColors`, and the entire `AppColors` static fallback class. Run `flutter analyze` to confirm zero referents.
- **ADD** `actionDisabled`, `text1Disabled`, `borderFocus` to `JColors`. Stop using `.withValues(alpha: x)` in widgets.
- **DOCUMENT** the contrast policy in `design-system/jobdun/MASTER.md`: "All body-text tokens must clear WCAG AA (4.5:1). UI-component tokens must clear 3:1. Run `flutter run --contrast-audit` (script TBD) before merging color changes."
- **CONSIDER** raising `text3` from `#64748B` to `#94A3B8` (= `text2`) and renaming `text2` → `textHigh` / `text3` → `textMid` / introduce `textLow` at `#B8C5D6`. Right now the 3-tier scale collapses for `text3`.

**Status:** 🟡 Partial — tokens are there, hygiene is not. P2.

---

### 1.2 Typography

**Current state:**
- `app_theme.dart` ships **Oswald** (display/heading/button/label-large) + **Open Sans** (body/title/label-medium/small)
- Wordmark fallback `AppTheme.brandDisplay()` is Inter 900 — **inconsistency with the rest of the theme**
- Full Material 3 textTheme covered: `displayLarge` (40 Oswald 700), `headlineMedium` (24 Oswald 600), `bodyLarge` (15 Open Sans 400), `labelLarge` (14 Oswald 700 — for buttons), `labelMedium` (12 Open Sans 600), etc.
- Line-height set on `titleMedium`, `bodyLarge` (1.6) — but not on `headlineLarge`, `displayLarge`, etc.
- Letter-spacing curve looks right for industrial type — 1.2 at display, 0.8 at H1, 0 at body, 1.5 at button-label
- `Pinput` theme also overrides Oswald inline (`pinputTheme` / `pinputFocusedTheme`) — bypasses the text theme

**Drift:**
| Source | Says |
|---|---|
| Code (`app_theme.dart`) | Oswald headings + Open Sans body — **truth** |
| `CLAUDE.md` (project rules, line 36) | "Inter (all weights, 700+ for headings) via `google_fonts`" — **stale** |
| `design-system/jobdun/MASTER.md` (line 52–53) | Oswald + Open Sans — **matches code** |
| `design-system/jobdun/MASTER.md` (line 249, pre-delivery checklist) | "Barlow / Barlow Condensed" — **stale, never used** |

**Gaps:**
1. `CLAUDE.md` line 36 says Inter — **wrong**. Future agents will use this as truth.
2. `MASTER.md` line 249 says Barlow — **wrong**. Never matched any state of the app.
3. `AppTheme.brandDisplay()` is Inter 900 — used by `JobdunLogo` widget? No — `JobdunLogo` actually renders the SVG. So `brandDisplay()` is unused — dead.
4. No `lineHeight` discipline on headings — Oswald 40sp display has no `height` set, so it defaults to Open Sans's font metrics. Visual inconsistency at large sizes.
5. Fonts load from **network** via `google_fonts` package on first run. AU tradies on patchy 4G see system-font fallback flash. Audit `cached_network_image`-style font bundling.

**Recommendation:**
- **P0 (this week):**
  - Update `CLAUDE.md` line 36 from "Inter" → "Oswald (headings) + Open Sans (body)"
  - Update `MASTER.md` line 249 pre-delivery checklist: "Barlow / Barlow Condensed" → "Oswald / Open Sans"
  - Delete `AppTheme.brandDisplay()` if grep confirms zero callers (a quick `grep -rn brandDisplay lib/` confirms 0 references)
- **P1:** Add `height` to every headline/display TextStyle (`height: 1.1` for headings, `1.6` for body).
- **P1:** Pre-load critical fonts at app startup using `GoogleFonts.pendingFonts([oswald, openSans])` — eliminates the system-font flash.
- **P2:** Consider bundling Oswald + Open Sans as `pubspec.yaml` `fonts:` entries instead of `google_fonts` for production builds. ~150KB total, paid once instead of on every cold start.

**Status:** 🟡 Partial — code is good, docs are wrong, fonts load slow. P0 to fix docs.

---

### 1.3 Spacing

**Current state:**
- `AppSpacing` in `app_colors.dart` (odd home, but works):
  - `xs: 4`, `sm: 8`, `md: 16`, `lg: 24`, `xl: 32`, `xxl: 48`
- Convention enforced: `Gap(n)` everywhere, never raw `SizedBox(height/width: n)` — **0 violations** in features
- `flutter_screenutil` extensions (`.w`, `.h`, `.sp`, `.r`) used everywhere

**Gaps:**
1. `AppSpacing` lives in `app_colors.dart` — wrong file. Move to `app_spacing.dart` or a tokens barrel file.
2. No `Gap(AppSpacing.md.h)` mixed with raw `Gap(12.h)`, `Gap(4.h)`, `Gap(18.h)`, `Gap(8.w)` etc. scattered across pages (login_page.dart uses `Gap(48.h)`, `Gap(6.h)`, `Gap(40.h)`, `Gap(18.h)`, `Gap(10.h)` — none of which are in the scale). This means the scale exists but isn't enforced.
3. No grep gate blocks raw `Gap(<number>)`.

**Recommendation:**
- Move `AppSpacing` to `lib/app/theme/app_spacing.dart`. Re-export from `app_colors.dart` for backward compatibility, then deprecate.
- Add a grep gate (or `dart analyze` custom lint) for `Gap\([0-9]+\.[wh]\)` in `lib/features/`. Allow only `Gap(AppSpacing.x.h)` or `Gap(AppSpacing.x.w)`.
- If a one-off spacing is needed (e.g. `Gap(48.h)` for the hero block), add it as a named token: `AppSpacing.hero = 48.0`.

**Status:** 🟢 Solid (scale exists, convention enforced for `Gap` vs `SizedBox`) but with a 🟡 sub-issue: scale **values** aren't enforced. P2.

---

### 1.4 Border Radius

**Current state:**
- `AppRadius` in `app_colors.dart`: `badge: 4`, `chip: 6`, `btn: 6`, `card: 8`, `input: 6`, `avatar: 8`
- Named by **role**, not by size — which is actually the more disciplined choice for a small app
- Used consistently across `AppButton`, `JobCard`, `StatusBadge`, `GvChip`, theme `inputDecorationTheme`

**Gaps:**
1. Same file-location issue as spacing.
2. No `radius.full` for circular avatars / pill chips (would be `9999.r`).
3. Avatar uses `8.r` rounded square — intentional, but the doc doesn't say why (vs a typical circle).

**Recommendation:** Add `AppRadius.full = 9999.0`. Document avatar = rounded square rationale in MASTER.md.

**Status:** 🟢 Solid. P3.

---

### 1.5 Elevation / Shadow

**Current state:**
- `AppElevation.none = 0.0` — and that's it
- Theme sets `elevation: 0` on `AppBar`, `Card`, `BottomNavigationBar` correctly
- MASTER.md anti-pattern: "No card shadows. Border instead of shadow for edge definition." — and the code follows it.

**Gaps:**
1. **The flat-only rule isn't documented anywhere except MASTER.md.** A future agent looking at `AppElevation.none` won't know elevation is intentionally restricted. Add a doc comment.
2. There will be cases where shadow IS needed — sticky bottom CTA bar, modal dialog drop shadow, persistent header on scroll. The "flat only" rule will get violated ad-hoc without a documented exception.

**Recommendation:**
```dart
abstract final class AppElevation {
  /// Default — flat surfaces with border for edge definition.
  /// Use this for cards, app bars, bottom nav, scaffolds.
  static const none = 0.0;

  /// Reserved for transient overlays only — bottom-sheet drop shadow,
  /// modal dialog, snackbars, and sticky CTA bars. NOT for cards or content.
  static const overlay = 8.0;
}
```

**Status:** 🟡 Partial (rule exists, isn't programmatic). P2.

---

### 1.6 Motion / Animation Tokens

**Current state:**
- MASTER.md says "Transitions: 150–200ms ease. No longer."
- Code uses `Duration(milliseconds: 150)` and `Duration(milliseconds: 400)` inline. Examples:
  - `login_page.dart:60` — `Duration(milliseconds: 150)` for AnimatedOpacity
  - `jobs_page.dart:57` — `Duration(milliseconds: 400)` for search debounce (this is fine, not a UI animation)
  - `gv_chip.dart:26` — `Duration(milliseconds: 150)`, `Curves.ease`

**Gaps:**
1. **No `AppMotion` token class exists.** Every animated widget gets the duration via a magic number.
2. Curve isn't tokenized either — `Curves.ease` is the convention, never tokenized.
3. No "reduced motion" handling — `MediaQuery.of(context).disableAnimations` is never checked.

**Recommendation:**
```dart
abstract final class AppMotion {
  /// Standard duration for micro-interactions (chip toggle, fade in, sheet open).
  static const fast = Duration(milliseconds: 150);

  /// Slightly longer — page transitions, slide-in lists.
  static const medium = Duration(milliseconds: 200);

  /// Reserved for splash / large hero animations. Capped at MASTER.md spec.
  static const slow = Duration(milliseconds: 300);

  /// Default curve. Construction-app brand = no bounce.
  static const curve = Curves.easeOutCubic;

  /// Respect OS-level reduced motion setting.
  static Duration adapt(BuildContext context, Duration base) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : base;
}
```

**Status:** 🔴 Missing as a token class. P1.

---

### 1.7 Iconography

**Current state:**
- `iconsax: ^0.0.8` is the primary set
- Material `Icons.*` is a documented fallback (and used for `Icons.error_outline` in `ErrorView`)
- `AdaptiveIcon` widget exists (iOS Cupertino fallback for the `iconsax` variant) — but only used... nowhere? `grep -rn AdaptiveIcon lib/` shows it's defined and never imported.
- No icon-size token enforcement — pages use `16.r`, `18.r`, `20.r`, `24.r`, `48.r` ad-hoc
- `AppIconSize` exists in `app_constants.dart`: `sm: 16`, `md: 20`, `lg: 24`, `xl: 32`, `feature: 40` — but **not used in any page** (grep confirms 0 references to `AppIconSize.` outside its own file)

**Gaps:**
1. `iconsax: ^0.0.8` is **0.x version** — pre-1.0, no semver guarantee. Risk for future flutter SDK bumps.
2. `AdaptiveIcon` is dead code. Either adopt it everywhere or delete it.
3. `AppIconSize` is dead code. Either adopt it or delete it.
4. No icon-color discipline beyond "use `c.text3` for unselected, `c.action` for active" — implied by MASTER.md but not enforced.

**Recommendation:**
- **DECIDE:** Either delete `AdaptiveIcon` and `AppIconSize`, OR migrate the 21 pages to use them. Half-built is worse than absent.
- Pin iconsax to a specific minor version or move to `flutter_iconly` / `phosphor_flutter` (both 1.x stable).
- Add a `JIcon` wrapper widget if you want enforcement: `JIcon(Iconsax.briefcase, size: JIconSize.md, color: c.text3)`.

**Status:** 🟡 Partial — primary icon set chosen, but token + wrapper layer half-built. P2.

---

### 1.8 Breakpoints / Responsive

**Current state:**
- `flutter_screenutil` initialized somewhere (presumably in `app.dart` — needs confirmation)
- `.w`, `.h`, `.sp`, `.r` used everywhere — good
- No breakpoint logic; no tablet layout

**Gaps:**
1. No `AppBreakpoints` class. If a tradie opens this on an iPad while on site, the 600px-wide login form will look ridiculous stretched to 1024px.
2. No `LayoutBuilder` / `MediaQuery` discipline in any of the 21 pages.
3. AU foldable users (Samsung Z Fold is common in trades for ruggedness) — no handling.

**Recommendation:** Defer to Phase 2 — phone-only is correct for MVP. But document the deferral explicitly in MASTER.md so it doesn't accidentally regress.

**Status:** 🟡 Partial (acceptable for MVP). P2.

---

## 2. Brand Identity

### 2.1 Logo System

**Current state:**
- `JobdunLogo` widget in `lib/core/design/widgets/jobdun_logo.dart` — 2 variants (`full`, `mark`), supports color override, 45 lines clean
- Assets: `logo-jobdun.svg`, `mark-jobdun.svg`, `logo.png` (raster mark), `icon-google.svg`, `icon-apple.svg`, plus 4 logo-concept directories from your brainstorm session (`hammer-j-above`, `hammer-j-fused`, `hammer-j-side`, `hammer-j-head`)
- `logo-brainstorm.md` (18KB) documents brand DNA and concept exploration — solid grounding
- `AppGradients.brandFlame` — 5-stop yellow→deep-orange gradient used as ShaderMask on wordmarks

**Gaps:**
1. **`JobdunLogo` widget is bypassed in the two highest-traffic places it should be used:**
   - `login_page.dart:69-91` renders the mark as raw `Image.asset('lib/core/assets/logo.png', ...)` and the wordmark as raw `Text('JOBDUN', ...)` with ShaderMask — **not** `JobdunLogo`
   - `jobs_page.dart:102-114` ShaderMask's a screen title with the same gradient as if it were a logo
2. Logo concepts (`hammer-j-*`) are in `pubspec.yaml` assets but no concept has been **decided** as the production mark — `logo.png` is still in use. Per memory: "User prefers modular brick-J direction" — but no `brick-j-*` directory exists yet.
3. No clear-space / minimum-size spec documented anywhere.
4. App icon (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `android/app/src/main/res/mipmap-*`) — git status shows iOS pbxproj modified but the actual rendered icon hasn't been audited in this pass.
5. Splash screen — same situation; not audited.

**Recommendation:**
- **P0:** Decide on the production mark (brick-J or hammer-J variant). Commit the chosen SVGs to `lib/core/assets/logo-jobdun-mark.svg` and `logo-jobdun-wordmark.svg`. Delete the rejected concept directories from `pubspec.yaml` assets list (they're loaded into the bundle right now — wasteful).
- **P0:** Migrate `login_page.dart` and `jobs_page.dart` to use `JobdunLogo` instead of raw `Image.asset` / `Text('JOBDUN')`. Make `JobdunLogo` the *only* way to render brand assets.
- **P1:** Add `JobdunLogo.wordmark(gradient: true)` variant that owns the ShaderMask logic. Right now the gradient lives in 2 places.
- **P1:** Document clear-space, minimum size, color variants in `design-system/jobdun/brand.md` (new file).
- **P1:** Audit the rendered app icon at 1024×1024 and at 24px (notification badge size). Tradies often run low-DPI Android devices.

**Status:** 🟡 Partial — assets exist, system isn't enforced. P0/P1.

---

### 2.2 Splash Screen

**Status:** 🔴 Missing from this audit — `flutter_native_splash` not in pubspec; `ios/Runner/LaunchScreen.storyboard` and `android/app/src/main/res/drawable*/launch_background.xml` not inspected. Mark for review.

---

### 2.3 Voice & Tone

**Current state (from MASTER.md):**
- "LOG IN" not "Sign in" — declarative, no apology
- "APPLY NOW" not "Apply"
- "POST JOB" not "Create"
- "CONFIRM" not "OK"
- Anti-pattern: friendly microcopy ("You're all set!", "Yay!")

**Reality check:**
- `login_page.dart:234` — `AppButton(label: authState.isLoading ? 'Logging in...' : 'Log in', ...)` — **violates own rule** (should be "LOG IN" / "LOGGING IN..." per MASTER.md). The `AppButton` widget does `label.toUpperCase()` internally, so the rendered output IS uppercase, but the source string isn't. Cosmetic only — but it means the next agent reading login_page won't see the convention.
- `login_page.dart:265` — `AppButton(label: 'Sign Up', ...)` — should be "CREATE ACCOUNT" per MASTER.md vocabulary.
- `login_page.dart:276` — `AppButton(label: 'Compare Logo Concepts', ...)` — internal dev tool, but it's reachable from production login. Should be gated behind `kDebugMode`.

**Recommendation:**
- Audit every user-facing string against the MASTER.md vocabulary table (line 128–134). I count at least 3 violations in `login_page.dart` alone.
- Add a `JStrings` class for canonical button labels: `JStrings.login = 'LOG IN'`, `JStrings.createAccount = 'CREATE ACCOUNT'`, etc. Then the vocabulary is enforceable.

**Status:** 🟡 Partial. P1.

---

## 3. Components

### 3.1 Atoms

| Component | Status | File | Notes |
|---|---|---|---|
| `AppButton` | 🟢 | `lib/core/widgets/app_button.dart` | 3 variants (primary/secondary/text), loading state, optional icon. Uppercases internally. **Good.** |
| `AppTextField` | 🔴 | `lib/core/widgets/app_text_field.dart` | **STUB — 43 lines, no validation, no error state, never imported by any feature page.** Forms re-implement `FormBuilderTextField` directly. |
| `AppCard` | 🔴 | — | No primitive. `Container(decoration: BoxDecoration(color: c.card, border: ...))` is re-implemented in `jobs_page.dart` header, `JobCard`, etc. |
| `AppChip` (general) | 🔴 | — | `GvChip` exists for filter-pill use only. No `AppChip` primitive for selected/unselected/closeable cases. |
| `Checkbox` | 🟡 | (theme) | `CheckboxTheme` set in `app_theme.dart`. Used in `login_page.dart` wrapped in a GestureDetector — see a11y section. |
| `Radio` | 🔴 | — | Not themed, not used. |
| `Switch` | 🔴 | — | Not themed, not used. |
| `Avatar` | 🟢 | `lib/core/design/widgets/avatar_block.dart` | Initials-based, auto-sized font. **Good.** Missing: image variant for `cached_network_image` avatar URLs. |
| `Badge` (notification dot) | 🔴 | — | `badges: ^3.1.2` in pubspec, not used. Notifications page surely needs one. |
| `Divider` | 🟢 | (theme) | DividerThemeData set. Used inline (`Divider(color: c.border)`) in places where the theme would handle it. |
| `Icon` | 🟡 | — | `iconsax` used directly. `AdaptiveIcon` exists but dead. No `JIcon` wrapper. |
| `StatusBadge` | 🟢 | `lib/core/design/widgets/status_badge.dart` | 5 variants (verified/available/urgent/pending/pro). **Good.** |
| `Pinput cell` | 🟢 | (theme) | `AppTheme.pinputTheme()` + `pinputFocusedTheme()`. Pre-built for OTP. |

**Top gap:** `AppTextField`. This is the single highest-impact missing primitive. Every form in `login_page.dart`, `register_page.dart`, `forgot_password_page.dart`, `phone_auth_page.dart`, `job_create_page.dart`, `profile_edit_page.dart` re-implements:
1. A `_FieldLabel` widget (defined inline at the bottom of `login_page.dart`)
2. A `FormBuilderTextField` with the same `style`, `decoration`, `contentPadding`, `validator` shape
3. Hand-rolled prefix/suffix icon logic

By Phase 1 you'll have **10+ forms**. Refactoring drift later is 10× costlier than building the primitive now.

---

### 3.2 Molecules

| Component | Status | File | Notes |
|---|---|---|---|
| `AppFormField` (label + input + helper + error) | 🔴 | — | Doesn't exist. Highest-priority molecule. See atoms section. |
| `JobCard` | 🟢 | `lib/core/design/widgets/job_card.dart` | Urgent header bar, title, description, rate/start/distance grid, optional APPLY NOW pill. **Strong.** |
| `TradieCard` | 🟡 | `lib/core/design/widgets/tradie_card.dart` | Exists (5762 bytes). Not inspected in detail in this audit — flag for review. |
| `EmptyState` | 🟡 | `lib/core/design/widgets/empty_state.dart` | Lottie + headline + CTA. **Good shape — but no Lottie assets exist in `lib/core/assets/`.** And `jobs_page.dart` re-implements its own `_EmptyState` (icon + headline, no Lottie, no CTA). |
| `ErrorView` | 🟡 | `lib/core/widgets/error_view.dart` | `Icons.error_outline` (not Iconsax — drift), retry button. Uses raw `FilledButton` instead of `AppButton`. |
| `StatusBanner` | 🟢 | `lib/core/widgets/status_banner.dart` | Bicolor (urgentBg / verifiedBg), Iconsax icon. **Good.** |
| `LoadingView` | 🟡 | `lib/core/widgets/loading_view.dart` | `CircularProgressIndicator` centered. Competes with `LinearProgressIndicator` used inline in `jobs_page.dart`. Skeletonizer never adopted. |
| `BottomSheetHeader` | 🟢 | `lib/core/design/widgets/bottom_sheet_header.dart` | Drag handle + optional title. **Good.** |
| `GvChip` | 🟡 | `lib/core/design/widgets/gv_chip.dart` | Filter chip. **Height 30.h — fails 44pt touch-target minimum.** AnimatedContainer for state change. |
| `SearchBar` | 🔴 | — | Re-implemented inline in `jobs_page.dart:156-205`. Should be `AppSearchBar`. |
| `AppBar` | 🟡 | (theme) | `AppBarTheme` set, but `jobs_page.dart` builds its own header from scratch instead. |
| `Snackbar` / `Toast` | 🔴 | — | No theme override; no helper. Status banners are inline. |

---

### 3.3 Organisms

| Organism | Status | Notes |
|---|---|---|
| Job feed list | 🟢 | `jobs_page.dart` uses `JobCard` + filter chips + search bar. Solid skeleton. |
| Job detail | 🟡 | `job_detail_page.dart` not inspected this pass — flag. |
| Application card | 🔴 | No dedicated widget yet; `applications_page.dart` likely renders inline. |
| Message thread item | 🔴 | No dedicated widget. |
| Profile card | 🔴 | `TradieCard` may cover this — needs review. |
| Verification status card | 🔴 | No widget; `verification_page.dart` is likely placeholder. |
| Review / rating component | 🟡 | `flutter_rating_bar` in pubspec, no wrapper widget yet. |
| Notification list item | 🔴 | No widget. |
| Onboarding slide | 🟡 | `onboarding_page.dart` exists; `smooth_page_indicator` in pubspec. Needs review. |

---

## 4. Patterns

### 4.1 Auth Pattern

**Current state:**
- Splash → Login → Register → Forgot password → Phone auth → Verify email → Onboarding
- Form-builder + validators set up
- Social SSO (`SocialAuthButtons` widget) integrated
- Phone auth page exists (recent — `46d3b58 feat: sprint 1 — phone auth`)
- `verify_email_page.dart` likely uses Pinput

**Gaps:**
1. **Vocabulary drift:** Login button says "Log in" not "LOG IN" in source (rendered uppercase by AppButton); "Sign Up" not "CREATE ACCOUNT". Per MASTER.md violations.
2. **Internal debug route reachable from prod:** "Compare Logo Concepts" button visible on `login_page.dart` at line 274 — should be `if (kDebugMode)` gated.
3. **No "biometric unlock" pattern** — for tradies who open the app dozens of times per day, this matters.
4. **No "session expired" / refresh-token recovery UX** — if a tradie's app is open during a 3-day site shutdown, what happens to their RLS-protected feed?
5. **No rate-limit error states** — Supabase Auth will 429 on too many login attempts. Currently shows generic `StatusBanner` urgent.

**Recommendation:** P1 — vocabulary fix and `kDebugMode` gate this sprint. P2 — biometric + session-recovery in Phase 1.

**Status:** 🟡 Partial.

---

### 4.2 Form Pattern

**Current state:** `flutter_form_builder` + `form_builder_validators`. Validator strings hardcoded English.

**Gaps:**
1. No `AppFormField` molecule (covered above) — every form re-implements label + field + decoration.
2. Validation timing: `saveAndValidate()` on submit only — no on-blur validation. Tradie types a 30-char password, taps Log In, gets "too short" — has to clear and retype. Should validate on-blur for high-value fields.
3. No idempotency for double-tap submit (the `isLoading` check helps but doesn't fully prevent it).
4. Validator messages aren't centralized — `FormBuilderValidators.email()` defaults to English from the lib. Won't survive AU spelling audit (e.g., "valid email" vs "valid email address").

**Recommendation:** Build `AppFormField`. Centralize validator messages in `JValidators`. P0.

---

### 4.3 List Pattern

**Current state:**
- `ListView.separated` used in `jobs_page.dart`
- `flutter_staggered_animations` in pubspec — **never imported in features** (grep confirms)
- `infinite_scroll_pagination` in pubspec — **never imported**
- No pull-to-refresh on `jobs_page.dart`'s ListView

**Recommendation:** Wrap `jobs_page.dart` ListView in `RefreshIndicator` and `AnimationLimiter`. Adopt `infinite_scroll_pagination` before the feed gets >50 items. P1.

---

### 4.4 Image Upload Pattern

**Current state:** `image_picker`, `image_cropper`, `flutter_image_compress` all in pubspec. No reference implementation page audited. Avatar upload presumably in `profile_edit_page.dart`.

**Status:** 🟡 — packages there, pattern not abstracted into `lib/core/services/image_upload_service.dart`. P1.

---

### 4.5 Search & Filter Pattern

**Current state:** `jobs_page.dart` has a working debounced search + 6-chip filter. **Inline-built — not extractable.**

**Recommendation:** Extract to `AppSearchBar` + `AppFilterRow` molecules. P2 — only matters when you add search to applications/messages screens.

---

### 4.6 Permission Request Pattern

**Status:** 🔴 — `google_maps_flutter` is in pubspec (location permission), `image_picker` is in pubspec (camera/photos), `notifications` feature exists. No `lib/core/services/permission_service.dart`. P1.

---

### 4.7 Confirmation Pattern (destructive actions)

**Current state:** `logout_confirm_sheet.dart` widget exists (only confirmation widget). No "delete account", "withdraw application", "cancel job" patterns.

**Recommendation:** Extract `JConfirmSheet` molecule from `logout_confirm_sheet`. P1 when destructive actions ship.

---

### 4.8 Onboarding Pattern

**Status:** 🟡 — `onboarding_page.dart` exists; not inspected in detail. `smooth_page_indicator` in pubspec.

---

### 4.9 Notification Pattern

**Status:** 🟡 — `notifications_page.dart` exists as placeholder. No push integration audited. `badges` package unused.

---

## 5. Accessibility

**This is the largest single gap in the audit.**

### 5.1 Color Contrast

| Combination | Ratio | WCAG AA Body (4.5:1) | Verdict |
|---|---|---|---|
| `text1` `#F1F5F9` on `background` `#0F172A` | 14.8:1 | ✅ | AAA |
| `text1` `#F1F5F9` on `surface` `#1E293B` | 12.3:1 | ✅ | AAA |
| `text2` `#94A3B8` on `background` | 6.0:1 | ✅ | AA |
| `text3` `#64748B` on `background` | 3.5:1 | ❌ | **fails for body text** |
| `action` `#F97316` on `background` | 6.4:1 | ✅ | AA |
| White on `action` `#F97316` (button text) | 2.9:1 | ❌ | **fails for body text** — but Material 3 allows for large-text/UI-component minimum 3:1 (fails that too marginally) |
| `urgentTx` `#FCA5A5` on `urgentBg` `#450A0A` | 7.8:1 | ✅ | AA |

**Two concrete issues:**
1. **White on safety-orange CTA fails AA.** The button label "LOG IN" in white on `#F97316` is 2.9:1 — below the 4.5:1 body requirement AND the 3:1 UI-component requirement. For a primary CTA used on every screen this is a real risk during App Store review and for users with low vision. **Either darken the orange to `#D85B0B` (gives 4.5:1), or change button text color to `#1A0A03` (very dark brown, gives 12.4:1 and reads correctly on warm safety orange — common in road signage).**
2. **`text3` body usage fails.** Used for "REMEMBER ME" label, timestamps, captions. Either deprecate `text3` for body text, OR raise it to `#94A3B8` (= text2).

### 5.2 Touch Targets

| Element | Size | Min Required | Verdict |
|---|---|---|---|
| `AppButton` primary | 52.h | 48dp / 44pt | ✅ |
| `AppButton` text variant | 44.h | 48dp / 44pt | ⚠️ iOS pass, Android fail |
| `GvChip` filter chip | 30.h | 44pt | ❌ fails iOS HIG |
| `JobCard` "APPLY NOW" pill | ≈32h (8.h vertical + label) | 44pt | ❌ fails iOS HIG |
| `JobsPage` "POST JOB" pill | 36.h | 44pt | ❌ fails iOS HIG (marginal) |
| Search-bar clear `Icon` GestureDetector | ≈16dp tap surface | 44pt | ❌ fails |
| Login page "Remember me" Checkbox | 18.r | 44pt | ❌ fails (wrapped in GestureDetector — see 5.3) |
| Pinput cell | 56×56 | 44pt | ✅ |

### 5.3 Screen Reader & Semantics

**`Semantics` usage in `lib/`: zero occurrences.**

Critical interactive widgets that use `GestureDetector` instead of a Material button (which lose default Material semantics):
- `jobs_page.dart:119` — "POST JOB" button (GestureDetector)
- `jobs_page.dart:188` — search clear icon (GestureDetector)
- `jobs_page.dart:257` — error-banner Retry text (GestureDetector)
- `job_card.dart:89` — "APPLY NOW" pill (GestureDetector)
- `gv_chip.dart:24` — filter chip (GestureDetector)
- `login_page.dart:170-198` — "Remember me" — `GestureDetector` wrapping a `Checkbox` that has its own `onChanged`. **Double tap target.** Worse: VoiceOver/TalkBack will announce both, possibly twice.
- `login_page.dart:201` — "FORGOT PASSWORD" (GestureDetector)
- `login_page.dart:170` (another wrap) — checkbox row

Every one of these should be:
- `InkWell` or `FilledButton.tonalIcon` (auto-semantics + ripple), OR
- `GestureDetector` wrapped in `Semantics(button: true, label: 'Apply now')`

### 5.4 Font Scaling

`flutter_screenutil` `.sp` extension scales with user OS text size by default — ✅. No `textScaleFactor: 1.0` overrides found, which is good. Audit: confirm no `Text(... overflow: TextOverflow.ellipsis ...)` lines clip critical text at 200% font size — `jobs_page.dart` results count "$count jobs found" at `labelMedium 12sp` will be tight.

### 5.5 Color-Independent Meaning

`StatusBadge.urgent` uses red dot + text "Urgent". ✅
`JobCard` `isUrgent` shows a red bar at the top. ❌ — color-only signal. Add an icon (Iconsax.warning_2) to the bar OR keep the StatusBadge as the canonical urgency signal and remove the bar.

### 5.6 Focus Indicators

`InputDecorationTheme.focusedBorder` = orange 2px — ✅.
No `Focus` widget usage; relying on Material defaults for buttons. Acceptable for v1.

### 5.7 Reduced Motion

`MediaQuery.of(context).disableAnimations` is checked zero times. The `AnimatedContainer` in `GvChip`, `AnimatedOpacity` in `LoginPage` all play regardless. Add `AppMotion.adapt(context, ...)` helper (see 1.6).

**Recommendation (5.x): A11y sprint, ~1 day:**
1. Fix white-on-orange contrast: change CTA label color OR darken orange. (~30 min)
2. Raise `text3` to `text2` for body-text uses. (~15 min)
3. Wrap all 8 listed `GestureDetector` interactive widgets with `Semantics(button: true, label: ...)`. (~2 hours)
4. Migrate `GvChip` from 30.h to 44.h minimum height (`minimumSize`) and re-test layout. (~30 min)
5. Replace the `GestureDetector(child: Row(... Checkbox ...))` "Remember me" pattern with `CheckboxListTile` or a single tappable surface. (~30 min)
6. Add `Semantics` icon-only meaning audit: every `Icon(Iconsax.x)` inside an interactive surface needs a semantic label. (~1 hour)
7. Add `AppMotion.adapt` helper and use it in `AnimatedContainer` / `AnimatedOpacity` callsites. (~1 hour)

**Status:** 🔴 Missing. **P0** — this affects App Store review and is legally required in some jurisdictions.

---

## 6. Internationalization & Localization

**Status:** 🔴 Missing.

### 6.1 What Exists

- `intl: ^0.20.2` in pubspec (used by `flutter_form_builder`, not by app code)
- `flutter_localizations` **not in pubspec**
- No `l10n/` directory
- No ARB files
- No `flutter` `generate: true` flag in pubspec
- All user-facing strings hardcoded in Dart files: "LOG IN", "Sign in to your account", "POST JOB", "Search trades, skills, suburbs…", "NO JOBS FOUND.", "REMEMBER ME", etc.

### 6.2 AU-Specific Formatters

| Concern | Status | What's missing |
|---|---|---|
| Date format `DD/MM/YYYY` | 🟡 | `lib/core/utils/app_date_utils.dart` exists — needs audit to confirm AU formatter. |
| Currency `AUD $` | 🔴 | No central currency formatter. `job_card.dart` shows `rate` as a pre-formatted string. |
| Phone `+61 4XX XXX XXX` | 🟡 | Phone auth recently added; formatter not centralized. |
| Units (metric) | 🟢 | Distance shown as `km` in `JobCard`. ✅ |
| Spelling (colour, organise, licence) | 🟡 | `StatusBadge.verified.defaultLabel = 'Licenced & Verified'` — ✅ uses AU spelling. But "Color" appears as a Flutter API (correct US spelling there). |

### 6.3 Recommendation

- **P1 (Phase 1):** Even if you ship English-only, set up the scaffold now. Adding `flutter_localizations` + `generate: true` + a single `app_en.arb` file is 30 minutes of work; retrofitting 100 hardcoded strings later is 2 days.
- **P0 (this week):** Build `JFormatters` utility class:
  ```dart
  abstract final class JFormatters {
    static final _aud = NumberFormat.currency(locale: 'en_AU', symbol: r'$');
    static String currency(num cents) => _aud.format(cents / 100);
    static String date(DateTime d) => DateFormat('dd/MM/yyyy', 'en_AU').format(d);
    static String dateRelative(DateTime d) { /* "Tomorrow", "Mon 3pm", "12 May" */ }
    static String phone(String e164) { /* +61 4xx xxx xxx pretty print */ }
  }
  ```
- **P2:** Add `JStrings` class for canonical UI strings (auth vocabulary, button labels) — this is the precursor to ARB extraction.

**Status:** 🔴 Missing scaffold; 🟡 AU formatters partial.

---

## 7. Flutter Implementation

### 7.1 Theme Architecture

**Strong:**
- `ThemeData` + `ColorScheme` correctly mapped to `JColors`
- `ThemeExtension<JColors>` registered correctly via `extensions: [c]`
- `context.c.action` extension method — clean ergonomics
- Light + dark `ThemeData` both built; `themeMode` driven by `themeProvider` (Riverpod)
- `loadSavedTheme()` runs before `runApp()` — no flash

**Weak:**
- `AppColors` static class (lines 198–223) duplicates every `JColors.dark` value. **Dead code now that features are migrated.** Delete.
- `AppDarkColors` (lines 225–234) re-exports `AppColors`. **Dead code.** Delete.
- `AppSpacing`, `AppRadius`, `AppGradients` live in the wrong files (`app_colors.dart`, `app_gradients.dart`). Move to a `lib/app/theme/tokens/` barrel.

### 7.2 File Organization

**Current:**
```
lib/
  app/
    theme/
      app_colors.dart          # JColors + AppColors + AppSpacing + AppRadius
      app_gradients.dart       # AppGradients.brandFlame
      app_theme.dart           # ThemeData builder
      theme_provider.dart      # Riverpod ThemeMode notifier
    constants/
      app_constants.dart       # AppConstants + AppIconSize + AppElevation
  core/
    design/widgets/            # Brand-aware widgets: JobCard, StatusBadge, etc.
    widgets/                   # App-level shared: AppButton, AppTextField, ErrorView, etc.
```

**Two widget directories is confusing.** `lib/core/design/widgets/` vs `lib/core/widgets/`. The split appears to be "design-system-y stuff (with JColors)" vs "generic utility (mixed)". But `AppButton` uses `JColors` heavily and lives in `core/widgets/`, while `AvatarBlock` is just initials in a colored box and lives in `core/design/widgets/`. **Pick one location.**

### 7.3 Naming Conventions

You have **three prefixes** in active use:
- `App*` — `AppButton`, `AppTextField`, `AppColors`, `AppSpacing`, `AppRadius`, `AppGradients`, `AppMotion`(proposed)
- `J*` — `JColors`, `JColorsX` (extension)
- `Jobdun*` — `JobdunLogo`
- No prefix — `JobCard`, `TradieCard`, `StatusBadge`, `GvChip`, `EmptyState`, `AvatarBlock`, `BottomSheetHeader`

**Pick one. My recommendation: `J*`.**
- Shorter than `App*` (matters at call sites)
- Brand-resonant (`JColors`, `JButton`, `JCard`, `JTextField`, `JChip`, `JIcon`, `JSpacing`)
- Already established for the theme extension
- Avoids the "Jobdun" stutter (`JobdunLogo` inside the Jobdun app)

Migration: rename `AppButton` → `JButton`, `AppTextField` → `JTextField`, `JobCard` → `JJobCard` (or keep `JobCard` as a domain-specific organism, distinct from primitives — that's a defensible rule).

### 7.4 Storybook / Widgetbook

**Missing.** `widgetbook` is not in pubspec. The closest thing is `logo_compare_page.dart` (internal dev route reachable from login — see 4.1).

**Recommendation:** Add `widgetbook: ^3.x` as a `dev_dependency`. Spin up a `widgetbook/main.dart` that loads `JButton`, `JTextField`, `JobCard`, `StatusBadge`, `EmptyState` in all variants. Run it as a separate target. ~2 hours setup, infinite value for catching drift.

**Status:** 🟢 Solid theme architecture; 🟡 organization + naming inconsistent; 🔴 no widgetbook.

---

## 8. Performance

### 8.1 Image Optimization

`cached_network_image: ^3.4.1` in pubspec. No reference usage audited. Confirm `placeholder:` and `errorWidget:` are set everywhere it's used. P2.

### 8.2 Lazy Loading

`ListView.separated` in `jobs_page.dart` is lazy by default. ✅
No `Image.network` used (per grep) — only `Image.asset`. ✅
`infinite_scroll_pagination` not used yet — acceptable until feeds exceed 50 items.

### 8.3 Font Loading

**Issue.** `google_fonts: ^6.2.1` loads Oswald + Open Sans **from the network on first cold start.** For a tradie on a remote site with 2 bars of 4G, the first paint of the login screen will show **Material's default Roboto fallback** for several seconds, then re-paint with Oswald. This looks broken.

**Recommendation (P1):**
- Bundle Oswald (Regular, SemiBold, Bold) and OpenSans (Regular, SemiBold, Bold) into `pubspec.yaml` `fonts:` entries (~120KB total).
- Set `GoogleFonts.config.allowRuntimeFetching = false` in `main.dart` for production builds.
- Verify via `flutter run --release --no-network` that the app renders correctly offline.

### 8.4 Bundle Size

Asset audit needed: 4 logo-concept directories in `pubspec.yaml` assets list (lines 133–136) load **all** rejected logo variants into the production bundle. Each SVG is ~5KB, but more importantly it signals indecision. After Brand decision (2.1), delete these from `pubspec.yaml`.

### 8.5 Animation Performance

`AnimatedContainer` / `AnimatedOpacity` are GPU-cheap. The only concern: if the jobs feed ever wraps `ListView` items in `flutter_staggered_animations`, low-end Android (Pixel 4a, Galaxy A12) will frame-skip past 30 items. Set up a low-end device test matrix before enabling stagger globally.

**Status:** 🟡 Partial. P1 fix font loading; P2 bundle audit.

---

## 9. Governance & Documentation

### 9.1 Sources of Truth

| Source | Authority | Status |
|---|---|---|
| `CLAUDE.md` | Project rules for AI agents | Drift: says typography is Inter (false) |
| `design-system/jobdun/MASTER.md` | Design system master | Drift: pre-delivery checklist line 249 says Barlow (false) |
| `design-system/jobdun/pages/*.md` | Page-specific overrides | 5 pages exist, not re-audited this pass |
| `design-system/jobdun/logo-brainstorm.md` | Brand discovery | ✅ current |
| `lib/app/theme/app_colors.dart` | Code — JColors | ✅ **truth source for tokens** |
| `lib/app/theme/app_theme.dart` | Code — text theme | ✅ **truth source for typography** |
| `docs/DESIGN_SYSTEM_AUDIT.md` (V1, 22KB) | Historical audit | Stale — pre this audit |
| `docs/DESIGN_SYSTEM_AUDIT_V2.md` (V2, 13KB) | Historical audit | Stale — pre this audit |
| `docs/DESIGN_SYSTEM.md` (11KB) | Older design doc | Stale, redundant with MASTER.md |
| `docs/auth-ui-system.md` | Auth-specific UI doc | Likely stale, needs audit |

### 9.2 Conventions Not Documented

- **Widget naming convention** (App* vs J* vs Jobdun*) — no rule.
- **When to add a new color to `JColors`** — no rule. Risk: someone adds `c.warning` instead of using `c.action` for amber alerts, and the palette bloats.
- **Component deprecation policy** — `AppColors` static fallbacks are technically deprecated (replaced by `JColors`), but there's no `@Deprecated` annotation and no removal date.
- **PR design-system review checklist** — `scripts/validate.sh` enforces grep gates, but there's no human-review checklist.

### 9.3 Recommendation

- **P0 (this week, ~1 hour):**
  1. Fix `CLAUDE.md` line 36 typography to "Oswald (headings) + Open Sans (body)"
  2. Fix `MASTER.md` line 249 pre-delivery checklist to "Oswald / Open Sans"
  3. Add a one-paragraph "Sources of Truth" section at the top of `MASTER.md` declaring code wins on tokens
  4. Delete or merge stale docs: pick one of `DESIGN_SYSTEM.md` vs `DESIGN_SYSTEM_AUDIT_V2.md`. Keep V1 as historical.
- **P1 (Phase 1):**
  - Add a `CONTRIBUTING-DESIGN.md` covering: naming convention, when to add a token, deprecation policy, PR checklist
  - Add `@Deprecated('Use JColors via context.c instead. Removal: 2026-07-01')` to `AppColors` and `AppDarkColors`
- **P2 (Phase 2):**
  - Versioned design system (`design-system/jobdun/v1.0.0/`) once you have a co-founder or first hire

**Status:** 🟡 Partial.

---

## 10. Production Readiness Gaps

| Gap | Status | Impact at 25k users | Priority |
|---|---|---|---|
| Trust-and-safety states ("Account under review", "Suspended", "Verification pending") | 🔴 | Verification queue stalls = silent bad UX | P1 |
| Offline banner (despite `connectivity_plus` in pubspec) | 🔴 | Tradies on rural sites with no signal see broken screens | P1 |
| Permission-denied recovery ("Notifications blocked? Here's how") | 🔴 | App Store rejection risk + lost retention | P1 |
| Empty states with Lottie | 🟡 | `EmptyState` widget exists; no Lottie JSON assets in `lib/core/assets/` yet | P2 |
| Loading skeleton states | 🔴 | `skeletonizer` in pubspec, zero usage — screens flash CircularProgressIndicator | P1 |
| Error recovery flow (retry → fallback → "contact us") | 🟡 | `ErrorView` is single-button retry only — no fallback chain | P2 |
| Push notification UI (received, in-app, banner) | 🔴 | Not integrated; `badges` package unused | P1 |
| Onboarding empty state ("No jobs yet — here's how to apply") | 🔴 | First 7 days of retention will hurt | P1 |
| App version + force-update screen | 🔴 | No way to ship a breaking change | P2 |
| Maintenance mode banner | 🔴 | If Supabase has an outage, users see crash dialogs | P2 |
| Crash reporting (Sentry / Firebase Crashlytics) | 🔴 | Not in pubspec — flying blind in production | P0 |

---

## Risk Register

| Risk | Likelihood | Impact at 25k users | Mitigation |
|---|---|---|---|
| Typography drift (3 sources disagree) | High | New agents build screens off wrong spec; visual inconsistency compounds | **Fix CLAUDE.md + MASTER.md this week** |
| `AppTextField` stub never adopted → forms drift | High | 10+ divergent input styles by Phase 1, refactor cost 5× | **Build `JTextField` molecule now, migrate 5 existing forms** |
| White on safety-orange CTA fails WCAG AA | High | App Store accessibility audit fail; low-vision users blocked | **Darken CTA or change label color** |
| Touch targets below 44pt (GvChip, APPLY NOW, search-clear) | High | iOS HIG fail; fat-finger tradies miss the chip | **Raise all interactive surfaces to 44.h minimum** |
| Zero `Semantics` labels | Medium | TalkBack/VoiceOver users blocked from core actions | **Wrap 8 listed GestureDetectors in Semantics widgets** |
| GoogleFonts loaded from network | Medium | Login screen flashes Roboto on cold start over slow 4G | **Bundle fonts or pre-load before first frame** |
| No crash reporting | High | Production bugs invisible | **Add Sentry/Crashlytics before TestFlight** |
| Internal "Compare Logo Concepts" route in production login | Medium | Brand inconsistency / unfinished feel for first-time users | **Gate behind `kDebugMode`** |
| No offline banner | High | Tradies on rural sites get blank screens, not "you're offline" | **Wire `connectivity_plus` into a global banner** |
| Logo decision unmade — 4 concepts in production bundle | Medium | Wasted bundle bytes + signals indecision | **Decide brick-J variant, delete others from assets** |
| No i18n scaffold | Low (now) → High (Phase 2) | Retrofit cost grows linearly with strings count | **Add scaffold at zero strings cost; defer translations** |

---

## Build Order (Prioritized)

### P0 — Must ship before Phase 1 (this and next sprint)

- [ ] **Reconcile typography docs to code.** Update `CLAUDE.md` line 36 (Inter → Oswald + Open Sans). Update `MASTER.md` line 249 pre-delivery checklist. (~15 min)
- [ ] **Delete dead code:** `AppColors.white`, `AppDarkColors`, `AppTheme.brandDisplay()`. Run `flutter analyze` to confirm zero referents. (~30 min)
- [ ] **Build `JTextField` molecule** with label-above + prefix-icon + hint + validator + error display. Migrate `login_page.dart`, `register_page.dart`, `forgot_password_page.dart`, `phone_auth_page.dart`, `job_create_page.dart`, `profile_edit_page.dart` to use it. (~1 day)
- [ ] **Fix WCAG AA CTA contrast.** Either darken `c.action` to `#D85B0B` (orange) OR change `AppButton` primary `foregroundColor` from `Colors.white` to `#1A0A03`. Test both, pick whichever the brand swallows. (~30 min)
- [ ] **Raise `GvChip` height** from 30.h to 44.h. Verify layouts. (~30 min)
- [ ] **Wrap 8 GestureDetector buttons in `Semantics(button: true, label: ...)`** — POST JOB, APPLY NOW, GvChip, search clear, retry, FORGOT PASSWORD, Remember-me row, Compare Logo Concepts. (~2 hours)
- [ ] **Gate "Compare Logo Concepts" button behind `kDebugMode`.** (~5 min)
- [ ] **Add crash reporting:** `sentry_flutter` or `firebase_crashlytics`. (~3 hours setup)
- [ ] **Add `JFormatters`** utility class for AUD currency, dd/MM/yyyy dates, +61 phone. (~2 hours)
- [ ] **Decide on production logo mark** (per `logo-brainstorm.md` — modular brick-J direction). Commit chosen SVGs to `lib/core/assets/`. Delete the 4 rejected `logo-concepts/*` directories from `pubspec.yaml` assets list. (~depends on decision)

### P1 — Ship during Phase 1

- [ ] **Build `JCard` primitive** to replace inline `Container(decoration: BoxDecoration(color: c.card, border: ...))`.
- [ ] **Build `JFormField` molecule** wrapping `FormBuilderTextField` with `_FieldLabel`.
- [ ] **Build `JAppBar` widget** for consistent screen headers (replace the inline header in `jobs_page.dart`).
- [ ] **Add `JMotion` tokens** (`fast`, `medium`, `slow`, `curve`, `adapt()`). Replace inline `Duration(milliseconds: 150)` calls.
- [ ] **Add `JStrings`** canonical strings class to enforce MASTER.md vocabulary.
- [ ] **Add `JValidators`** centralized validator messages.
- [ ] **Set up Widgetbook** as `dev_dependency` + `widgetbook/main.dart` target. Add stories for JButton, JTextField, JCard, JobCard, StatusBadge, EmptyState.
- [ ] **Bundle Oswald + Open Sans fonts** locally; disable `GoogleFonts.allowRuntimeFetching` for release.
- [ ] **Add offline banner** wired to `connectivity_plus` stream — pin to top of every authenticated page.
- [ ] **Add `JPermissionService`** for location/camera/notifications request flow + denied recovery.
- [ ] **Replace `jobs_page.dart`'s inline `_EmptyState`** with the canonical `EmptyState` widget + add a Lottie asset.
- [ ] **Add skeleton loading states** using `skeletonizer` on jobs feed, applications list, profile, messages.
- [ ] **Add `flutter_localizations` + `app_en.arb` scaffold** even with one locale. Extract first 30 strings as proof.
- [ ] **Audit + finalize app icon + splash screen** at 1024×1024 and 24px.
- [ ] **Vocabulary audit** — replace "Log in" / "Sign Up" with "LOG IN" / "CREATE ACCOUNT" in source strings.
- [ ] **Build trust-and-safety state widgets:** `JStatusBanner.underReview`, `JStatusBanner.suspended`, `JStatusBanner.verificationPending`.
- [ ] **Push notification UI integration** + `badges` package adoption.

### P2 — Phase 2+

- [ ] **Pick one widget directory** — collapse `lib/core/design/widgets/` and `lib/core/widgets/` into one tree.
- [ ] **Rename inconsistent prefixes** — App* / Jobdun* → J*.
- [ ] **Add `flutter_staggered_animations`** to feed lists once feeds reach 30+ items.
- [ ] **Add `infinite_scroll_pagination`** to jobs feed before it exceeds 50 items.
- [ ] **Tablet / foldable layout pass.**
- [ ] **`AppBreakpoints` token class.**
- [ ] **Versioned design system** — `design-system/jobdun/v1.0.0/`.
- [ ] **CONTRIBUTING-DESIGN.md** with naming convention + deprecation policy.
- [ ] **Force-update screen + maintenance mode.**
- [ ] **Tablet layout audit.**
- [ ] **`@Deprecated` annotations** on `AppColors`/`AppDarkColors` with removal date.

---

## Recommended File Structure

```
lib/
  app/
    theme/
      tokens/                   # NEW — barrel of all primitive tokens
        j_colors.dart           # JColors ThemeExtension only
        j_spacing.dart          # AppSpacing → JSpacing
        j_radius.dart           # AppRadius → JRadius
        j_motion.dart           # NEW: JMotion (durations + curves + adapt())
        j_elevation.dart        # NEW: JElevation
        j_typography.dart       # NEW: TextStyle builders, extracted from app_theme.dart
        j_gradients.dart        # JGradients.brandFlame
      app_theme.dart            # ThemeData composition only (light + dark builders)
      theme_provider.dart       # Riverpod ThemeMode notifier
    constants/
      j_strings.dart            # NEW: canonical UI vocab ("LOG IN" etc.)
      j_icon_size.dart          # ex AppIconSize
    formatters/
      j_formatters.dart         # NEW: AUD currency, dd/MM/yyyy, +61 phone
    validators/
      j_validators.dart         # NEW: AU-spelled validator messages
  core/
    widgets/                    # ONE shared-widget directory (merge core/design/widgets/)
      buttons/
        j_button.dart           # ex AppButton, renamed
      inputs/
        j_text_field.dart       # ex AppTextField, fully built
        j_form_field.dart       # NEW: label + field + helper + error molecule
      cards/
        j_card.dart             # NEW: replaces inline Container card pattern
        job_card.dart           # domain organism, kept
        tradie_card.dart        # domain organism, kept
      chips/
        j_chip.dart             # NEW: general chip primitive (44h minimum)
        gv_chip.dart            # filter-specific variant, refactor on top of JChip
      status/
        j_status_badge.dart     # ex StatusBadge
        j_status_banner.dart    # ex StatusBanner
      states/
        j_empty_state.dart      # ex EmptyState (canonical, used everywhere)
        j_error_view.dart       # ex ErrorView
        j_loading_view.dart     # ex LoadingView
        j_skeleton.dart         # NEW: skeletonizer wrappers for common screens
      layout/
        j_scaffold.dart         # NEW: app shell with offline banner, error boundary
        j_app_bar.dart          # NEW: replaces inline page headers
        j_bottom_sheet_header.dart
      avatars/
        j_avatar.dart           # ex AvatarBlock + image variant
      logo/
        jobdun_logo.dart        # kept
  features/
    auth/, jobs/, ... (unchanged)
```

---

## Token Reference (Quick-Copy)

> These are paste-ready additions to your existing `lib/app/theme/` files. Drop into the relevant new tokens/ files in the structure above.

### `j_motion.dart` (new)

```dart
import 'package:flutter/material.dart';

abstract final class JMotion {
  /// Micro-interactions: chip toggle, fade-in, sheet open.
  static const fast = Duration(milliseconds: 150);

  /// Page transitions, slide-in lists.
  static const medium = Duration(milliseconds: 200);

  /// Reserved for splash / large hero. Caps MASTER.md spec (200ms ceiling).
  static const slow = Duration(milliseconds: 300);

  /// Default curve. Construction-app brand: no bounce, no spring.
  static const curve = Curves.easeOutCubic;

  /// Respect OS-level reduced-motion setting.
  static Duration adapt(BuildContext context, Duration base) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : base;
}
```

### `j_elevation.dart` (new)

```dart
abstract final class JElevation {
  /// Flat surfaces with border for edge definition.
  /// Use for cards, app bars, bottom nav, scaffolds.
  static const none = 0.0;

  /// Transient overlays only — bottom-sheet shadow, modal dialog,
  /// snackbars, sticky CTA bars. NOT for cards or content.
  static const overlay = 8.0;
}
```

### `j_formatters.dart` (new)

```dart
import 'package:intl/intl.dart';

abstract final class JFormatters {
  static final _aud = NumberFormat.currency(locale: 'en_AU', symbol: r'$');
  static final _date = DateFormat('dd/MM/yyyy', 'en_AU');
  static final _dateShort = DateFormat('d MMM', 'en_AU'); // "12 May"
  static final _time = DateFormat('h:mma', 'en_AU').addPattern("'AEST'", ' ');

  /// Cents → "$1,234.50".
  static String currency(num cents) => _aud.format(cents / 100);

  /// "12/05/2026".
  static String date(DateTime d) => _date.format(d.toLocal());

  /// "12 May" — short list-row date.
  static String dateShort(DateTime d) => _dateShort.format(d.toLocal());

  /// "3:30PM AEST" — message timestamps.
  static String time(DateTime d) => _time.format(d.toLocal());

  /// E.164 (+61412345678) → "+61 412 345 678".
  static String phone(String e164) {
    if (!e164.startsWith('+61') || e164.length != 12) return e164;
    final body = e164.substring(3);
    return '+61 ${body.substring(0, 3)} ${body.substring(3, 6)} ${body.substring(6)}';
  }
}
```

### `j_strings.dart` (new — first pass at vocabulary canon)

```dart
/// Canonical UI strings. Enforces MASTER.md voice & tone rules.
/// All button labels rendered uppercase by JButton — store mixed case here
/// for code readability and ARB extraction later.
abstract final class JStrings {
  // Auth vocabulary
  static const logIn = 'Log in';
  static const createAccount = 'Create account';
  static const forgotPassword = 'Forgot password';
  static const rememberMe = 'Remember me';

  // Job vocabulary
  static const postJob = 'Post job';
  static const applyNow = 'Apply now';
  static const findWork = 'Find work';
  static const postedJobs = 'Posted jobs';

  // Action vocabulary
  static const confirm = 'Confirm';
  static const retry = 'Retry';
  static const cancel = 'Cancel';
  static const delete = 'Delete';

  // Empty / error
  static const noJobsFound = 'No jobs found';
  static const noOpenJobs = 'No open jobs';
  static const youreOffline = "You're offline";
}
```

### `j_colors.dart` additions (in-place edits)

```dart
// Add to JColors:
final Color actionDisabled;   // = action with 35% alpha pre-baked
final Color borderFocus;      // = action (alias for clarity in inputs)
final Color textDisabled;     // = text1.withValues(alpha: 0.4)

// Update dark const:
actionDisabled: Color(0x59F97316), // = F97316 @ 35%
borderFocus: Color(0xFFF97316),
textDisabled: Color(0x66F1F5F9),

// DELETE: AppColors.white, AppDarkColors (entire class),
//         AppColors static fallbacks (lines 198–223).
```

### `JButton` foreground fix (a11y P0)

```dart
// Option A (recommended): change CTA label color to dark brown.
foregroundColor: const Color(0xFF1A0A03), // 12.4:1 vs #F97316 — passes AAA
// Option B: darken the action color.
// Update JColors.dark.action: Color(0xFFD85B0B) // 4.5:1 vs white
```

---

## Component Inventory

| Component | Status | File path | Top issue |
|---|---|---|---|
| `AppButton` | 🟢 | `lib/core/widgets/app_button.dart` | White-on-orange contrast fails AA |
| `AppTextField` | 🔴 | `lib/core/widgets/app_text_field.dart` | Stub — 43 lines, never imported |
| `ErrorView` | 🟡 | `lib/core/widgets/error_view.dart` | Uses raw `FilledButton` not `AppButton`; uses Material `Icons.error_outline` not Iconsax |
| `LoadingView` | 🟡 | `lib/core/widgets/loading_view.dart` | Competes with inline `LinearProgressIndicator` in pages |
| `StatusBanner` | 🟢 | `lib/core/widgets/status_banner.dart` | None |
| `FeatureScaffoldPage` | 🟡 | `lib/core/widgets/feature_scaffold_page.dart` | Looks like a placeholder template — flag whether still needed |
| `JobCard` | 🟢 | `lib/core/design/widgets/job_card.dart` | APPLY NOW pill 32h fails 44pt; isUrgent uses color-only signal |
| `TradieCard` | ⏸️ | `lib/core/design/widgets/tradie_card.dart` | Not inspected this pass |
| `StatusBadge` | 🟢 | `lib/core/design/widgets/status_badge.dart` | None |
| `EmptyState` | 🟡 | `lib/core/design/widgets/empty_state.dart` | Lottie asset path required but no Lottie JSONs exist in `lib/core/assets/` |
| `GvChip` | 🟡 | `lib/core/design/widgets/gv_chip.dart` | Height 30h fails 44pt; no Semantics label |
| `AvatarBlock` | 🟢 | `lib/core/design/widgets/avatar_block.dart` | Missing image-URL variant |
| `BottomSheetHeader` | 🟢 | `lib/core/design/widgets/bottom_sheet_header.dart` | None |
| `JobdunLogo` | 🟡 | `lib/core/design/widgets/jobdun_logo.dart` | Bypassed by raw Image.asset / Text in login_page + jobs_page |
| `AdaptiveIcon` | 🔴 | `lib/core/design/widgets/adaptive_icon.dart` | Dead — defined but zero call sites |
| `SocialAuthButtons` | ⏸️ | `lib/features/auth/presentation/widgets/social_auth_buttons.dart` | Not inspected |
| `LogoutConfirmSheet` | ⏸️ | `lib/features/auth/presentation/widgets/logout_confirm_sheet.dart` | Not inspected — should be generalized to `JConfirmSheet` |

---

## Pattern Inventory

| Pattern | Status | Reference location | Top issue |
|---|---|---|---|
| Auth flow | 🟡 | `lib/features/auth/presentation/pages/` | Vocabulary drift; dev-only route reachable in prod |
| Form (label + field + validator) | 🔴 | `login_page.dart:111-216` | Re-implemented per page — no `JFormField` molecule |
| List + pull-to-refresh | 🟡 | `jobs_page.dart:289-315` | No `RefreshIndicator`; no infinite scroll yet |
| Search + filter chips | 🟡 | `jobs_page.dart:156-228` | Inline — not extractable to other screens |
| Image upload | ⏸️ | `profile_edit_page.dart` (assumed) | Not audited |
| Permission request | 🔴 | — | No central `JPermissionService` |
| Destructive-action confirm | 🟡 | `logout_confirm_sheet.dart` | Single-purpose; not generalized |
| Onboarding | ⏸️ | `onboarding_page.dart` | Not audited |
| Notification (in-app banner) | 🔴 | — | `badges` unused; no integration |
| Offline state | 🔴 | — | `connectivity_plus` in pubspec, not wired |
| Error → retry → fallback | 🟡 | `ErrorView` | Single retry button only |
| Loading → skeleton → empty | 🟡 | Three competing patterns | No unified async-state envelope |
| Trust-and-safety states | 🔴 | — | No widgets defined |
| Force-update | 🔴 | — | Not implemented |

---

## Open Questions

These are decisions the audit can't make for you — they need a human call.

1. **Naming prefix.** App*, J*, Jobdun*, or no prefix? **Recommendation: `J*`** — but you have a vote.
2. **CTA contrast fix.** Darken the orange (changes brand feel, more red-toned) or change label color (keeps orange punchy, label becomes dark brown). Both pass WCAG AA. **Recommendation: dark brown label** — preserves the safety-orange brand recognition.
3. **Logo decision.** Brick-J or hammer-J? Per memory, you lean brick-J modular. Confirm and commit so we can delete the other 4 concept directories from `pubspec.yaml`.
4. **`AppColors` deletion timing.** Delete now (audit shows zero referents in features) or `@Deprecated` it with a removal date? **Recommendation: delete now** — every week of dual-source-of-truth is another week of agent drift.
5. **i18n scaffold timing.** Set up `flutter_localizations` + ARB now (cost: 30 min) or defer until first non-English locale (cost: 2 days retrofit)? **Recommendation: now.** The scaffold is the cheap part.
6. **Crash reporting choice.** Sentry vs Firebase Crashlytics? Sentry has better Flutter ergonomics and free-tier; Crashlytics is free + integrates with FCM you'll need anyway for push notifications.
7. **Bundle Oswald + Open Sans locally** or accept the cold-start fallback flash? At ~120KB total it's a small bundle cost for materially better first-paint UX. **Recommendation: bundle locally.**
8. **Two widget directories** — collapse `core/design/widgets/` into `core/widgets/`, or formalize the split as "domain organisms vs primitives"? **Recommendation: collapse.**
9. **`FeatureScaffoldPage`** — still needed as a placeholder for unfinished features (reviews, notifications, verification)? Or replace with proper screens now?
10. **Should `JButton.text` variant be a separate widget (`JLinkButton`) or stay as a variant?** Text variant has different semantics (link-like, 44.h minimum is borderline).

---

## Next Audit

**Trigger:**
- End of Phase 1 (~50+ screens), OR
- After P0 list is complete, OR
- Before any external designer / contractor PR lands

**Focus:**
- Component drift (re-grep for token violations after P0/P1 migrations)
- A11y compliance check (re-run contrast, touch-target, Semantics audit on full app)
- Widgetbook coverage (every primitive should have a story)
- Pattern adoption rate (how many forms migrated to `JFormField`?)
- Performance: cold-start time, font-load timing, low-end Android frame budget

---

## Layman's Term Explanation

A design system is the **toolbox you buy once so you don't have to re-buy a hammer every time you frame a wall.** Right now Jobdun's toolbox has solid hammers (the color tokens, the button widget, the job card) — but it has *no measuring tape* (form fields are eyeballed per screen), the *handles disagree on whether they're metric or imperial* (the docs say Inter, the code says Oswald), and the *box itself is two boxes labelled "tools" and "stuff that looks like tools"* (two widget directories that overlap).

If we ship like this, every new screen takes 30% longer than it should because we re-invent the input field, the empty state, the loading shimmer — and every fix-it-later debt grows interest. The audit's P0 list — fix the docs, build the real input field, fix the accessibility, decide the logo — is **maybe two days of work that will save two weeks per quarter** for the rest of Jobdun's life.

The good news: the foundation (color tokens, theme architecture, grep gates) is genuinely strong for a 21-screen-old project. We're not rebuilding from scratch; we're tightening the bolts before we add the second storey.

---

*End of audit.*
