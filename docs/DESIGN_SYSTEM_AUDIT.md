# Design System Audit Report
> Project: Jobdun (Flutter — Android/iOS) | Audited: 2026-05-10

## Executive Summary

Jobdun has a well-structured, deliberately dark design system with strong token foundations — a full semantic color extension (`JColors`), typed spacing/radius constants, a 13-style Oswald/Open Sans type scale, and excellent design documentation across MASTER + 5 page overrides. The biggest risk is a split between documentation intent and implementation reality: a branded gradient is hardcoded in 13+ files instead of being tokenized, `GoogleFonts.*` is called per-widget in every design component despite the rule against it, and `Colors.white` / raw `SizedBox` leak throughout core widgets. The system scores well on color and documentation, but component consistency and accessibility need targeted work before the app is production-ready.

---

## 1. Typography

### Current state

Two font families configured via Google Fonts base theme in `lib/app/theme/app_theme.dart`:

| Style | Font | Weight | Size | Letter-spacing |
|-------|------|--------|------|----------------|
| `displayLarge` | Oswald | 700 | *(unset)* | 1.2 |
| `displaySmall` | Oswald | 700 | 40sp | 1.0 |
| `headlineLarge` | Oswald | 700 | 32sp | 0.8 |
| `headlineMedium` | Oswald | 600 | 24sp | 0.5 |
| `headlineSmall` | Oswald | 600 | 20sp | 0.3 |
| `titleLarge` | Oswald | 600 | 16sp | 0 |
| `titleMedium` | Open Sans | 600 | 15sp | — |
| `bodyLarge` | Open Sans | 400 | 15sp | — (height 1.6) |
| `bodyMedium` | Open Sans | 400 | 13sp | — |
| `bodySmall` | Open Sans | 500 | 11sp | — |
| `labelLarge` | Oswald | 700 | 14sp | 1.5 |
| `labelMedium` | Open Sans | 600 | 12sp | 0.5 |
| `labelSmall` | Open Sans | 600 | 10sp | 0.8 |

Auth/onboarding page override specifies Inter Black (900) for logo/brand wordmark, but the implementation uses Oswald everywhere including the logo block.

### Issues

- `displayLarge` has no explicit `fontSize` set — inherits platform default, not the 40sp+ specified in MASTER.
- Auth-onboarding override specifies **Inter Black (900)** for logo/wordmark; implementation uses Oswald w700 instead. The third font family (Inter) is never loaded in `AppTheme`.
- `GoogleFonts.oswald()` and `GoogleFonts.openSans()` are called **per-widget** in every design component (`AppButton`, `JobCard`, `TradeCard`, `StatusBadge`, `GvChip`, `AvatarBlock`) — violates the rule to only configure fonts in `AppTheme`, and causes redundant font downloads.
- `bodyLarge` has `height: 1.6` set but `titleMedium` does not — inconsistent line-height handling.
- No `titleSmall` slot used; jumps from `titleMedium` straight to `bodyLarge`, leaving a gap around 13–14sp labeled text.

### Recommendations

1. Add `fontSize: 40` to `displayLarge` in `app_theme.dart`.
2. Load Inter via `GoogleFonts.getTextTheme('Inter', ...)` in `AppTheme` and assign it to logo/brand text styles; add a named constant `AppTextStyles.brandDisplay`.
3. Replace every per-widget `GoogleFonts.oswald(...)` / `GoogleFonts.openSans(...)` call with `Theme.of(context).textTheme.labelLarge` (or the appropriate slot). Where the slot doesn't match, use `.copyWith()` — never raw `GoogleFonts.*`.
4. Add `height: 1.5` to `titleMedium` to unify line-height with `bodyLarge`.

---

## 2. Color System

### Current state

**Token system:** `JColors` ThemeExtension in `lib/app/theme/app_colors.dart`. Accessed via `context.c.*` extension. Dark theme is the default. Light theme (`JColors.light`) is defined.

**Dark theme tokens:**

