# Jobdun — Design System Unification Sprint (v2)

You are operating as my senior Flutter engineer + design systems architect on Jobdun (Flutter + Supabase, AU construction trades marketplace, mobile-first). Project rules in CLAUDE.md apply — match my pace, principal-level reasoning, end with a layman's analogy at every sprint boundary.

## Required reading before you start

Two docs live in project knowledge. Read both before writing any code:

1. **`UI_UX_INCONSISTENCY_AUDIT.md`** — screens-vs-theme audit. Identifies the 12 categories of drift across feature screens.
2. **`DESIGN_SYSTEM_FOUNDATION_AUDIT.md`** — MASTER-vs-theme + theme-vs-primitives audit. Grounds every claim in this prompt against actual code. **§8 of that doc is the work order; this prompt is its narrative form.**

If anything in this prompt contradicts the foundation audit, the **foundation audit wins** (it was written against the real source; this prompt is its derivative).

## Context

The UI/UX audit identified screen-level drift. The foundation audit traced the root cause: ~6 design-system primitives are missing, so screens bypass the system because the system is incomplete. We're fixing the primitive layer first, migrating screens second, locking with CI third. Three sprints. Don't skip ahead. Don't let me skip ahead. **Stop at every sprint boundary and let me verify before continuing.**

## Architecture

Strict dependency direction, no cheating:

```
Tokens  →  Primitives  →  Patterns  →  Screens
```

- **Tokens** (`lib/app/theme/`): `app_colors.dart` (existing, keep `JColors` class name), `app_theme.dart` (existing), plus extracted `app_spacing.dart`, `app_radii.dart`, and new `app_motion.dart`.
- **Primitives** (`lib/core/design/widgets/`): `JButton` (renamed from `AppButton`), `JTextField` (existing), `FieldLabel` (existing), `PageHeader` (new), `JCard` (new), `JChip` (new — solid identity only), `JSwitch` (new), `BottomActionBar` (new). Untouched existing primitives: `GvChip` (filter pills), `StatusBadge` (translucent semantic).
- **Patterns**: feature-private compositions (`_StatBadge` → promoted; `_ApplySheet` stays private). Compose primitives only. Never reach past to raw `Container(decoration: BoxDecoration(...))`.
- **Screens**: import primitives + the `core/design/colors.dart` barrel. Never import individual files in `lib/app/theme/` directly.

Naming: `J` prefix for new primitive widgets. `AppSpacing`/`AppRadius`/`AppMotion` for token classes (existing semantic naming, kept). Class for colors is `JColors`, **not** `AppColors` — verify before any rename.

## Confirmed decisions (do not re-litigate)

- White text on orange CTAs (`onAction → #FFFFFF`).
- `JButton` standard height: **56h** (MASTER §110). Add `compact` 40h variant for in-row actions (applications page REJECT/SHORTLIST/HIRE).
- `PageHeader` ships with **three sizes** mapped to existing theme tokens: `hero` → `headlineLarge` (32sp, `/home` only), `tab` → `headlineMedium` (24sp, tab landings), `sub` → `headlineSmall` (20sp, pushed sub-pages).
- Tokens get extracted from `app_colors.dart` into separate files. Keep existing semantic names (`AppSpacing.xs/sm/md/lg/xl/xxl`, `AppRadius.badge/chip/btn/card/input/avatar`) — they already match MASTER. Do not introduce parallel `kSpace*` or `kRadius*` schemes.
- `ShaderMask` reserved for the JOBDUN wordmark on `/login` and `/register` only — uses existing `AppTheme.brandDisplay`.
- Goldens use Flutter's built-in `matchesGoldenFile` (no `golden_toolkit` dep). Wrap every golden in a fixed `MediaQuery` (393×852, iPhone 14 baseline) and initialize `ScreenUtil` with that size — non-negotiable for stable CI.

---

## SPRINT A — Primitive completion (2–3 days)

### Day 1 — Tokens + core primitives

**A1 — Flip `onAction` to white + doc the color contract**
- `lib/app/theme/app_colors.dart:75` (dark) and `:102` (light): change `onAction: Color(0xFF1A0A03)` → `Color(0xFFFFFFFF)`.
- Add MUST/MUST NOT doc comment above `onAction`:
  ```dart
  /// Foreground when bg is c.action. White per MASTER §1.
  /// MUST be used as text/icon color on primary CTAs.
  /// MUST NOT be used as a standalone text color elsewhere.
  ```
