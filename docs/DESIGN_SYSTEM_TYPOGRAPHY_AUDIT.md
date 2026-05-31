# Typography Token System — Detailed Audit

**Date:** 2026-05-31 · **Source of truth:** `lib/app/theme/app_theme.dart:86–166` (the `textTheme`) + `:16` (`brandDisplay`). · **Fonts:** Oswald (display/headings/buttons) + Open Sans (body/labels) via `google_fonts`, configured in `AppTheme` only.

A standalone, rigorous audit of Jobdun's **type token system** — every role, its size/weight/letter-spacing/line-height, benchmarked against typographic best practice (modular scale, line-height, measure, tracking, platform baselines). Written to be shared for a second opinion. All values are the **current shipping** ones (post the 2026-05-31 type-floor fixes). Companion: [`DESIGN_SYSTEM_RULES.md`](./DESIGN_SYSTEM_RULES.md), [`DESIGN_SYSTEM_TOKENS.md`](./DESIGN_SYSTEM_TOKENS.md).

---

## 1. Current type system (dark theme)

| Role | Font | Size | Weight | Letter-spacing | Line-height | Colour | Use |
|------|------|:----:|:------:|:--------------:|:-----------:|--------|-----|
| `displayLarge` | Oswald | 40 | 700 | 1.2 | — (default ~1.17) | text1 | hero / splash |
| `displaySmall` | Oswald | **40** | 700 | 1.0 | — | text1 | (same size as Large) |
| `headlineLarge` | Oswald | 32 | 700 | 0.8 | — | text1 | screen titles |
| `headlineMedium` | Oswald | 24 | 600 | 0.5 | — | text1 | section / tab titles |
| `headlineSmall` | Oswald | 20 | 600 | 0.3 | — | text1 | sub-section |
| `titleLarge` | Oswald | 16 | 600 | — | — | text1 | card headers |
| `titleMedium` | Open Sans | 15 | 600 | — | 1.6 | text1 | emphasised body |
| `bodyLarge` | Open Sans | 15 | 400 | — | 1.6 | text1 | primary body |
| `bodyMedium` | Open Sans | 13 | 400 | — | 1.45 | text2 | secondary body (most-used) |
| `bodySmall` | Open Sans | 12 | 500 | — | — | text2 | caption / metadata |
| `labelLarge` | Oswald | 14 | 700 | 1.5 | — | text1 | buttons (ALL CAPS) |
| `labelMedium` | Open Sans | 12 | 600 | 0.5 | — | text2 | tags / chips |
| `labelSmall` | Open Sans | 11 | 600 | 0.8 | — | text3 | eyebrows (`FieldLabel`) |
| `brandDisplay()` | Oswald | 40 | 700 | 3.0 | — | (passed) | wordmark only |

Distinct sizes in use: **40, 32, 24, 20, 16, 15, 14, 13, 12, 11** (10 steps).

---

## 2. What's right ✅

1. **Strong font pairing.** Oswald (condensed, industrial display) + Open Sans (humanist body) pair on a real contrast axis — exactly the "contrast, don't match" rule. Not two similar sans-serifs.
2. **Centralised.** All styles flow through `AppTheme.textTheme`; **zero per-widget `GoogleFonts`** and zero detached `TextStyle(` in feature code (verified by grep).
3. **Material-aligned role structure.** display / headline / title / body / label × L/M/S — a familiar, complete role set (mirrors Material 3's 15-style system).
4. **Type floor met.** Smallest is `labelSmall` 11 / `bodySmall` 12 — at the iOS 11pt / web 12px floors (fixed 2026-05-31, was 10/11).
5. **Good weight contrast.** 700 → 600 → 500 → 400 gives clear hierarchy via weight, not just size.

---

## 3. Findings (benchmarked)

### T1 — Scale ratio is inconsistent, and the small end is over-populated *(High)*
Adjacent ratios:

| Step | Ratio | | Step | Ratio |
|------|:-----:|---|------|:-----:|
| 40→32 | 1.250 | | 16→15 | **1.067** |
| 32→24 | 1.333 | | 15→14 | **1.071** |
| 24→20 | 1.200 | | 14→13 | **1.077** |
| 20→16 | 1.250 | | 13→12 | **1.083** |

- The **heading half** (40→16) is roughly modular but with **no single ratio** (1.20–1.33).
- The **small half** (16→11) is a near-**linear** ramp — **six sizes inside a 5px band**, 1px apart. **15 / 14 / 13 are perceptually indistinguishable.** Best practice (product register): one ratio ~1.2 and *fewer, distinct* steps. This is the biggest structural issue.

### T2 — `displayLarge` and `displaySmall` are both 40px *(Med)*
They differ only by letter-spacing (1.2 vs 1.0). There's **no size hierarchy within "display"** — one role is effectively redundant. (Material's display L/M/S are 57/45/36.)

### T3 — Line-heights are partial and inconsistent *(High)*
- **Set:** `titleMedium` 1.6, `bodyLarge` 1.6, `bodyMedium` 1.45.
- **Unset (font default ~1.17):** every display/headline, `titleLarge`, `bodySmall`, all labels.
- **Two different body line-heights** (1.6 for 15px, 1.45 for 13px) with no system. Best practice: one body value ~1.5; headings *explicitly* tighter (~1.1–1.25), not left to the font default.