| Token | Hex | Purpose |
|-------|-----|---------|
| `background` | `#0F172A` | Screen background |
| `surface` | `#1E293B` | Cards, inputs, bottom sheets |
| `card` | `#1E293B` | Alias for surface |
| `surfaceRaised` | `#334155` | Elevated cards, secondary buttons |
| `border` | `#334155` | All borders and dividers |
| `text1` | `#F1F5F9` | Primary text |
| `text2` | `#94A3B8` | Secondary text, labels |
| `text3` | `#64748B` | Hints, placeholders |
| `action` | `#F97316` | CTA, accent (safety orange) |
| `actionBg` | `#431407` | Action container bg |
| `actionTx` | `#FED7AA` | Action container text |
| `verified` | `#22C55E` | Success/verified |
| `verifiedBg` | `#052E16` | Verified container bg |
| `verifiedTx` | `#86EFAC` | Verified container text |
| `urgent` | `#EF4444` | Error/danger |
| `urgentBg` | `#450A0A` | Error container bg |
| `urgentTx` | `#FCA5A5` | Error container text |
| `available` | `#3B82F6` | Available status (blue) |
| `availableBg` | `#1E3A5F` | Available container bg |
| `availableTx` | `#93C5FD` | Available container text |
| `star` | `#F59E0B` | Rating stars (amber) |

**Static fallback:** `AppColors` class with same values — for legacy files not yet using `context.c.*`. `AppDarkColors` is a thin alias.

### Issues

- **Branded gradient is not tokenized.** The five-stop gradient (`#FFF176 → #FFB300 → #F97316 → #E64A19 → #BF360C`) is hardcoded in **13+ files**: `login_page.dart`, `register_page.dart`, `splash_page.dart`, `verify_email_page.dart`, `forgot_password_page.dart`, `onboarding_page.dart` (×5 ShaderMasks), `home_page.dart`, `jobs_page.dart`, `applications_page.dart`. This gradient doesn't appear in MASTER or page overrides — it's an undocumented, untokenized pattern.
- **`Colors.white` used directly** in `app_button.dart` (×2), `gv_chip.dart` (active state), `home_page.dart` (icon), `jobs_page.dart`, `applications_page.dart` (×3). Should be `c.text1` or `Colors.white` wrapped in a named constant at minimum.
- **`const Color(0xFFEF4444)` hardcoded** in `applications_page.dart` for rejected status — should use `c.urgent`.
- **Light theme conflict:** `JColors.light` defines `background: #F8FAFC` (a white background), which MASTER explicitly forbids. It's unclear if light theme is reachable from the app. If unused, it should be removed or blocked.
- **`AppColors` static class still imported** across new feature files. Migration to `context.c.*` is incomplete.

### Recommendations

1. Add `AppGradients.brandFlame` constant in `app_colors.dart`: a `LinearGradient` with the 5-stop gradient. Replace all 13+ hardcoded instances.
2. Replace every `Colors.white` in widgets with `context.c.text1` (dark theme: `#F1F5F9`). The only acceptable `Colors.white` is in `AppButton.primary` where the design explicitly says white text on orange.
3. Replace `const Color(0xFFEF4444)` in `applications_page.dart` with `context.c.urgent`.
4. Remove or gate `JColors.light` — if the app is dark-only, remove the light theme factory to prevent accidental light-mode regression.
5. Migrate remaining `AppColors.*` static usages to `context.c.*` across all feature files.

---

## 3. Shadows & Elevation

### Current state

No shadows anywhere — by design. Card theme sets `elevation: 0`. AppBar theme sets `elevation: 0`. `AppButton` uses `elevation: 0` on `ElevatedButton.styleFrom`. Cards use a `1dp` border (`c.border = #334155`) for edge definition instead of shadow. This matches the MASTER "Aggressive Flat — no shadows" rule exactly.

### Issues

- No elevation token defined (`AppRadius` and `AppSpacing` exist; no `AppElevation`). Elevation of 0 is scattered as a magic literal across theme and button code. If a component ever needs a raised surface (e.g., a tooltip), there is no governance.
- `feature_scaffold_page.dart` uses a `Card` widget — in light mode (if ever enabled) this would inherit Material's default 1dp elevation shadow.