- Same one-line MUST/MUST NOT comment on every semantic color: `action`, `actionBg`, `actionPressed`, `available`, `surface`, `surfaceRaised`, `text1`, `text2`, `text3`, `border`, `verified`, `urgent`. This is a public API.
- Verify no widget currently depends on the dark `onAction` value (grep for `c.onAction` consumers). Note: `ColorScheme.onPrimary` is wired to `c.onAction` in `app_theme.dart:58-84`, so Material widgets using `colorScheme.onPrimary` will pick up white correctly.

**A2 — Rename `AppButton` → `JButton`, 56h, add compact variant, remove `.toUpperCase()`**
- Move `lib/core/widgets/app_button.dart` → `lib/core/design/widgets/j_button.dart`.
- Rename class `AppButton` → `JButton`, enum `AppButtonVariant` → `JButtonVariant`.
- Add `enum JButtonSize { standard, compact }`. `standard` → 56h (`Size.fromHeight(56.h)` at both `:57` primary and `:73` secondary, replacing 52h). `compact` → 40h, used for in-row actions only (applications page).
- Remove `label.toUpperCase()` at line `:45`. Callers must now pass uppercase strings explicitly — this surfaces intent at the call site and lets the lint catch lowercase regressions.
- Add doc comment listing use cases for each variant × size combo.
- Use IDE Dart-aware rename refactor, not blind text find-replace, to avoid corrupting string literals or comments.
- Do rename + all call-site updates in one atomic commit. Run `flutter analyze` immediately after — zero errors required.
- After rename, verify the `filledButtonTheme` overlay in `app_theme.dart` still applies (`FilledButton` has its own theme — may need parallel override if `JButton` extends one and the existing `elevatedButtonTheme` overlay no longer hits).

**A3 — Build `PageHeader` with three-size hierarchy**
- New file: `lib/core/design/widgets/page_header.dart`.
- Signature:
  ```dart
  enum PageHeaderSize { hero, tab, sub }

  class PageHeader extends StatelessWidget {
    final String eyebrow;
    final String title;
    final PageHeaderSize size; // default: PageHeaderSize.tab
    final Widget? trailing;
    // ...
  }
  ```
- Size mapping (consume existing theme tokens — do NOT hand-tune fontSize):
  - `hero` → `theme.textTheme.headlineLarge` (32sp w700, ls 0.8) — `/home` only.
  - `tab` → `theme.textTheme.headlineMedium` (24sp w600, ls 0.5) — tab landings (jobs, applications, messages, verification).
  - `sub` → `theme.textTheme.headlineSmall` (20sp w600, ls 0.3) — pushed sub-pages (job_create, profile_edit).
- Eyebrow uses `FieldLabel`. Title uppercased at render time (the casing rule is a `PageHeader` concern, not a global).
- Never use `ShaderMask`. Document in class doc: "ShaderMask is reserved for the JOBDUN wordmark in auth via `AppTheme.brandDisplay`. PageHeader is flat `c.text1` only."

**A4 — Build `BottomActionBar`**
- New file: `lib/core/design/widgets/bottom_action_bar.dart`.
- Signature: `BottomActionBar({required JButton primary, JButton? secondary})`.
- SafeArea-aware. Surface-tinted with shadow. Pattern source: existing inline implementation in `profile_edit_page.dart:362-392` — extract the chrome, drop in `JButton`.

### Day 2 — Remaining primitives + token extraction + barrel

**A5 — Promote `_InfoCard` → `JCard`, `_StatBadge` → `JStatBadge`**
- Source: private classes in `profile_page.dart` (around `:592-598` for `_InfoCard`, `:550-556` for `_StatBadge`).
- New file: `lib/core/design/widgets/j_card.dart`. Both classes live here.
- Delete privates from `profile_page.dart` and update references in same commit.
- Note: `job_card.dart` and `tradie_card.dart` are feature cards — leave them. `JCard` is generic chrome only.

