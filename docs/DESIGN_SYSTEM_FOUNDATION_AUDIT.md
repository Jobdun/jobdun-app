# Design System Foundation Audit — Jobdun (Flutter)

**Date:** 2026-05-20
**Branch:** `feat/ui-updates`
**Author:** Claude (Opus 4.7) — grounding pass before Sprint A execution
**Purpose:** Reconcile the proposed Sprint A/B/C unification plan against actual code state. The plan was written from `UI_UX_INCONSISTENCY_AUDIT.md` alone (a screens-vs-theme audit) — this doc audits **MASTER-vs-theme** and **theme-vs-primitives** to catch unverified claims before they hit the codebase.

**Companion:** [`UI_UX_INCONSISTENCY_AUDIT.md`](./UI_UX_INCONSISTENCY_AUDIT.md) — screens-vs-theme. This doc operates one layer down.

---

## 0. Executive Summary

The Sprint A/B/C plan is **directionally correct** but contains **8 plan-vs-code mismatches** that would either:
- Duplicate primitives that already exist (`GvChip`, `StatusBadge`, `AppSpacing`, `AppRadius`)
- Introduce token values that violate MASTER (`kRadiusMd=12`, `kRadiusLg=16`)
- Reference symbols that don't exist (`AppColors` — actual class is `JColors`)
- Collapse a hierarchy the theme already supports (single-size `PageHeader` vs theme's 4 heading sizes)

Net effect on Sprint A: **3 of 9 tasks execute as written. 6 tasks need amendment.** No task is fundamentally wrong — just imprecise.

Sprint B and C inherit fewer issues but the CI script in C1 is unworkable without a barrel file.

---

## 1. Naming Inventory — what the symbols are actually called

| Plan name | Real name | Location | Status |
|-----------|-----------|----------|--------|
| `AppColors` (referenced ~10x in plan) | `JColors` | `lib/app/theme/app_colors.dart:7` | Rename in v2 prompt |
| `Theme.of(context).extension<AppColors>()` | `context.c` extension (defined on BuildContext) | `app_colors.dart:198-200` | Plan's access pattern works, just wrong type name |
| `AppButton` | `AppButton` | `lib/core/widgets/app_button.dart` | Correct in plan |
| `JButton` (rename target) | — | does not yet exist | Correct in plan |
| `kSpace2/4/8/12/16/24/32` | `AppSpacing.xs/sm/md/lg/xl/xxl` (4/8/16/24/32/48) | `app_colors.dart:202-209` | **Plan introduces parallel scheme — use existing** |
| `kRadiusSm/Md/Lg/Xl` (8/12/16/24) | `AppRadius.badge/chip/btn/card/input/avatar` (4/6/6/8/6/8) | `app_colors.dart:211-218` | **Existing uses semantic names + sharper values. Plan's 16/24 violate MASTER §238** |
| `FieldLabel` | `FieldLabel` | `lib/core/design/widgets/field_label.dart` | Correct |
| `JTextField` | `JTextField` | `lib/core/widgets/inputs/j_text_field.dart` | Correct |
| `JCard` (new) | — | does not yet exist | Correct in plan |
| `JChip` (new) | — | but `GvChip` + `StatusBadge` both exist (see §3) | Plan double-builds; needs amendment |
| `JSwitch` (new) | — | does not yet exist | Correct in plan |
| `PageHeader` (new) | — | does not yet exist | Correct in plan, but see §4 |
| `BottomActionBar` (new) | — | does not yet exist | Correct in plan |

---

## 2. Existing primitive inventory — `lib/core/`

```
lib/core/design/widgets/
├── adaptive_icon.dart
├── avatar_block.dart
├── bottom_sheet_header.dart        ← exists, could feed PageHeader
├── empty_state.dart
├── field_label.dart                ← keep, integrate into PageHeader
├── gv_chip.dart                    ← FILTER chip (toggleable, solid orange when active)
├── job_card.dart                   ← feature card (job listing)
├── jobdun_logo.dart                ← brand wordmark widget
├── status_badge.dart               ← TRANSLUCENT semantic badge (verified/available/urgent/pending/pro)
└── tradie_card.dart                ← feature card (tradie profile)

lib/core/widgets/
├── app_button.dart                 ← RENAME → lib/core/design/widgets/j_button.dart
├── error_view.dart
├── feature_scaffold_page.dart
├── inputs/
│   └── j_text_field.dart           ← already correctly placed/named
├── loading_view.dart
├── social_auth_button.dart
└── status_banner.dart
```

**Key insight:** The plan's "build `JChip`" task overlaps with **two** existing primitives:

- **`GvChip`** (filter pill, toggleable, `c.action` when active) — `gv_chip.dart`
- **`StatusBadge`** (translucent dot-prefixed badge with semantic variants: verified, available, urgent, pending, pro) — `status_badge.dart`

What's missing is the **solid identity chip** (e.g. the always-orange role chip on `profile_page.dart:206-223`, the URGENT badge on `job_detail_page.dart:121-137`). Build *that* as `JChip(variant: solid)` and migrate the inline copies. Leave `GvChip` and `StatusBadge` alone — they own clear, distinct jobs.

---

## 3. Token reality vs plan claims

### 3a. Radii — plan violates MASTER

| Source | Values |
|--------|--------|
| **MASTER §238 (anti-pattern)** | "Soft/rounded border radius above 12 — keep it sharp (4–8)" |
| MASTER §111 button | `6.r` |
| MASTER §147 card | `8.r` |
| MASTER §165 input | `6.r` |
| MASTER §189 chip | `4.r` |
| **Plan A8** | `kRadiusSm=8, kRadiusMd=12, kRadiusLg=16, kRadiusXl=24` |
| **Existing `AppRadius`** | `badge=4, chip=6, btn=6, card=8, input=6, avatar=8` |

**Verdict:** Existing `AppRadius` matches MASTER exactly. Plan's `kRadiusLg=16, kRadiusXl=24` directly violate MASTER §238. **Keep `AppRadius` as-is.** Plan itself said *"or whatever MASTER says — verify first"* — verified.

### 3b. Spacing — existing matches MASTER; plan introduces extras

| Source | Values |
|--------|--------|
| **MASTER §85-94** | xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48 |
| **Plan A8** | kSpace2=2, kSpace4=4, kSpace8=8, kSpace12=12, kSpace16=16, kSpace24=24, kSpace32=32 |
| **Existing `AppSpacing`** | xs=4, sm=8, md=16, lg=24, xl=32, xxl=48 |

**Verdict:** Existing matches MASTER 1:1. Plan introduces `kSpace2=2` and `kSpace12=12` not in MASTER. **Keep `AppSpacing`.** If a 2dp or 12dp gap is ever genuinely needed, add `AppSpacing.xxs=2` and `AppSpacing.smd=12` — don't fork to a parallel `kSpace*` scheme.

### 3c. Motion — plan's 250ms violates MASTER

| Source | Values |
|--------|--------|
| **MASTER §216** | "Transitions: 150–200ms ease. No longer." |
| **Plan A8** | `kDurationFast=150ms, kDurationMd=250ms, kCurveStandard=Curves.easeOutCubic` |
| **Existing** | none — no motion tokens yet |

**Verdict:** `kDurationMd=250ms` violates MASTER §216. **Build `AppMotion.fast=150ms, AppMotion.medium=200ms`** instead. Two values, not three. Curve `Curves.easeOut` matches MASTER's "ease" — `easeOutCubic` is fine but document the choice.

### 3d. Text theme — `PageHeader` is reinventing what `headlineMedium` already is

Theme already defines (from `app_theme.dart:90-166`):

| Token | Size | Weight | LS | MASTER mapping | Use for |
|-------|------|--------|-----|----------------|---------|
| `displayLarge` | 40 | w700 | 1.2 | §64 Display | brand wordmark, splash |
| `headlineLarge` | 32 | w700 | 0.8 | §65 H1 | screen titles (sub-pages) |
| `headlineMedium` | 24 | w600 | 0.5 | §66 H2 | section headers / **tab landing titles** |
| `headlineSmall` | 20 | w600 | 0.3 | §67 H3 | sub-section headers |
| `titleLarge` | 16 | w600 | 0 | §68 Title | card headers |
| `labelLarge` | 14 | w700 | 1.5 | §70 Button | button text |
| `labelMedium` | 12 | w600 | 0.5 | §71 Label | tags, badges, chips |
| `labelSmall` | 10 | w600 | 0.8 | (smaller variant) | eyebrows (FieldLabel uses this) |

**Verdict:** The audit's `pageHero / pageTitle / screenTitle` hierarchy is **already expressible** via `headlineLarge / headlineMedium / headlineSmall`. No new constants needed. `PageHeader` should be a **layout widget** that takes a size enum and consumes the existing theme tokens. The bug is screens calling `tt.headlineSmall!.copyWith(fontSize: 28.sp)` instead of just using `headlineMedium`.

### 3e. Button height — plan correct, theme is wrong

| Source | Value |
|--------|-------|
| **MASTER §110** | `Size(double.infinity, 56.h)` |
| `AppButton.minimumSize` | `Size.fromHeight(52.h)` ← off by 4 |
| Inline bottom-bar CTAs (`profile_edit`, `job_create`, `job_detail`) | 48h |

**Verdict:** Plan A2 (bump `AppButton` to 56h) is correct.

### 3f. Button letterSpacing — MASTER conflicts with itself

| Source | LS |
|--------|-----|
| MASTER §70 (typography table) | 1.5 |
| MASTER §117 (button code sample) | 1.0 |
| Theme `labelLarge` | 1.5 |

**Verdict:** MASTER has internal inconsistency. Theme uses 1.5 (matches the table). **Pick 1.5.** Update MASTER §117 in the Sprint C documentation pass.

### 3g. Brand display constant

`AppTheme.brandDisplay(Color color)` at `app_theme.dart:14-21` already exists for the JOBDUN wordmark (40sp Oswald w700 ls 3.0). Plan's "reserve ShaderMask for /login and /register JOBDUN wordmark only" works with this — those two pages override fontSize to 56sp via `.copyWith(fontSize: 56.sp)`. Keep the helper, document the override.

---

## 4. Plan claim-by-claim status

| Plan task | Status | Amendment if needed |
|-----------|--------|---------------------|
| **A1** — Flip `onAction` to white + doc comments | ✅ Execute as written | The lines are accurate: `app_colors.dart:75` (dark) and `:102` (light). Both currently `Color(0xFF1A0A03)`. |
| **A2** — Rename `AppButton` → `JButton`, height 56h, remove `.toUpperCase()`, doc comment | ✅ Execute as written | `AppButton.minimumSize` is at lines `:57` (primary) and `:73` (secondary). The `label.toUpperCase()` call is at `:45`. Note: variant enum becomes `JButtonVariant`. |
| **A3** — Build `PageHeader` | ⚠ Amend | Use `theme.textTheme.headlineMedium` (24sp w600 ls 0.5) — **don't hand-tune a new 24sp Oswald style**. Add an optional `size: PageHeaderSize.hero/tab/sub` param mapping to `headlineLarge/Medium/Small` so /home keeps its larger hero. Eyebrow uses `FieldLabel`. Document the ShaderMask-reserved-for-auth rule. |
| **A4** — Build `BottomActionBar` | ✅ Execute as written | No existing primitive. SafeArea-aware, surface-tinted, with shadow per existing pattern in `profile_edit_page.dart:362-392`. |
| **A5** — Promote `_InfoCard` → `JCard` (+ `JStatBadge`) | ✅ Execute as written | `job_card.dart` and `tradie_card.dart` are feature-specific cards — distinct from a generic chrome `JCard`. No conflict. |
| **A6** — Build `JChip` | ⚠ Amend significantly | `GvChip` (filter) and `StatusBadge` (translucent semantic) already cover two of three chip patterns. The **missing** primitive is the **solid identity chip** (role chip on profile_page, URGENT badge on job_detail_page). Build `JChip` for that one use case (solid bg, white fg, configurable bg color defaulting to `c.action`). Don't try to unify all three under one widget in Sprint A — that's a refactor for later. |
| **A7** — Build `JSwitch` | ✅ Execute as written | No existing primitive. Pattern: `activeThumbColor: Colors.white, activeTrackColor: c.action` (the brighter `job_create_page` style per audit §10). |
| **A8** — Token files | ⚠ Amend | (a) **Extract** `AppSpacing` and `AppRadius` from `app_colors.dart` into `lib/app/theme/app_spacing.dart` and `lib/app/theme/app_radii.dart` (per your "extract" preference). (b) Keep the **existing semantic names and values** — they match MASTER. (c) Add **new** `lib/app/theme/app_motion.dart` with `AppMotion.fast=150ms, AppMotion.medium=200ms, AppMotion.standard=Curves.easeOutCubic`. (d) Do NOT introduce `kSpace*` or `kRadius*` parallel schemes. |
| **A9** — Golden tests | ✅ Execute as written | `golden_toolkit` is NOT in `pubspec.yaml`. Plan said "no extra deps" — Flutter's built-in `matchesGoldenFile` works. Confirmed. |

---

## 5. CI rule C1 — barrel file plan (you already chose this)

Plan rule as written: `grep -rn "import.*app_colors.dart" lib/features/ → fail`.

This is unworkable because `extension JColorsX on BuildContext { JColors get c => JColors.of(this); }` is defined in `app_colors.dart` (lines 198-200). Every feature file using `context.c.action` (~all of them) imports `app_colors.dart` solely for the extension.

**Your decision (confirmed in chat):** move the extension to a barrel file.

**Concrete migration:**

1. Create `lib/core/design/colors.dart`:
   ```dart
   export 'package:jobdun/app/theme/app_colors.dart' show JColors, JColorsX;
   ```
   *(Or use a relative path if the project's import style is relative — check existing imports first.)*

2. After Sprint A's token extraction (Task A8), also re-export `AppSpacing`, `AppRadius`, `AppMotion`:
   ```dart
   export 'package:jobdun/app/theme/app_colors.dart' show JColors, JColorsX;
   export 'package:jobdun/app/theme/app_spacing.dart' show AppSpacing;
   export 'package:jobdun/app/theme/app_radii.dart' show AppRadius;
   export 'package:jobdun/app/theme/app_motion.dart' show AppMotion;
   ```

3. Find-replace in features: `import '...app/theme/app_colors.dart'` → `import '...core/design/colors.dart'`. ~30 files affected (grep count below).

4. CI rule becomes:
   ```bash
   grep -rn "import.*'.*app/theme/app_colors\.dart'" lib/features/ --include="*.dart" \
     && fail "Import design tokens via core/design/colors.dart, not app/theme/app_colors.dart"
   ```

**Migration scope (preview):** running `grep -rln "app_colors.dart" lib/features/` will give the file count.

---

## 6. Hero/tab/sub size decision (still open)

| Option | Implication |
|--------|-------------|
| **A. One PageHeader size (24sp `headlineMedium`)** | Plan as written. Home `/home` drops from 40sp → 24sp. Strict consistency. |
| **B. PageHeader with `size: hero/tab/sub` enum** | Uses existing `headlineLarge` (32sp) for hero on `/home`, `headlineMedium` (24sp) for tab landings, `headlineSmall` (20sp) for pushed sub-pages. Matches audit §6 recommendation. Three sizes that already exist. **Recommended.** |

**Recommendation: B.** The theme already supports three sizes — no new constants, no new code. The audit explicitly recommended this hierarchy. Plan's single-size collapse is over-correction.

---

## 7. Plan completeness gaps the audit didn't catch

1. **`AppTheme.brandDisplay(Color)` exists** and is the canonical brand wordmark style (40sp Oswald w700 ls 3.0). Sprint A/B should mention it — don't accidentally re-implement.
2. **`AppTheme.pinputTheme(c)` / `pinputFocusedTheme(c)` exist** for the OTP/PIN field. Out of scope for this sprint but worth knowing — don't introduce alternates.
3. **`ColorScheme` is fully wired in `app_theme.dart:58-84`** including `onPrimary: c.onAction`. After A1's flip, every Material widget that uses `colorScheme.onPrimary` will pick up the new white correctly. Verify no widget currently depends on the dark `onAction` value.
4. **`elevatedButtonTheme` overlay** uses `c.action.withValues(alpha: 0.15)` for pressed states (`app_theme.dart:185-196`). After `JButton` renames to a `FilledButton`, verify the overlay still applies (FilledButton has its own `filledButtonTheme` — may need a parallel override).

---

## 8. Recommended Sprint A — corrected work order

This replaces the original Sprint A. Bold = changed from v1.

### Day 1 — Tokens + core primitives

**A1** — Flip `onAction` to `Color(0xFFFFFFFF)` at `app_colors.dart:75` (dark) and `:102` (light). Add MUST/MUST NOT doc comments on `onAction`, `action`, `actionBg`, `actionPressed`, `available`, `surface`, `surfaceRaised`, `text1`, `text2`, `text3`, `border`, `verified`, `urgent`. **Note:** the class is `JColors`, not `AppColors`.

**A2** — Move `lib/core/widgets/app_button.dart` → `lib/core/design/widgets/j_button.dart`. Rename `AppButton` → `JButton`, `AppButtonVariant` → `JButtonVariant`. Update `minimumSize: Size.fromHeight(52.h)` → `Size.fromHeight(56.h)` (both primary at `:57` and secondary at `:73`). Remove `label.toUpperCase()` at `:45`. Add doc comment. Find-replace `AppButton` → `JButton` across the codebase. **Verify `filledButtonTheme` overlay still applies** after rename.

**A3** — Build `lib/core/design/widgets/page_header.dart`.
```dart
enum PageHeaderSize { hero, tab, sub }
// hero → theme.textTheme.headlineLarge (32sp) — /home only
// tab  → theme.textTheme.headlineMedium (24sp) — tab landings (default)
// sub  → theme.textTheme.headlineSmall (20sp) — pushed sub-pages
```
Signature: `PageHeader({required String eyebrow, required String title, PageHeaderSize size = PageHeaderSize.tab, Widget? trailing})`. Eyebrow uses `FieldLabel`. **Never use ShaderMask** — reserved for `/login` + `/register` JOBDUN wordmark via `AppTheme.brandDisplay`.

**A4** — Build `lib/core/design/widgets/bottom_action_bar.dart`. Signature: `BottomActionBar({required JButton primary, JButton? secondary})`. SafeArea-aware. Pattern source: `profile_edit_page.dart:362-392`.

### Day 2 — Remaining primitives + tokens

**A5** — Promote `_InfoCard` and `_StatBadge` from `profile_page.dart` to `lib/core/design/widgets/j_card.dart`. Class names: `JCard`, `JStatBadge`. Delete the privates from `profile_page.dart` and update its references.

**A6** — Build `lib/core/design/widgets/j_chip.dart` for the **solid identity chip** only (role chip, URGENT badge, trade-type chip). Signature: `JChip({required String label, Color? backgroundColor, Color? foregroundColor})`. Defaults: `c.action` bg, white fg. Document: `GvChip` is for filter pills, `StatusBadge` is for semantic status, `JChip` is for identity/critical. Migrate inline solid chips in `profile_page.dart:206-223` and `job_detail_page.dart:121-137`.

**A7** — Build `lib/core/design/widgets/j_switch.dart`. One canonical treatment: `activeThumbColor: Colors.white, activeTrackColor: c.action` (matches `job_create_page` per audit §10).

**A8** — Token extraction:
- Move `AppSpacing` from `app_colors.dart:202-209` → `lib/app/theme/app_spacing.dart`. **Keep existing values: xs=4, sm=8, md=16, lg=24, xl=32, xxl=48.**
- Move `AppRadius` from `app_colors.dart:211-218` → `lib/app/theme/app_radii.dart`. **Keep existing semantic names and values: badge=4, chip=6, btn=6, card=8, input=6, avatar=8.**
- Create new `lib/app/theme/app_motion.dart`:
  ```dart
  abstract final class AppMotion {
    static const fast = Duration(milliseconds: 150);
    static const medium = Duration(milliseconds: 200);
    static const standard = Curves.easeOutCubic;
  }
  ```
- Update all imports across `lib/`. Verify `app_button.dart` and `app_theme.dart` still find `AppRadius.btn` / `AppRadius.input` / `AppRadius.card`.

**A8b (new)** — Create the colors barrel: `lib/core/design/colors.dart` re-exporting `JColors`, `JColorsX`, `AppSpacing`, `AppRadius`, `AppMotion`. Don't migrate feature files yet (that's a Sprint B sub-task).

### Day 3 — Golden tests

**A9** — Golden tests using Flutter's built-in `matchesGoldenFile` (no `golden_toolkit` dep needed). Files:
- `test/golden/j_button_test.dart` — variant × state matrix (~9 goldens)
- `test/golden/j_text_field_test.dart`
- `test/golden/j_card_test.dart`
- `test/golden/j_chip_test.dart`
- `test/golden/j_switch_test.dart`
- `test/golden/page_header_test.dart` — three sizes
- `test/golden/bottom_action_bar_test.dart`

**STOP at end of Sprint A.** Show:
1. Per-file diff summary
2. `flutter analyze` (zero issues)
3. `flutter test` (all goldens + existing tests pass)
4. List of judgment calls made beyond this plan

---

## 9. Sprint B amendments (preview)

Mostly mechanical. Key adjustments from v1:

- **B1** (BottomActionBar migration) — verbatim.
- **B2** (FieldLabel/PageHeader migration) — `PageHeader.size: hero` on `/home`, `tab` on jobs/applications/messages/verification, `sub` on job_create/profile_edit.
- **B3** (Strip ShaderMask) — verbatim. Keep on auth wordmarks.
- **B4** (JTextField migration) — verbatim. `JTextField` already exists and works.
- **B5** (JSwitch migration) — verbatim.
- **B6** (decorative `c.action` → `c.text2/3`) — verbatim.
- **B7** (link pattern) — verbatim. Reuse `login_page.dart:307-310` muted-link treatment.
- **B8** (uppercase strings) — verbatim. After A2 removes `.toUpperCase()`, this becomes a correctness requirement, not just style.
- **B-new** — Migrate feature files from `app/theme/app_colors.dart` import → `core/design/colors.dart` import (the barrel). One find-replace pass.

---

## 10. Sprint C amendments (preview)

- **C1** — CI script in plan is fine after barrel. Update the rule: `grep -rn "import.*'.*app/theme/app_colors\.dart'" lib/features/`. Other rules (no raw `TextField`, no `ShaderMask` outside auth, no inline `letterSpacing: 0.12`, no `0xFFF97316` literal) execute as written.
- **C2** — MASTER updates:
  - Fix the §70 vs §117 button letterSpacing conflict (pick 1.5).
  - Document the three-tier `PageHeader` hierarchy (hero/tab/sub mapped to headlineLarge/Medium/Small).
  - Document the chip vocabulary: `GvChip` (filter), `JChip` (identity/critical), `StatusBadge` (semantic status).
  - Document `AppMotion.fast/medium/standard` tokens.
  - Document the barrel-file rule for feature imports.
- **C3** — Final report verbatim.

---

## 11. Non-negotiables (carried from v1)

1. No new bypasses. If tempted to write `GestureDetector + Container` button or hand-built `TextField`, add a primitive.
2. Don't re-litigate audit decisions (white-on-orange, 56h CTA, kill ShaderMask creep, single-page-title-per-role).
3. Push back on me if I try to skip Sprint A → migration, or skip C → leave drift.
4. Boss-readable summaries at each sprint boundary. Plain English. Layman's analogy at the end.

---

## 12. Decisions — all locked (2026-05-20)

- ✅ Move extension to barrel file (§5)
- ✅ Extract `AppSpacing` and `AppRadius` to separate files; add new `app_motion.dart` with `fast=150ms/medium=200ms/standard=Curves.easeOutCubic` (§3 + §8)
- ✅ PageHeader ships with `hero/tab/sub` enum mapped to existing `headlineLarge/Medium/Small` (§4 + §6)
- ✅ `JButton` gains `JButtonSize.standard` (56h) + `JButtonSize.compact` (40h, for in-row actions on applications page)
- ✅ Golden tests fix `MediaQuery(393×852)` + `ScreenUtil` baseline, light + dark variants
- ✅ MASTER §70 vs §117 button letterSpacing conflict resolved as `1.5` (Sprint C)

**Sprint A executes from §8.** The canonical work order is now `docs/SPRINT_PROMPT_v2.md`.

---

**Layman's analogy:** You hired a contractor to renovate the kitchen. They showed up with a quote based on photos. You said "walk the actual kitchen first." This document is the walk-through: every cabinet opened, every cabinet measured, every assumption in the quote checked against what's actually behind the drywall. Two surprises (the chip primitives are already there; the spacing/radii constants are already there). Three confirmations (button colour is the bug, ShaderMask creep is real, page headers are inconsistent). One recommendation per surprise. The quote that comes out the other side of this isn't bigger or smaller — it's accurate.