### Recommendations

1. Add `AppElevation.none = 0.0` to `app_colors.dart` (or a new `app_constants.dart`) so zero-elevation is a named contract, not a magic number.
2. Annotate light theme's `CardTheme` with `elevation: 0` explicitly to prevent shadow bleed if light mode is ever activated.

---

## 4. Buttons & Interactive States

### Current state

**Three variants** in `lib/core/widgets/app_button.dart`:

| Variant | Background | Text color | Min height | Radius |
|---------|-----------|------------|------------|--------|
| Primary | `action` (`#F97316`) | White | 52.h | 6.r |
| Secondary | `surfaceRaised` (`#334155`) | `text1` | 52.h | 6.r |
| Text | Transparent | `action` | 44.h | 6.r |

All variants: zero elevation, uppercase label via `.toUpperCase()`, Oswald 14sp w700 letter-spacing 1.5, loading spinner support, optional leading icon (18.r, 8.w gap).

Disabled states: Primary → `action` at 35% alpha bg, white at 50% alpha text. Secondary → `surfaceRaised` at 50% alpha, `text2` text.

No ghost/outline buttons exist — correct per MASTER.

### Issues

- **`GoogleFonts.oswald()` called per-widget** in `app_button.dart` instead of using `Theme.of(context).textTheme.labelLarge`. Same style (14sp w700 ls 1.5 uppercase) is already in the theme — this is redundant and violates the font centralization rule.
- **`Colors.white` hardcoded** for primary button text and loading indicator (×2) — should be a named constant or `Colors.white` at minimum documented as intentional.
- **`SizedBox(width: 18.r, height: 18.r)`** used for loading spinner wrapper instead of a `SizedBox` passed through ScreenUtil or `Gap`.
- **No pressed/splash state** explicitly configured — relies on Material's default ink splash, which may not match the design's 150ms ease spec.
- **Text button** has no documented hover/focus state in either design docs or implementation.

### Recommendations

1. Replace `GoogleFonts.oswald(...)` in `app_button.dart` with `Theme.of(context).textTheme.labelLarge!.copyWith(color: ...)`.
2. Add `splashColor: c.action.withOpacity(0.15)` and `overlayColor: WidgetStateProperty.all(c.action.withOpacity(0.1))` to button style for explicit press feedback.
3. Replace the `SizedBox` loader wrapper with `SizedBox.square(dimension: 18.r)`.

---

## 5. Icons

### Current state

Primary library: **Iconsax** (`iconsax: ^0.0.8`) — used throughout design components (`Iconsax.search_normal`, `Iconsax.eye`, `Iconsax.add`, etc.).

Fallback: `Icons.*` (Material) for cases with no Iconsax equivalent.

Default icon color: `c.text3` (`#64748B`) from `IconTheme` in `AppTheme`.
Active/selected: `c.action` (`#F97316`).
Primary actions: `c.text1` (`#F1F5F9`).

Icon sizes: 20–24dp navigation, 16–20dp inline, 32–40dp feature icons (per MASTER).

`flutter_svg: ^2.0.14` is available for SVG illustrations — no evidence of current usage in scanned files.

### Issues

- **No icon size tokens defined.** Sizes 16, 18, 20, 24, 32, 40 are all used directly as magic literals. No `AppIconSize` constant class exists.
- **`Colors.white`** used as icon color in `home_page.dart` — should be `c.text1`.
- **`flutter_svg` appears unused** in scanned feature files — SVG assets may not be wired up yet.
- MASTER specifies Iconsax but does not document which specific icons map to which actions (search, filter, post, apply, etc.) — no icon vocabulary documented.

### Recommendations

1. Add `AppIconSize` constants: `sm = 16.0, md = 20.0, lg = 24.0, xl = 32.0, feature = 40.0`.
2. Replace `Colors.white` icon color usages with `c.text1`.
3. Add an icon vocabulary section to `design-system/jobdun/MASTER.md` mapping actions to Iconsax names.

---

## 6. Form Inputs

