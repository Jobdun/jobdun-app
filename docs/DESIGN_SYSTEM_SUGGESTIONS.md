# Design System — Suggested Updates

**Date:** 2026-05-30 · **Companion to:** [`DESIGN_SYSTEM_AUDIT.md`](./DESIGN_SYSTEM_AUDIT.md) (read that first — every item here maps to a finding ID there). · **Status:** proposals only, nothing applied.

This is the "how to fix it" half. Part A is a **prioritized backlog** (what / why / where / effort). Part B gives **concrete, ready-to-apply values** for the top items, with contrast ratios re-computed and verified. Part C notes which web-stack recommendations from the research **don't** apply to Flutter. Part D suggests an order.

Effort: **S** ≈ <1h one-file edit · **M** ≈ a few files + tests · **L** ≈ multi-file migration.

---

## A. Prioritized remediation backlog

| ID | Sev | What | Why | Where | Effort |
|----|-----|------|-----|-------|:------:|
| **S0-CTA** | P0 | Make primary-CTA text legible on orange | 2.80:1 fails WCAG on the most-tapped control | `app_colors.dart:153`, `j_button.dart` | S |
| **S1-TEXT3** | P1 | Lighten the `text3` role | 3.07:1 — labels, hints, **placeholders** below floor | `app_colors.dart:148` | S |
| **S2-BORDER** | P1 | Add a stronger interactive-border token | input borders 1.41:1 fail 1.4.11 | `app_colors.dart`, `app_theme.dart:227-234` | S |
| **S3-SCALE** | P1 | Clamp `MediaQuery.textScaler` band | Dynamic Type unbounded; fixed heights overflow | `app.dart`, `admin_app.dart` | M |
| **S4-SPEC-A11Y** | P1 | Add an Accessibility section to `MASTER.md` | root cause — a11y was never a requirement | `MASTER.md` | S |
| **S5-TYPE-FLOOR** | P2 | Raise type floor (no 10sp; body-small ≥12sp) | below legibility minimum | `app_theme.dart:143,160,255` | S |
| **S6-TEXT2-RAISED** | P2 | Stop body text on `surfaceRaised` (or lift `text2`) | 4.04:1 on raised | tokens + usage rule | S |
| **S7-ERR-PAIR** | P2 | Use tinted error pair, not white-on-red | white-on-red 3.76:1 | `app_theme.dart:73`, urgent chips | S |
| **S8-MOTION** | P2 | Honor reduced-motion app-wide | only `JStaggeredList` does today | `flutter_animate` sites, router | M |
| **S9-ADMIN-FONTS** | P2 | Route admin text through `textTheme` | 115 `GoogleFonts.*` bypass + red CI | `lib/admin/**` | L |
| **S10-ADMIN-SPEC** | P2 | Rewrite `admin-web.md` to describe reality | doc describes a marketing page that doesn't exist | `pages/admin-web.md` | S |
| **S11-LS-CONFLICT** | P3 | Resolve `MASTER §70` vs §117 letter-spacing | self-contradiction (code = 1.5) | `MASTER.md:117` | S |
| **S12-PRIMITIVES** | P3 | Add a primitive color ramp under `JColors` | makes future re-tinting one-line | `app_colors.dart` | M |
| **S13-LEADING** | P3 | Set `bodyMedium` line-height | ~1.36 → 1.45 | `app_theme.dart:138` | S |
| **S14-LIGHT-THEME** | P3 | Wire-and-verify or delete gated light theme | untested, will rot | `app_colors.dart:167-191` | M |
| **S15-DOC-NITS** | P3 | Fix `brandDisplay` "Inter Black 900" comment | stale (renders Oswald 700) | `app_theme.dart:14` | S |
| **S16-COMPACT-BTN** | P3 | Re-check 40/36dp compact buttons on small phones | below iOS 44pt visible (tap area OK) | `j_button.dart:57,133` | S |

---

## B. Concrete proposals (verified values)

### S0-CTA — primary-CTA contrast *(decision required — re-opens a locked call)*

The audit's headline P0. White on `#F97316` = **2.80:1**. Three ways out, with verified ratios:

| Option | Change | CTA text ratio | Brand cost | Verdict |
|--------|--------|:--------------:|-----------|---------|
| **A — dark foreground** *(recommended)* | `onAction: Color(0xFF0F172A)` (reuse `background`) or legacy `Color(0xFF1A0A03)` | **6.37** / **6.88** | Loses the white "punch"; dark-on-orange reads heavier (arguably *more* on-brand: industrial hazard signage is black-on-orange) | Only fully WCAG-clean option that **keeps the bright safety-orange**. Reverses `FOUNDATION_AUDIT §11.2`. |
| **B — darken the orange** | `action: Color(0xFFC2410C)`, keep white text | white **5.18** | Orange goes burnt/muted; `action`-on-bg drops to 3.45, dulling the whole identity | Keeps white text but sacrifices the vibrancy that makes the brand. |
| **C — keep white, accept the gap** | no change | 2.80 | none | **Not viable** — fails even the 3:1 large-text floor; can't be justified once computed. |

**Recommendation: A**, with `onAction = #0F172A` (it reuses an existing token, so the CTA foreground is literally "the background color" — tidy). Apply at `app_colors.dart:153`; `JButton` primary (`j_button.dart:99-101`), `ColorScheme.onPrimary`, and role/urgent chips all inherit it. **This reverses a prior "non-negotiable," so it's your call** — pick A or B; C is off the table.

```dart
// app_colors.dart — dark theme
onAction: const Color(0xFF0F172A),   // was 0xFFFFFFFF — white=2.80:1 fails WCAG; this=6.37:1
```

### S1-TEXT3 — lighten the tertiary text role

Need ≥4.5:1 on `surface`. Verified candidates:

| Value | on bg | on surface | on raised |
|-------|:-----:|:----------:|:---------:|
| `#64748B` (current) | 3.75 ❌ | 3.07 ❌ | 2.18 ❌ |
| **`#8B98AB`** (proposed) | **6.10 ✅** | **5.00 ✅** | 3.54 (large only) |

```dart
text3: const Color(0xFF8B98AB),   // was 0xFF64748B (3.07:1) — now 5.0:1 on surface
```

Plus a usage rule (add to `MASTER`): *small/secondary text sits on `background` or `surface`, never `surfaceRaised`* — even `#8B98AB` only reaches 3.54 on raised. This single token change fixes `labelSmall`, input labels, hints, **placeholders**, icon defaults, and the muted-link pattern at once.

### S2-BORDER — interactive-border token

`#334155` (1.41:1) is fine as a *decorative* card/divider hairline but fails 1.4.11 as an *interactive* boundary. Add a second token rather than lighten the existing one:

```dart
// new in JColors
final Color borderStrong;        // interactive boundaries (inputs, focusable controls)
// dark:  borderStrong: const Color(0xFF708096),   // 3.63:1 on surface — passes 1.4.11
```

Wire `borderStrong` into `enabledBorder`/`border` in `inputDecorationTheme` (`app_theme.dart:227-234`); keep `border` (`#334155`) for `cardTheme`/`dividerTheme`. (Focused border already passes at orange 5.22:1.)

### S3-SCALE — clamp Dynamic Type

Wrap both app roots so OS text-scaling is honored but bounded to a tested band:

```dart
// in app.dart / admin_app.dart, inside the builder under ScreenUtilInit
MediaQuery.withClampedTextScaling(
  minScaleFactor: 0.9,
  maxScaleFactor: 1.3,
  child: child!,
)
```

Then audit fixed heights (`j_button.dart` 56/40, Pinput 56, dense rows) to use `min`-height + intrinsic growth rather than hard heights, so a 1.3× label still fits. Verify on iOS at the largest standard size and Android "Largest."

### S4-SPEC-A11Y — add an Accessibility section to `MASTER.md`

The root-cause fix. Add a section that makes the implicit explicit:

```markdown
## Accessibility (non-negotiable)
- Contrast: body text ≥ 4.5:1; large (≥18.66px bold / ≥24px) & UI/icons/borders ≥ 3:1.
  Placeholders are content — they need 4.5:1 too.
- Touch targets: ≥ 48dp (we already floor to 48 in AppTheme).
- Dynamic Type: honor OS text scale, clamped 0.9–1.3. Fixed heights must grow with text.
- Reduced motion: every animation needs a MediaQuery.disableAnimations branch.
- Never convey state by color alone — pair with icon or text.
```