**A6 — Build `JChip` (solid identity chip only)**
- New file: `lib/core/design/widgets/j_chip.dart`.
- Signature: `JChip({required String label, Color? backgroundColor, Color? foregroundColor})`. Defaults: `c.action` bg, white fg.
- Scope is **identity/critical chips only** — role chip on profile, URGENT badge on job_detail, trade-type solid chip.
- Class doc must spell out the vocabulary so future devs don't collide:
  - `GvChip` → filter pills (toggleable, exists at `lib/core/design/widgets/gv_chip.dart`)
  - `StatusBadge` → translucent semantic status (verified/available/urgent/pending/pro, exists at `lib/core/design/widgets/status_badge.dart`)
  - `JChip` → solid identity/critical chip (this file)
- Do **not** try to unify all three under one widget. Different jobs.
- Migrate inline solid chips in same task: `profile_page.dart:206-223` (role chip), `job_detail_page.dart:121-137` (URGENT badge).

**A7 — Build `JSwitch`**
- New file: `lib/core/design/widgets/j_switch.dart`.
- One canonical treatment: `activeThumbColor: Colors.white, activeTrackColor: c.action`. Matches `job_create_page` pattern — more discoverable, matches orange-dominant rhythm. Replaces both existing inconsistent styles.

**A8 — Token extraction**
- Extract `AppSpacing` from `app_colors.dart:202-209` → `lib/app/theme/app_spacing.dart`. **Keep existing values verbatim: xs=4, sm=8, md=16, lg=24, xl=32, xxl=48.**
- Extract `AppRadius` from `app_colors.dart:211-218` → `lib/app/theme/app_radii.dart`. **Keep existing semantic names and values: badge=4, chip=6, btn=6, card=8, input=6, avatar=8.** These match MASTER §238 (sharp, 4–8). Do NOT introduce 12/16/24 — that violates MASTER.
- Create new `lib/app/theme/app_motion.dart`:
  ```dart
  abstract final class AppMotion {
    static const fast = Duration(milliseconds: 150);
    static const medium = Duration(milliseconds: 200); // MASTER §216: no longer
    static const standard = Curves.easeOutCubic;
  }
  ```
- Update all imports across `lib/` after extraction (`app_button.dart`, `app_theme.dart`, anywhere referencing `AppRadius.btn`/`AppRadius.input`/`AppRadius.card` etc.). Run `flutter analyze` after — zero errors required.

**A8b — Create the colors barrel**
- New file: `lib/core/design/colors.dart`:
  ```dart
  export 'package:jobdun/app/theme/app_colors.dart' show JColors, JColorsX;
  export 'package:jobdun/app/theme/app_spacing.dart' show AppSpacing;
  export 'package:jobdun/app/theme/app_radii.dart' show AppRadius;
  export 'package:jobdun/app/theme/app_motion.dart' show AppMotion;
  ```
  (Verify project import style is package: or relative before committing — match what the rest of the codebase uses.)
- Do **not** migrate feature files yet — that's a Sprint B sub-task. Sprint A leaves the barrel in place, ready to consume.

### Day 3 — Golden tests

**A9 — Golden tests with stable ScreenUtil baseline**
- Use Flutter's built-in `matchesGoldenFile`. No new dependencies.
- Every golden test must:
  1. Wrap the widget under test in a `MediaQuery` with a fixed `Size(393, 852)` (iPhone 14).
  2. Initialize `ScreenUtil` with the same size before `pumpWidget`.
  3. Render against both light and dark `ThemeData` (two goldens per variant).
- Files:
  - `test/golden/j_button_test.dart` — variant × state matrix (~9–18 goldens with light/dark)
  - `test/golden/j_text_field_test.dart`
  - `test/golden/j_card_test.dart`
  - `test/golden/j_chip_test.dart`
  - `test/golden/j_switch_test.dart`
  - `test/golden/page_header_test.dart` — three sizes
  - `test/golden/bottom_action_bar_test.dart`
- If a golden fails locally on the first run because no baseline exists, generate baselines with `flutter test --update-goldens` and commit them.

**STOP at end of Sprint A.** Show me:
1. Per-file diff summary (created/modified/deleted).
2. `flutter analyze` output — zero issues required.
3. `flutter test` output — all goldens + existing tests pass.
4. List of any judgment calls you made beyond this plan, with rationale.
5. Boss-readable summary (1 paragraph, plain English, conversion-relevant where applicable).
6. Layman's analogy for what Sprint A accomplished.