### Current state

Configured globally via `InputDecorationTheme` in `AppTheme` — no per-widget decoration overrides needed.

| Property | Value |
|----------|-------|
| Fill | `c.surface` (`#1E293B`) |
| Border radius | 6.r (`AppRadius.input`) |
| Normal border | `c.border` (`#334155`), 1dp |
| Focused border | `c.action` (`#F97316`), 2dp |
| Error border | `c.urgent` (`#EF4444`), 1.5dp |
| Content padding | 16h horizontal, 16v vertical |
| Hint style | `c.text3` (`#64748B`), 13sp, w400 |
| Label style | Open Sans 11sp w700, ls 0.8, `c.text3` |
| Floating label (focused) | Same but `c.action` |
| Error style | Open Sans 11sp w500, `c.urgentTx` |
| Prefix/suffix icon color | `c.text3` |

`AppTextField` (`lib/core/widgets/app_text_field.dart`) is a thin wrapper — delegates all decoration to `InputDecorationTheme`. No manual theming per-widget.

Password field has show/hide toggle (`Iconsax.eye`) — confirmed in auth screens.

### Issues

- **No disabled input state documented** — InputDecorationTheme has no explicit `disabledBorder` or disabled fill color set.
- **Label placement is "floating"** (Material default) — auth/onboarding override specifies fixed labels above the field (not floating). The implementation uses Flutter's floating label behavior, which contradicts the page override.
- **No `helperText` style defined** in the theme — if hint text is added below a field, it will render with Material defaults.
- **`Pinput` (OTP input)** is installed (`pinput: ^5.0.0`) but no custom theme applied — it will use its own default styles, not the Jobdun token system.

### Recommendations

1. Add `disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border.withOpacity(0.4)))` and `disabledColor: c.surface.withOpacity(0.5)` to `InputDecorationTheme`.
2. Evaluate switching auth fields to `floatingLabelBehavior: FloatingLabelBehavior.never` with labels rendered as `Text` widgets above each `TextField`, per the auth-onboarding override.
3. Create a `PinputTheme` constant in `app_theme.dart` using `c.action` for the focused cursor and `c.border` for inactive borders.

---

## 7. Components & Patterns

### Current state

**Design widgets** (`lib/core/design/widgets/`):
- `GvChip` — filter chip with 150ms animated active state
- `JobCard` — job listing card with urgent indicator, meta row, apply button
- `StatusBadge` — 5 variants (verified, available, urgent, pending, pro) with colored dot
- `AvatarBlock` — initials avatar with configurable size
- `TradeCard` — (found but not fully scanned)

**Core widgets** (`lib/core/widgets/`):
- `AppButton` — primary/secondary/text variants
- `AppTextField` — thin decoration wrapper
- `FeatureScaffoldPage` — page scaffold with header
- `LoadingView` — centered loading indicator
- `ErrorView` — error state with retry

**Component patterns:** All cards use `c.card` background, 1dp `c.border` border, 8.r radius, zero elevation — consistent. Status chips are all-caps, 28.h height, 4.r radius — consistent across `StatusBadge`.

### Issues

- **`GoogleFonts.*` per-widget in every design component** — `JobCard`, `TradeCard`, `StatusBadge`, `GvChip`, `AvatarBlock` all call `GoogleFonts.oswald()` or `GoogleFonts.openSans()` inline. This violates the centralization rule and makes global font changes require edits in 6+ places.
- **`FeatureScaffoldPage`** uses `const SizedBox(height: 10)`, `const SizedBox(height: 20)`, `const EdgeInsets.only(bottom: 10)` — raw hardcoded pixels instead of `Gap` or `AppSpacing`.
- **`LoadingView`** uses `const SizedBox(height: 16)` — should be `Gap(AppSpacing.lg)`.
- **`ErrorView`** uses `const EdgeInsets.all(24)`, `const SizedBox(height: 16)`, `const SizedBox(height: 20)` — raw values.
- **`GvChip` active text** uses `Colors.white` directly — should be `context.c.text1` or `Colors.white` via theme.
- **No `EmptyState` shared component.** Every feature would implement its own Lottie + headline + CTA pattern, causing divergence. No shared component exists yet.
- **No `BottomSheetHeader` component** — `modal_bottom_sheet` is installed but no reusable handle bar + title component is documented or implemented.
- **`onboarding_page.dart` chip group** uses `Colors.white` for selected chip text (should be `c.text1`).

