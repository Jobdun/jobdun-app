# Jobdun — Best-Practice Rules Checklist

**Date:** 2026-05-31 · **Companions:** [`DESIGN_SYSTEM_AUDIT.md`](./DESIGN_SYSTEM_AUDIT.md) · [`DESIGN_SYSTEM_SUGGESTIONS.md`](./DESIGN_SYSTEM_SUGGESTIONS.md) · [`DESIGN_SYSTEM_COLOR_SYSTEM.md`](./DESIGN_SYSTEM_COLOR_SYSTEM.md)

Every implementation rule from the design study, with Jobdun's status, the **target number**, where it's enforced, and what's left — so you can check the whole setup at a glance, and see what the **HOME · FIXED** preview now applies.

**Status key:**
- ✅ **Met** — enforced in the live theme/widgets already
- 🟢 **Preview** — newly applied in the fixed preview (`PreviewTheme` / clamped scaling)
- ⚠️ **Gap** — partially met / needs attention
- ❌ **Fail** — violates the target
- ⚙️ **Widget-level** — fix needs editing shared widget code (would change the live app too, so it can't be shown via a theme-only A/B)

---

## 1. Color & Contrast

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Body-text contrast | ≥ 4.5:1 | ⚠️→🟢 | `text1` ✅; `text2` on raised 4.04 ❌; `text3` 3.07 ❌ → fixed in preview (`#8B98AB`) |
| Large/UI/icon contrast | ≥ 3:1 | ⚠️ | most ✅; borders 1.41 ❌ → fixed in preview (`#708096`) |
| CTA text contrast | ≥ 4.5:1 | ❌→🟢 | white-on-orange 2.80 → preview uses dark `onAction` (6.37) |
| Color never the only signal | pair w/ icon/text | ✅ | status badges use dot + label |
| Single accent, used for action only | Restrained | ✅ | orange = CTA/critical only (MASTER §51) |
| No banned backgrounds (white/`#F8FAFC`) | dark `#0F172A` | ✅ (dark) / ❌ (light theme) | live is dark-only; gated light theme uses the banned white |

## 2. Typography

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Body floor | ≥ 16px web / ≥ 11pt iOS | ⚠️→🟢 | `bodySmall` 11sp, `labelSmall` 10sp → preview raises to 12/11 |
| Line-height (body) | 1.4–1.6 | ⚠️→🟢 | `bodyLarge`/`titleMedium` 1.6 ✅; `bodyMedium` none → preview 1.45 |
| Modular scale ratio | 1.2–1.333 | ✅ | 40/32/24/20/16 ≈ 1.2–1.33 |
| Measure (prose) | 45–75ch | ✅ | mobile single-column, naturally short |
| One/two families, weight contrast | ≤ 3 families | ✅ | Oswald + Open Sans, configured in `AppTheme` only |
| Type scales with OS setting | honor + clamp | ⚠️→🟢 | passthrough only → preview clamps `textScaler` 0.9–1.3 |

## 3. Spacing & Grid

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Spacing scale | 4/8pt grid | ✅ | `AppSpacing` 4/8/16/24/32/48; **0** raw `SizedBox` in features |
| Radius scale | small/consistent | ✅ | `AppRadius` 4–8 band |
| Whitespace via tokens | `Gap(n)` only | ✅ | enforced by `validate.sh` |

## 4. Icons

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| One icon library | single source | ✅ | `AppIcons` is the only `phosphor_flutter` seam; **0** direct in features |
| Icon grid | 24×24 | ✅ | Phosphor is a 24-grid set |
| Sizes on the scale | 16 / 20 / 24 (32–40 feature) | ✅ | MASTER §210: nav 20–24, inline 16–20, feature 32–40 |
| Sensible default size/colour | 24dp, inherit colour | ⚠️→🟢 | most icons set their own size; **preview now sets default `IconTheme` 24dp + `text2`** |
| Icon-on-accent contrast | ≥ 3:1 | ❌ ⚙️ | white icons on orange tiles (`_PrimaryActionCard`, FAB) = 2.80 — **hardcoded `Colors.white`, bypasses the token**; needs a widget edit |
| No emoji as icons | SVG/icon font | ✅ | none |

## 5. Touch & Targets (iOS / Android / Web)

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Android target | 48 × 48 dp | ✅ | `minTap = Size(48,48)` + `MaterialTapTargetSize.padded` (`app_theme.dart:176,188`) |
| iOS target | 44 × 44 pt | ✅ | exceeded by the 48dp floor |
| WCAG minimum (2.5.8) | 24 × 24 px | ✅ | met everywhere |
| WCAG AAA (2.5.5) | 44 × 44 | ✅ standard / ⚙️ compact | `JButton.standard` 56dp ✅; **`compact` 40dp / text-compact 36dp** visible < 44 (hit-area padded to 48) — `j_button.dart:57,133`, used on Applications page, not Home |
| Spacing between targets | ≥ 8px | ✅ | spacing scale / `Gap` |

> On the **Home** page specifically, touch targets are already fully compliant (no compact buttons in the content) — the 48dp floor covers the bell, FAB, cards, and rows.

## 6. Components & States

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Full state matrix | default/hover/focus/active/disabled/loading/empty/error | ✅ | `JButton` states; visible orange focus border |
| Loading = skeleton (not spinner) | content-shaped | ✅ | `JSkeletonList`; spinners only inline/overlay |
| Empty states teach + CTA | no blank screens | ✅ | `EmptyState`, per-tab empties |
| Error states recover | "try again" | ✅ | paged error builders with retry |
| Consistent affordances | one button/chip vocabulary | ✅ | `JButton`/`JChip`/`StatusBadge`/`GvChip` documented |

## 7. Motion

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Duration | 150–200ms (Jobdun) | ✅ | `AppMotion.fast/medium`, `easeOutCubic` |
| No bounce/spring | — | ✅ | MASTER §228 |
| `prefers-reduced-motion` | always honored | ⚠️ | only `JStaggeredList` respects `MediaQuery.disableAnimations`; `flutter_animate` micro-interactions don't — app-wide sweep needed |

## 8. Accessibility (cross-cutting)

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Semantic labels on icon-only buttons | every one | ⚠️ | `Semantics` on ~16 feature sites; expand to icon buttons/rows |
| Focus visible | ≥ 2px, ≥ 3:1 | ✅ | orange focus border on inputs |
| Text resize to 200% | no clipping | ⚠️→🟢 | preview clamps scaling; fixed heights still need an audit at max scale |
| Don't disable a11y features | — | ✅ | no `outline:none`-equivalents |

## 9. Platform conventions

| Rule | Target | Status | Where / note |
|------|--------|:------:|--------------|
| Follow nav/gesture conventions | per-platform | ⚠️ (by choice) | Material-only on both iOS+Android; `AdaptiveIcon` swaps glyphs on iOS — a deliberate brand decision, should be documented |
| System status-bar handling | adaptive | ✅ | `SystemUiOverlayStyle` per brightness |
| Safe areas | respect insets | ⚠️ | `SafeArea` used 33× but inconsistently — no single page-scaffold primitive |

---

## What the HOME · FIXED preview now applies (theme-level)

The preview re-renders the **real** home page under `PreviewTheme`, so it picks up everything that's theme-driven: **contrast fixes** (CTA/`text3`/borders), **type floor + line-height**, **clamped text scaling**, and now **icon defaults (24dp + legible colour)**. The 48dp touch floor is inherited from the base theme, so it's identical (and already compliant) in both.

## What it can't show (widget-level — needs real code, changes live too)

These bypass the theme, so they're the same in preview and live until the widget is edited:
1. **White-on-orange icon tiles** (`_PrimaryActionCard`, FAB, completeness banner) — hardcoded `Colors.white`, so the `onAction` token fix doesn't reach them. → swap to a contrast-safe icon colour or `c.onAction`.
2. **Compact buttons 40/36dp** (`j_button.dart`) — visible size below 44pt (hit area is padded to 48). → bump compact to 44dp if the layout allows. (Not on Home; it's the Applications row actions.)
3. **App-wide reduced-motion** — `flutter_animate` call sites need the `MediaQuery.disableAnimations` guard.

If you want these too, they're real edits to shared widgets — say the word and I'll apply them (the live app changes, and you'd compare against git history rather than the A/B button).

---

*Targets are from the design study cheat-sheet (WCAG 2.2 AA, Apple HIG, Material 3). Jobdun statuses verified against `lib/app/theme/*`, `lib/core/design/widgets/*`, and `scripts/validate.sh`.*
