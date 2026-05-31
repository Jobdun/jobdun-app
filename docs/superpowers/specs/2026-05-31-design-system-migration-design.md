# Design — App-wide design-system migration to home-parity

**Date:** 2026-05-31 · **Branch:** `feat/verified-builder-details-step6`
**Baseline checkpoint:** commit `2c4ba63` (home DS migration)
**Companion docs:** `docs/DESIGN_SYSTEM_HANDOFF.md`, `_RULES.md`, `_TOKENS.md`, `_COLOR_SYSTEM.md`

## Goal

The home feature was migrated to the audit-driven design system (commit `2c4ba63`). This
brings **every remaining feature** to the same standard ("home-parity"): icon sizes on the
`AppIconSize` scale, typography through the theme, accessible colour on accent surfaces,
and reduced-motion-aware entrances.

Success = `bash scripts/validate.sh` green, **zero** raw `size: N` icon calls in `lib/features`,
**zero** detached `TextStyle(` in feature widgets, **zero** white-on-orange glyphs, and the
golden suite passing (regenerated where shared widgets changed).

## Scope

In scope (all features): `jobs`, `applications`, `messaging`, `profile`, `verification`,
`auth`, `reviews`, `notifications`, `legal`, `ftue` + shared widgets in `lib/core/design/widgets/`
and the app roots (`lib/app/app.dart`, `lib/admin/app/admin_app.dart`).

Explicitly **out of scope** (do not touch — separate uncommitted work in the tree):
`supabase/functions/verify-licence/index.ts`, the four `20260531*` migrations,
`docs/VERIFICATION_FLOW_AUDIT.md`, `ios/IMAGE 2026-05-31 00:07:26.jpg`.

## The migration recipe (4 transforms)

Each is a mechanical, reviewable transform with an established home precedent.

### 1. Icon-size tokens
Replace raw sizes in `Icon(...)` (and icon params on widgets) with `AppIconSize.*.r`.

```dart
// before
Icon(AppIcons.bell, size: 24.r, color: c.text2)
// after
Icon(AppIcons.bell, size: AppIconSize.nav.r, color: c.text2)
```

Mapping (off-scale values snap to the nearest step):

| raw | token | use-case |
|----:|-------|----------|
| 11–14 | `AppIconSize.micro` (14) | caption-adjacent micro-glyph |
| 15–17 | `AppIconSize.inline` (16) | inside buttons / chips / labels |
| 18–22 | `AppIconSize.md` (20) | list-row leading, chevrons, field affordances |
| 23–28 | `AppIconSize.nav` (24) | nav items, app-bar actions |
| 29–36 | `AppIconSize.feature` (32) | section / primary-action tiles |
| 37–40 | `AppIconSize.hero` (40) | empty-state / hero |

