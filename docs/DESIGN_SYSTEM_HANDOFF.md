# Design System — Work Handoff

**Date:** 2026-05-31 · **Branch:** `feat/verified-builder-details-step6` · **Scope:** accessibility + token + icon-size pass on the design system, driven by the design-study audit.

A running record of what shipped, what's still open, and how to verify. Pairs with the audit set: [`DESIGN_SYSTEM_AUDIT.md`](./DESIGN_SYSTEM_AUDIT.md) · [`DESIGN_SYSTEM_SUGGESTIONS.md`](./DESIGN_SYSTEM_SUGGESTIONS.md) · [`DESIGN_SYSTEM_TOKENS.md`](./DESIGN_SYSTEM_TOKENS.md) · [`DESIGN_SYSTEM_COLOR_SYSTEM.md`](./DESIGN_SYSTEM_COLOR_SYSTEM.md) · [`DESIGN_SYSTEM_RULES.md`](./DESIGN_SYSTEM_RULES.md).

---

## ✅ Done (shipped to live code)

### Color tokens — `lib/app/theme/app_colors.dart` + `app_theme.dart`
- **`onAction` white → `#0F172A`** (CTA text/icons 2.80:1 → **6.37:1**). *Option A — reverses the prior "white-on-orange" lock in `archive/DESIGN_SYSTEM_FOUNDATION_AUDIT.md §11.2`.*
- **`text3` `#64748B` → `#8B98AB`** (dark) / `#64748B` (light) — 3.07 → **5.0:1**.
- **New `borderStrong` token `#708096`** (3.63:1), wired into the input `enabledBorder`/`border`. Cards keep the subtle `border` (#334155).
- **Type floor**: `labelSmall` 10→11sp, `bodySmall` 11→12sp, `bodyMedium` line-height → 1.45.
- **13 golden PNGs regenerated** to match (j_button primary*, bottom_action_bar, j_card, j_chip, page_header*, j_switch_off).

### Typography (home)
- **Home stat numbers** (`_StatCard`, the Applied/Shortlisted/Jobs-done values) — removed the off-scale `fontSize: 28.sp` override → `headlineMedium` (24sp, on-scale).
- Verified home typography is otherwise clean: **no detached `TextStyle(`, no per-widget `GoogleFonts`** — all via `Theme.of(context).textTheme.*`.

### Widget-level a11y
- **3 white-on-orange icon tiles → dark** (`c.background`, 6.37:1): home `_PrimaryActionCard`, `ProfileCompletenessBanner`, home map-toggle FAB. *(Map markers left — convention.)*
- **`FtueHeroPhoto`** entrance now honors **reduced motion** (`MediaQuery.disableAnimations`).

### Icon-size system
- **New `AppIconSize` token** — `lib/app/theme/app_icon_size.dart`, exported via the `core/design/colors.dart` barrel: `micro 14 / inline 16 / md 20 / nav 24 / feature 32 / hero 40` (mapped to MASTER §210 use-cases).
- **Home feature migrated** (~14 icon sites) from raw `size: N.r` to `AppIconSize.*.r`. Only the raw map-marker glyph (`home_map_view.dart:280`) left by design.

### Notifications
- **Header bell fixed**: tap target 34×34 → **44×44**, `HitTestBehavior.opaque`, glyph → `nav` (24), `Semantics`+`Tooltip`, and `onTap` now opens `/notifications` (was a no-op `() {}`).
- **`/notifications` page** upgraded from a generic bullet stub to a **design-system placeholder/zero-state** (dark, hero glyph, declarative copy).

### Debug-only preview scaffolding (kDebugMode, never in release)
- `PreviewTheme` (fixed-dark + fixed-light) — `lib/app/theme/preview_theme.dart`.
- **`/home-preview`** — the real `HomePage` in `fixedPreview` mode with a sun/moon dark/light toggle + clamped text scaling.
- **`/design-preview`** — `DesignPreviewPage` showcase (CTA before/after, eyebrow/text3, input border, card, status, **ICON SIZE SCALE**, **VISUAL HIERARCHY**, body).
- Home debug buttons: **HOME · FIXED** + **TOKENS**.

### Docs created (`docs/`)
`DESIGN_SYSTEM_AUDIT.md`, `_SUGGESTIONS.md`, `_TOKENS.md`, `_COLOR_SYSTEM.md`, `_RULES.md`, and this handoff.

---

## ⬜ Left to do (prioritized)

### P1 — finish what's only half-shipped
- [ ] **Dynamic Type clamp is preview-only.** `MediaQuery.withClampedTextScaling(0.9–1.3)` exists in the preview pages but **NOT** in the live app roots. Add it in `lib/app/app.dart` and `lib/admin/app/admin_app.dart`, then test fixed-height controls at max OS font size.
- [ ] **App-wide icon-size migration.** Only the home feature uses `AppIconSize`. Migrate the rest — `jobs`, `profile`, `auth`, `applications`, `messaging`, `verification` + shared widgets (`JButton`/`JCard`/`JTextField`/`StatusBadge` icon params). **Will touch golden-tested widgets → regenerate `j_button`/`j_card` goldens.**
- [ ] **`MASTER.md` spec sync.** Still says foreground = white, has **no accessibility section**, and the §70-vs-§117 button letter-spacing conflict is unresolved. Update the colour table (onAction dark, add `borderStrong`), document `AppIconSize`, add the a11y section (`SUGGESTIONS.md S4`).

### P2 — remaining audit items not yet fixed
- [ ] **`text2` on `surfaceRaised` = 4.04:1** — body copy on raised/selected surfaces dips below AA. Lift `text2` or forbid body on raised.
- [ ] **White-on-red error fills = 3.76:1** — use the tinted `urgentTx`-on-`urgentBg` pair for error text instead of white-on-solid-red (`app_theme.dart` `onError`).
- [ ] **App-wide reduced-motion** — only `FtueHeroPhoto` + `JStaggeredList` honor it; sweep any other `AnimationController`/`flutter_animate` entrances.
- [ ] **Semantics coverage** — ~16 feature sites today; expand to icon-only buttons, list rows, gallery images.
- [ ] **Stat-number typography consistency** — `JStatBadge` (profile dashboard) still renders stat values at **22sp** (off-scale), now inconsistent with home's on-scale 24sp. Unify to one scale step (touches a shared widget → may regen the `j_card` golden).
- [ ] **Centralise hand-tuned `letterSpacing`** — magic numbers (`0.02 * 11`, `0.12 * 11`, scattered `0.5`/`0.6`) across home/map widgets; fold into the theme's per-style `letterSpacing` or `FieldLabel`. Cosmetic.

### P3 — cleanup / decisions
- [ ] **Remove redundant preview scaffolding.** Now that the fixes are live, `HOME · FIXED` ≈ live. Candidate for deletion: `PreviewTheme`, `/home-preview` (`HomePage.fixedPreview`), `/design-preview` (`DesignPreviewPage`), the two home debug buttons, the routes. (Or keep as a living token showcase — decide.)
- [ ] **Refresh the 5 design-system docs** — they describe the fixes as "proposed/current-failing"; they're now shipped/historical. Update or mark as the original audit record.
- [ ] **Gated light theme** (`JColors.light`) — wire-and-verify its contrast or delete it (still untested in production; app is dark-only).
- [ ] **Compact `JButton` visible 40/36dp** — tap area is already 48 (padded); visible bump to 44 is optional polish (churns the `j_button` compact golden).

### Not ours (pre-existing — don't attribute to this work)
- `validate.sh` is red from **admin** `GoogleFonts.*`/`Colors.white`/format debt (see memory `project_verification_remediation`).
- 3 analyzer **infos** in untouched files (e.g. `job_remote_datasource.dart`).
- `login_page.dart` pre-existing format drift.

---

## Key files

| File | What changed |
|------|--------------|
| `lib/app/theme/app_colors.dart` | `onAction`/`text3` fixed; new `borderStrong`; +`AppIconSize` export |
| `lib/app/theme/app_theme.dart` | input border → `borderStrong`; type-floor + line-height |
| `lib/app/theme/app_icon_size.dart` | **new** — icon size scale |
| `lib/app/theme/preview_theme.dart` | **new** — debug fixed-dark/light theme |
| `lib/core/design/colors.dart` | export `AppIconSize` |
| `lib/features/home/presentation/pages/home_page.dart` | `fixedPreview` mode, toggle, debug buttons, FAB icon |
| `lib/features/home/presentation/pages/home_widgets.dart` | icon-size migration; bell 44×44 + wired |
| `lib/features/home/presentation/pages/home_map_widgets.dart` | icon-size migration |
| `lib/features/home/presentation/pages/home_shell_page.dart` | wifi icon → `micro` |
| `lib/features/home/presentation/pages/design_preview_page.dart` | **new** — showcase |
| `lib/features/home/presentation/widgets/profile_completeness_banner.dart` | icon dark-on-orange + size migration |
| `lib/features/ftue/presentation/widgets/ftue_hero_photo.dart` | reduced-motion guard |
| `lib/features/notifications/presentation/pages/notifications_page.dart` | rewritten as DS placeholder |
| `lib/app/router/app_router.dart` | `/home-preview` + `/design-preview` debug routes |

## Verification status (as of this handoff)
- `flutter analyze` — **clean on all touched files** (3 pre-existing infos elsewhere).
- `flutter test` — **all 158 pass**, including regenerated goldens.
- `dart format` — clean on all session files (pre-existing `login_page.dart` drift untouched).
- **Not run:** device/emulator visual pass, screen-reader pass, Dynamic Type at max scale.

## How to see it
Run the app (`flutter run`) → **Home**:
- The orange icon tiles + map FAB now have **dark** glyphs; the **notification bell** is a real 44×44 button that opens the placeholder page.
- **HOME · FIXED** (debug button) — the home page under the corrected theme, with a sun/moon light/dark toggle.
- **TOKENS** (debug button) — the showcase: CTA before/after, icon-size scale, visual hierarchy, etc.