### Recommendations

1. Replace all per-widget `GoogleFonts.*` calls in design components with the appropriate `Theme.of(context).textTheme.*` slot.
2. Replace all `SizedBox(height/width: n)` in `FeatureScaffoldPage`, `LoadingView`, `ErrorView` with `Gap(AppSpacing.*)`.
3. Create `lib/core/design/widgets/empty_state.dart` — shared widget accepting `lottieAsset`, `headline`, `body`, optional `ctaLabel`/`onCta`. Enforce the Lottie + headline + CTA pattern.
4. Create `lib/core/design/widgets/bottom_sheet_header.dart` — handle bar + optional title, using `c.border` for the bar.

---

## 8. Spacing & Grid

### Current state

**Spacing tokens** in `app_colors.dart` (`AppSpacing`):

| Token | Value |
|-------|-------|
| `xs` | 4.0 |
| `sm` | 8.0 |
| `md` | 12.0 |
| `lg` | 16.0 |
| `xl` | 20.0 |
| `xxl` | 32.0 |

Spacing convention: `Gap(n)` from the `gap` package, combined with `flutter_screenutil` (`.w`, `.h`, `.sp`, `.r`). All sizing should use ScreenUtil extensions, never raw pixels.

Grid: No formal grid system — uses Flutter's native column/row layout with padding. No `GridView` or column-count constants defined. `fl_chart` handles dashboard charts. `infinite_scroll_pagination` (`PagedListView`) handles job feeds.

Container max-width: not defined for mobile (full-width). `admin-web.md` override specifies 1400px max-width for web — but this is the Flutter mobile app.

Responsive breakpoints: Not formally defined. App targets Android + iOS only; no tablet-specific breakpoints documented.

### Issues

- **`AppSpacing.md = 12` but MASTER says `md = 16`** — 4dp drift between design doc and code. In MASTER: `xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48`. In code: `xs=4, sm=8, md=12, lg=16, xl=20, xxl=32`. The scale is shifted by one step.
- **Raw `SizedBox` and `EdgeInsets` in 5+ files** (`FeatureScaffoldPage`, `LoadingView`, `ErrorView`, `AppButton`) — inconsistent with the `Gap` convention.
- **No `AppSpacing.xxl` equivalent for 48dp** — the MASTER "2xl = 48" token has no code counterpart.
- **All sizing in design widgets uses `.w`/`.h`/`.r` but some core widgets use raw `const` values** — inconsistent ScreenUtil adoption.

### Recommendations

1. Reconcile `AppSpacing` with MASTER: `md = 16, lg = 24, xl = 32, xxl = 48`. Update all usages (check for breakage — `md` drift from 12 → 16 affects paddings).
2. Add `AppSpacing.xxl2 = 48.0` to match MASTER's `2xl`.
3. Do a project-wide `SizedBox(height` / `SizedBox(width` grep and replace with `Gap(AppSpacing.*)` where applicable.
4. Enforce ScreenUtil extensions in all new code — add a lint note or `// ignore` comment policy for `const SizedBox.shrink()` (acceptable zero-size sentinel).

---

## 9. Missing Tokens / Undocumented Decisions