Edge cases left raw **by design** (document, don't migrate): map-marker glyphs
(`home_map_view.dart:280`), anything inside a `photo_view`/canvas. When unsure, pick the
nearest step and note it — never invent a new value.

Import: most feature files already `import '.../core/design/colors.dart';` (the barrel
re-exports `AppIconSize`). Add it only where missing.

### 2. Typography on-scale
Replace detached `TextStyle(...)` with a theme style + `.copyWith(...)`. Drop off-scale
`fontSize:` overrides; snap to the nearest scale step (40/32/24/20/16/14/12).

```dart
// before
Text('x', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text1))
// after
final tt = Theme.of(context).textTheme;
Text('x', style: tt.headlineMedium!.copyWith(color: c.text1)) // headlineMedium = 24
```

Keep `letterSpacing`/`color`/`fontWeight` overrides via `copyWith`. Never reintroduce
`GoogleFonts.*` (already 0 in features — keep it that way).

### 3. a11y — dark-on-orange + semantics + targets
- Any icon/text on an **orange (`c.action`)** background → colour `c.onAction` (dark, 6.37:1),
  never `Colors.white`. Audit each of the 10 `Colors.white` feature sites: keep only where the
  background is genuinely dark; switch the on-accent ones.
- Icon-only buttons get `Semantics(label: …)` + `Tooltip` (home bell precedent).
- Tap targets ≥ 44×44 (the 48dp theme floor already covers padded buttons; verify custom
  `InkWell`/`GestureDetector` hit areas).

### 4. Reduced-motion
Guard `flutter_animate` entrance animations:

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;
// skip / shorten the entrance when reduceMotion is true (FtueHeroPhoto precedent)
```

`JStaggeredList` already honours it — list entrances routed through it need no change.

## Sequencing (phased, verified per phase)

Foundation first so feature work isn't invalidated by later shared-widget edits.

- **Phase 0 — checkpoint.** ✅ Done (`2c4ba63`).
- **Phase 1 — global enablers.** Dynamic-Type clamp `MediaQuery.withClampedTextScaling(0.9–1.3)`
  in `lib/app/app.dart` + `lib/admin/app/admin_app.dart`; confirm default `IconTheme` (24dp +
  legible colour) is in the live theme, not just preview. No feature edits.
- **Phase 2 — shared widgets + goldens.** `lib/core/design/widgets/*` icon/typography/onAction
  params (`JButton`, `JCard`, `JTextField`, `StatusBadge`, `job_card`, `tradie_card`,
  `review_card`). Regenerate affected goldens **once** here.
- **Phases 3+ — one feature per phase, highest-debt first:**
  profile (33) → jobs (17) → verification (13, +14 TextStyle files) → auth (25) →
  applications (4) → messaging (4) → reviews (2) → notifications → legal (5) → ftue (4).
- **Final — close-out.** Full `validate.sh` green; sync `MASTER.md` (onAction dark,
  `borderStrong`, `AppIconSize`, a11y section) + mark the 5 DS docs as shipped/historical
  (handoff P1/P3); update the handoff's "left to do".

Each feature phase ends with: `flutter analyze --no-fatal-infos` (clean on touched files) →
`flutter test` (targeted + goldens) → spot `bash scripts/validate.sh`.

## Per-phase verification gate

A phase is "done" only when:
1. `flutter analyze --no-fatal-infos` shows no new issues in touched files.
2. `flutter test` passes (regenerate goldens **only** for intentional shared-widget changes,
   never to paper over a regression — diff the golden before accepting).
3. The phase's grep targets are zero: `grep -rn "size: [0-9]" lib/features/<feat>` and
   `grep -rn "TextStyle(" lib/features/<feat>` (minus documented edge cases).
4. `dart format` clean on touched files.

## Risks & decisions

- **Golden churn.** Only Phase 2 should move goldens. If a feature phase moves a golden, a
  shared widget changed unexpectedly — stop and investigate (systematic-debugging), don't
  blind-regenerate.
- **File-size ceiling (500 LOC).** Some targets (verification widgets, profile pages) are near
  the budget. Migration is net-neutral on LOC, but if a file is already oversize, split per the
  CLAUDE.md recipe rather than growing it. Check `scripts/validate.sh OVERSIZE_ALLOWLIST`.
- **`validate.sh` is pre-existingly red** from admin `GoogleFonts`/`Colors.white`/format debt
  (memory `project_verification_remediation`) — that is **not** ours; judge success on *touched*
  files, not the global exit code.
- **Compact `JButton` 40/36dp** (applications row actions) — visible size < 44 (hit area padded
  to 48). Bumping visible size churns the compact golden; treat as optional polish, flag don't
  force.
- **`text2`-on-`surfaceRaised` 4.04:1 / white-on-red error 3.76:1** — theme-level audit items
  from the handoff P2; in scope only if they surface in a feature being migrated, otherwise
  leave for the theme pass.

## Out-of-scope / YAGNI

No new design tokens, no new widgets, no layout/IA redesign, no copy changes. This is a
fidelity migration to an **existing** system, not a redesign. The gated light theme
(`JColors.light`) stays untouched (app is dark-only).