**Wait for my explicit confirmation before starting Sprint B.**

---

## SPRINT B — Screen migration (2–3 days)

Mechanical pass. Use the audit file paths and line numbers verbatim. Don't re-discover them.

**B1 — Inline bottom-bar CTAs → `BottomActionBar(primary: JButton(...))`**
- `profile_edit_page.dart:362–392` (SAVE CHANGES)
- `job_create_page.dart:419–467` (POST JOB)
- `job_detail_page.dart:329–385` (APPLY NOW)
- `job_detail_page.dart:549–568` (SUBMIT APPLICATION)
- `jobs_page.dart:140–150` (POST JOB header chip) — this is a header trailing widget, use `JButton` directly via `PageHeader.trailing`, **not** `BottomActionBar`.
- Applications page row buttons (`applications_page.dart:332, 360, 391`) → `JButton(size: JButtonSize.compact)`, NOT `BottomActionBar`. They're row actions, not bottom CTAs.

**B2 — Inline eyebrow recipes → `FieldLabel` / `PageHeader`**
- `PageHeader(size: hero)` on `/home` (`home_page.dart:218–223, 371–376, 379–392`).
- `PageHeader(size: tab)` on tab landings: `jobs_page.dart:94–114`, `applications_page.dart:99–119`, `messages_page.dart:65–66`, `verification_page.dart:119–143`.
- `PageHeader(size: sub)` on pushed sub-pages: `job_create_page.dart:128–147`, `profile_edit_page.dart:167–176`.
- Inline `FieldLabel` replacements: `profile_page.dart:592–598`, `job_detail_page.dart:102–106, 456–460, 472–477, 521–525`.
- **Delete** `_SectionLabel` in `job_detail_page.dart:605–619`.

**B3 — Strip `ShaderMask` from non-brand titles**
- Remove from: `jobs_page.dart:102–114`, `applications_page.dart:107–119`, `job_create_page.dart:136–147`, `home_page.dart:379–392`.
- Keep on: `login_page.dart:128–140`, `register_page.dart:258–268` only.
- Stripped titles render as flat `c.text1` via `PageHeader`.

**B4 — Hand-built `TextField` → `JTextField`**
- `jobs_page.dart:160–216` (search field)
- `job_create_page.dart:283–358, 477–510`
- `job_detail_page.dart:479–518` (apply sheet)

**B5 — Two `Switch` → `JSwitch`**
- `profile_page.dart:777–784` (dark-mode toggle)
- `job_create_page.dart:403–409` (urgency)

**B6 — Decorative `c.action` → `c.text2`/`c.text3`**
- `messages_page.dart:246, 285` (avatar initials)
- `home_page.dart:396–402` (location pin + city)
- `job_detail_page.dart:213, 256, 502` (decorative chip/initial uses)
- Keep `c.action` only for: actual CTAs, loading indicators, critical status, URGENT badges, role chips.

**B7 — `c.available`-as-link → underlined `c.text3`**
- `profile_page.dart:401–407` ("Change" availability)
- `profile_page.dart:687–693` ("Upload" verification)
- Pattern source: `login_page.dart:307–310` ("Forgot?"). Reuse that exact muted-link treatment.

**B8 — Casing — pass uppercase strings to `JButton`**
- `register_page.dart:636–637`: `'Create Account'` → `'CREATE ACCOUNT'`
- `profile_page.dart:85`: `'Sign out'` → `'SIGN OUT'`
- `trade_category_picker.dart:502`: `'Use this trade'` → `'USE THIS TRADE'`
- Scan remaining `JButton` call sites and normalize.

**B9 — Barrel migration**
- Find-replace all feature file imports of `lib/app/theme/app_colors.dart` → `lib/core/design/colors.dart`.
- `grep -rln "app_colors.dart" lib/features/` first to scope; expect ~38 files.
- Do this last in Sprint B so it doesn't churn other diffs.