- **[CRITICAL]** Branded gradient (`#FFF176 → #FFB300 → #F97316 → #E64A19 → #BF360C`) — used in 13+ files, zero documentation, zero tokenization. MASTER forbids gradients, yet this gradient is the most-repeated visual motif in the app. Needs a decision: tokenize it as `AppGradients.brandFlame` OR remove it for MASTER compliance.
- **[CRITICAL]** `GoogleFonts.*` per-widget in 6+ design components — undocumented exception to the AppTheme-only font rule. Every component is a font-loading liability.
- **[MODERATE]** `Colors.white` vs `c.text1` — used interchangeably in 10+ places. No documented rule on when to use literal `Colors.white` vs the token (`#F1F5F9`). The two values are visually similar but semantically different (one is theme-aware, one is not).
- **[MODERATE]** `AppSpacing` scale mismatches MASTER by one step — four tokens have different values than the spec. No changelog or decision record explaining the delta.
- **[MODERATE]** Inter (font) — listed in auth/onboarding page override as the logo font (Inter Black 900), but never loaded in `AppTheme`. It is silently missing from the font stack.
- **[MODERATE]** Light theme (`JColors.light`) exists in code but MASTER says dark-only. Its existence creates ambiguity — is it intentional future-proofing or a leak?
- **[MODERATE]** No `EmptyState` shared widget — every feature builds its own. High risk of pattern drift.
- **[MODERATE]** `Pinput` OTP widget has no custom theme — will render with Pinput defaults, not Jobdun tokens.
- **[LOW]** `displayLarge` has no `fontSize` — relies on platform default.
- **[LOW]** No `AppIconSize` constants — icon sizes (16, 18, 20, 24, 32, 40) are magic literals.
- **[LOW]** No `AppElevation` constant — `elevation: 0` is a magic literal in 4+ places.
- **[LOW]** No pressed-state gradient or color defined for CTA button (`#EA6C0A` is in MASTER but not in `JColors` or `AppColors`). The pressed state defaults to Material ink splash.
- **[LOW]** `titleSmall` text style is unused — gap in the type scale between `titleMedium` (15sp) and `bodyMedium` (13sp).

---

## 10. Priority Action Plan

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| 1 | Extract branded gradient into `AppGradients.brandFlame` constant; replace all 13+ hardcoded instances | Medium | High — eliminates the most widespread undocumented pattern |
| 2 | Replace per-widget `GoogleFonts.*` calls in all design components and `AppButton` with `Theme.of(context).textTheme.*` slots | Medium | High — enforces centralization, fixes font-loading overhead |
| 3 | Reconcile `AppSpacing` scale with MASTER (md=16, lg=24, xl=32, xxl=48); replace all raw `SizedBox`/`EdgeInsets` in core widgets with `Gap(AppSpacing.*)` | Medium | High — eliminates spacing inconsistency across the board |
| 4 | Replace `Colors.white` with `c.text1` in all widgets except where explicitly white-on-orange (document the exceptions) | Low | Medium — improves theme-awareness and future light/dark safety |
| 5 | Replace hardcoded `const Color(0xFFEF4444)` in `applications_page.dart` with `c.urgent`; audit all feature pages for other hardcoded color literals | Low | Medium — closes semantic color gaps |
| 6 | Create shared `EmptyState` widget and `BottomSheetHeader` widget; enforce as the pattern for all features | Medium | Medium — prevents pattern divergence as new screens are built |
| 7 | Apply a `PinputTheme` in `AppTheme` using Jobdun tokens; add `disabledBorder` to `InputDecorationTheme` | Low | Low-Medium — closes input state gaps before auth polish |

---

## Design System Maturity Score

- **Token coverage:** 4/5 — Colors, spacing, radius all tokenized. Gradient, icon sizes, elevation, and CTA pressed-state are missing tokens.
- **Component consistency:** 3/5 — Correct component set exists and core patterns are right. Broken by GoogleFonts per-widget, `Colors.white` leakage, and raw spacing in core utilities.
- **Documentation:** 5/5 — MASTER.md + 5 page overrides is exceptional. Anti-patterns listed, component specs detailed, copy guidelines included.
- **Accessibility:** 2/5 — No documented contrast ratios, no semantic label coverage, no focus-order docs, no screen reader testing evidence. The dark palette likely passes WCAG AA for primary text but this is unverified.
- **Dark mode readiness:** 4/5 — Full `JColors.dark` implementation, correctly wired as app default. Loses one point because `JColors.light` (WCAG-conflicting) exists and `Colors.white` is scattered throughout.

**Overall: 18/25**