### S5-TYPE-FLOOR — raise the small end

| Role | Now | Proposed |
|------|-----|----------|
| `labelSmall` | 10sp | **11sp** (`app_theme.dart:160`) |
| input `labelStyle` | 11sp | keep 11sp (paired with stronger color) |
| `bodySmall` / caption | 11sp | **12sp** (`app_theme.dart:143`) |

Retire 10sp entirely. Combined with S1, eyebrows go from "tiny + faint" to "small but legible."

### S7-ERR-PAIR — error styling

For error *text*, prefer the existing tinted pair `urgentTx #FCA5A5` on `urgentBg #450A0A` (**8.51:1**) over white-on-solid-`urgent` (3.76:1). `ColorScheme.onError` (`app_theme.dart:73`) stays white only where the red fill is a large badge, not body text.

### S10-ADMIN-SPEC — rewrite `pages/admin-web.md`

Replace the marketing-template content with what's actually built: breakpoints (1024 sidebar-collapse, 720/1100 grid columns), modal `maxWidth`s (440/480/720), the shared dark theme, and the keyboard-focus expectation. Document the **content-density** intent that's real.

---

## C. Flutter vs the (web-centric) research — what does *not* port

The research is excellent but written for the web/CSS stack. To avoid mis-applying it:

| Research recommendation | Flutter reality | Do instead |
|-------------------------|-----------------|-----------|
| OKLCH color space in CSS | Dart `Color` is sRGB 32-bit ARGB; no OKLCH literal | Keep hex `Color(0xFF…)`; use OKLCH *thinking* (uniform lightness steps) when **designing** the ramp, then convert to hex. |
| DTCG `.tokens.json` + Style Dictionary build step | No CSS variables; tokens are Dart consts/ThemeExtension | `JColors` ThemeExtension **is** the semantic layer — keep it. A pipeline is only worth it if you later need to emit the same tokens to a non-Flutter surface. |
| shadcn/Radix `--primary`/`--primary-foreground` | Flutter `ColorScheme` + ThemeExtension already do on-color pairing | Already done (`onAction`, `onSurface`…). Just fix the failing pair (S0). |
| `prefers-reduced-motion` media query | `MediaQuery.disableAnimations` (OS "remove animations") | Same intent, different API — apply it everywhere (S8). |
| Container queries / CSS breakpoints | `LayoutBuilder` / `MediaQuery` | Admin already uses `LayoutBuilder`; mobile scales via ScreenUtil. |
| `rem` for type, `px` for hairlines | `.sp` (scales) for type, `.r`/`.w` for sizing | Already the convention; the gap is the **clamp** (S3), not the unit. |
| Storybook | `flutter test` golden files (already scaffolded per Foundation Audit A9) | Extend golden coverage to the fixed token states. |

**Net:** Jobdun doesn't need a token *pipeline* — it needs the *values* in its existing semantic layer to pass contrast, and an a11y section in its spec. The architecture is already what the research recommends, expressed in Dart.

---

## D. Suggested sequencing

**First pass — accessibility-clean (mostly S-effort, do together):**
1. **S4-SPEC-A11Y** — write the rule first, so the rest has a target.
2. **S0-CTA** *(get the user's A-vs-B decision)*, **S1-TEXT3**, **S2-BORDER**, **S5-TYPE-FLOOR**, **S7-ERR-PAIR** — all token/theme edits in `app_colors.dart` + `app_theme.dart`. Re-run the contrast script; every row should go green. Add/refresh golden tests.
3. **S11-LS-CONFLICT**, **S15-DOC-NITS**, **S13-LEADING** — trivial cleanups while in those files.

**Second pass — behavior & surfaces:**
4. **S3-SCALE** + audit fixed heights (needs a device run to confirm).
5. **S8-MOTION** — sweep `flutter_animate` sites.
6. **S10-ADMIN-SPEC** (doc), then **S9-ADMIN-FONTS** (the big L — also turns `validate.sh` green).

**Later / when touching the files:**
7. **S6**, **S12-PRIMITIVES**, **S14-LIGHT-THEME**, **S16-COMPACT-BTN**.

After the first pass, re-run the audit: the health score should move from **17/20** to **~19–20**, with Accessibility going 2→4. That's the point at which the design system is defensibly "working perfectly."