### T4 — Letter-spacing runs against convention + token/usage drift *(Med)*
- Headings carry **positive tracking that grows with size** (40 = +1.2, 32 = +0.8, 24 = +0.5, 20 = +0.3). The typographic norm is the inverse — large display tightens (≈0 to negative), small/caps text loosens. For condensed Oswald this may be a deliberate brand choice, but it's a conscious deviation worth ratifying.
- **Token vs usage mismatch:** `labelSmall` declares ls `0.8`, but `FieldLabel` (its main consumer) overrides to `0.12 * 11 = 1.32`, and other sites hand-tune `0.5`/`0.6`. The token isn't the source of truth in practice.

### T5 — Primary body is below platform baselines *(Med)*
`bodyLarge` / primary body = **15px**. Material body-large = 16, iOS body = 17. Jobdun's body sits **1–2px under both** platform defaults — readable but a deliberate downscale that compounds with the dense small-end cluster.

### T6 — Mixed scaling model: fixed sizes vs `.sp` overrides *(Med)*
Theme roles are **fixed logical px** (40, 32, …) that honour the OS text scaler. But feature code sometimes overrides with `.copyWith(fontSize: X.sp)` (flutter_screenutil **device-width** scaling). Mixing the two means some text scales with screen width and some doesn't — inconsistent across devices. (One such `28.sp` was removed on home; an app-wide sweep is pending — see handoff.)

### T7 — Adjacent roles 1px apart *(Low)*
`titleLarge` 16 vs `bodyLarge`/`titleMedium` 15 — distinguished only by font (Oswald vs Open Sans) + weight. Borderline; tight.

### T8 — No tabular/number treatment *(Low)*
Stats, pay rates ($85/hr), counts use the proportional body/heading fonts; no tabular-figure or mono option for aligned numerics.

---

## 4. Benchmark scorecard

| Dimension | Target | Status |
|-----------|--------|:------:|
| Font pairing | contrast axis, ≤3 families | ✅ Strong |
| Role structure | complete, named | ✅ Good (Material-aligned) |
| Scale ratio consistency | one ratio ~1.2–1.25 | ❌ Varies 1.07–1.33 |
| Step distinctness | each step visibly distinct | ❌ Cramped (6 sizes in 5px) |
| Line-height coverage | all roles, body ~1.5 | ⚠️ Partial; headings unset; 2 body LHs |
| Letter-spacing | convention + single source | ⚠️ Reversed + token/usage drift |
| Type floor | ≥11pt / 12px | ✅ Met |
| Body vs platform baseline | 16 web / 17 iOS / 16 M3 | ⚠️ 15 (below) |
| Scaling model | one consistent model | ⚠️ Fixed + `.sp` mixed |

---

## 5. Recommended direction (proposal — for review)

A cleaner system would: **one ratio, fewer steps, explicit line-heights, a ratified tracking rule.** One concrete option (1.2 "minor third", dense-product-appropriate), anchored at a 16px body:

| Role | Size | Weight | Line-height | Notes |
|------|:----:|:------:|:-----------:|-------|
| display | **36** | 700 | 1.1 | collapse the two 40s into one display |
| headlineLarge | **30** | 700 | 1.15 | |
| headlineMedium | **24** | 600 | 1.2 | |
| headlineSmall | **20** | 600 | 1.25 | |
| titleLarge | **17** | 600 | 1.3 | card/section headers |
| bodyLarge | **16** | 400 | 1.5 | primary body (up from 15, hits platform baseline) |
| bodyMedium | **14** | 400 | 1.5 | secondary body (drop 13/15 duplication) |
| bodySmall | **12** | 500 | 1.4 | caption (floor) |
| labelLarge | **14** | 700 | 1.0 | buttons, +tracking |
| labelMedium | **12** | 600 | 1.2 | chips/tags |
| labelSmall | **11** | 600 | 1.2 | eyebrows |

Net: **~7 distinct sizes** (36/30/24/20/17/16/14/12/11 → collapses the 15/14/13 mush), every role gets an explicit line-height, and primary body returns to 16. *This is illustrative, not prescriptive — the ratio/sizes are the decision below.*

Also recommended regardless of the scale chosen:
- **One body line-height** (~1.5) and **explicit heading line-heights** (~1.1–1.25).
- **Ratify the tracking rule** — either keep the brand's positive-on-display tracking deliberately, or flip to the convention (tight display, loose small/caps). Then make `labelSmall`'s token the single source so `FieldLabel` stops overriding it.
- **Pick one scaling model** — fixed (recommended for product, honour OS scaler + clamp) and ban `.copyWith(fontSize: X.sp)`.

---

## 6. Open decisions (for the second opinion)

1. **Ratio:** 1.2 (minor third, dense) vs 1.25 (major third, current-ish top) — which fits a trades product?
2. **Body size:** stay at 15 (denser) or move to 16 (platform-aligned)?
3. **Display tracking:** keep the brand's positive tracking on big Oswald, or adopt the tight-display convention?
4. **Step count:** is collapsing to ~7 sizes too aggressive for the existing screens, or right?
5. **Scaling:** fully fixed + OS-scaler-clamp, or keep some screenutil `.sp` for very large screens?

---

*Method: values read directly from `app_theme.dart`; ratios computed; benchmarks from the design-study cheat-sheet (modular scale 1.2–1.333, body line-height 1.4–1.6, type floor 11pt/12px, Material 3 + iOS body baselines). Colours (`text1/2/3`) and their contrast are covered separately in `DESIGN_SYSTEM_AUDIT.md` §5.*