**STOP at end of Sprint B.** Show me:
1. Per-screen diff summary.
2. `flutter analyze` (zero issues).
3. `flutter test` (all goldens + unit tests pass).
4. 30-minute manual smoke test checklist for me to walk every screen in light + dark mode.
5. Boss-readable summary.
6. Layman's analogy.

**Wait for me to walk the smoke test before Sprint C.**

---

## SPRINT C — Lock it (1 day)

**C1 — CI lint script**

Create `scripts/check-design-system.sh`, make it executable, wire into PR gate (find `.github/workflows/ci.yml` or equivalent and add a step):

```bash
#!/usr/bin/env bash
set -e

fail() { echo "FAIL: $1"; exit 1; }

# No raw TextField in features (use JTextField)
grep -rn "TextField(" lib/features/ --include="*.dart" \
  | grep -v "JTextField" | grep -v "// design-system-ok" \
  && fail "Use JTextField, not raw TextField" || true

# No GestureDetector + styled Container button pattern
grep -rn -A2 "GestureDetector" lib/features/ --include="*.dart" \
  | grep "decoration: BoxDecoration" \
  && fail "Use JButton, not GestureDetector + Container" || true

# No ShaderMask outside auth (brand wordmark only)
grep -rn "ShaderMask" lib/features/ --include="*.dart" \
  | grep -v "lib/features/auth/" \
  && fail "ShaderMask reserved for JOBDUN wordmark in auth/" || true

# No magic letterSpacing constant (use FieldLabel)
grep -rn "letterSpacing: 0.12" lib/features/ --include="*.dart" \
  && fail "Use FieldLabel, not inline letterSpacing constants" || true

# No headlineSmall/Medium/Large fontSize override (use PageHeader)
grep -rn "headline\(Small\|Medium\|Large\).*copyWith.*fontSize" lib/features/ --include="*.dart" \
  && fail "Use PageHeader, not headline*.copyWith(fontSize: ...)" || true

# No raw orange hex in features
grep -rn "0xFFF97316" lib/features/ --include="*.dart" \
  && fail "Use c.action, not raw orange hex" || true

# Direct theme-file imports forbidden in features — go through the barrel
grep -rn "import.*'.*app/theme/app_\(colors\|spacing\|radii\|motion\)\.dart'" lib/features/ --include="*.dart" \
  && fail "Import tokens via core/design/colors.dart, not individual theme files" || true

echo "Design system checks passed."
```

Tag intentional exceptions with `// design-system-ok: <reason>` comments inline.

**C2 — MASTER.md updates**
- Fix the §70 vs §117 button letterSpacing conflict — pick `1.5` (matches the typography table and theme).
- Document the three-tier `PageHeader` hierarchy (hero/tab/sub mapped to headlineLarge/Medium/Small).
- Document the chip vocabulary: `GvChip` (filter), `JChip` (identity/critical), `StatusBadge` (semantic status).
- Document `AppMotion.fast/medium/standard` tokens.
- Document the barrel-file rule for feature imports.
- Document the muted-underline link pattern as the canonical "tappable but not primary" treatment.

**C3 — Final report**
- Summary of: primitives shipped, screens migrated, CI checks live.
- Updated `UI_UX_INCONSISTENCY_AUDIT.md` with everything resolved struck through; anything deferred called out explicitly.
- Recommendation for what to enforce in code review going forward.
- Known gaps not enforced by the lint (e.g., hardcoded spacing/radii values in features) and how to monitor them.

---

## Non-negotiables throughout

1. **No new bypasses.** If you find yourself wanting to write `GestureDetector + Container` or `TextField(decoration: ...)` in a feature file, stop and add a primitive instead.
2. **Don't re-litigate audit decisions.** White-on-orange, 56h CTA, three-size PageHeader, kill ShaderMask creep — settled. Execute.
3. **Push back on me** if I try to skip Sprint A and jump to migration, or skip Sprint C and leave drift unlocked.
4. **Boss-readable summaries** at each sprint boundary. Plain English. Conversion-relevant metrics where applicable.
5. **Layman's analogy** at the end of each sprint summary.
6. **Show diffs before destructive operations** (rename, delete). Atomic commits where renames touch >1 file.
7. **If anything in this prompt contradicts the foundation audit, the audit wins.**

Start with Sprint A, Task A1. Show me the diff before running anything destructive.

---

**End of prompt.**
