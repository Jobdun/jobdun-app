# Design System — Token Reference & OKLCH Gauge

**Date:** 2026-05-30 · **Source of truth:** `lib/app/theme/` (`app_colors.dart`, `app_theme.dart`, `app_spacing.dart`, `app_radii.dart`, `app_motion.dart`) · **Theme shown:** **dark** (the production theme; light is gated, §6). · **Companions:** [`DESIGN_SYSTEM_AUDIT.md`](./DESIGN_SYSTEM_AUDIT.md) · [`DESIGN_SYSTEM_SUGGESTIONS.md`](./DESIGN_SYSTEM_SUGGESTIONS.md)

This is the complete, current token list with **every color converted to OKLCH** (L = perceived lightness 0–100%, C = chroma/saturation, H = hue 0–360°), so we can judge the palette the way modern systems do — on *perceptual* terms, not by hex eyeballing. The verdict is in §5.

> **Why OKLCH for the gauge:** OKLCH separates "how light it looks" (L) from "how colorful" (C) and "what color" (H), and L is perceptually uniform — two colors at the same L *look* equally bright regardless of hue. That makes it the right lens for two questions the audit raised: *do the neutrals step evenly?* and *why does white text fail on orange but pass on red?* (Dart `Color` itself is sRGB; OKLCH is the **design-time** reasoning tool — you tune the ramp in OKLCH, then store hex. See `SUGGESTIONS.md §C`.)

---

## 1. Color tokens — neutral ramp (slate family)

| Role | Hex | OKLCH | Usage |
|------|-----|-------|-------|
| `background` | `#0F172A` | `oklch(20.8% 0.040 266)` | app scaffold |
| `surface` / `card` | `#1E293B` | `oklch(27.9% 0.037 260)` | cards, sheets, input fill |
| `surfaceRaised` / `border` | `#334155` | `oklch(37.2% 0.039 257)` | elevated/selected; also borders+dividers |
| `text3` | `#64748B` | `oklch(55.4% 0.041 257)` | eyebrows, hints, placeholders, muted links |
| `text2` | `#94A3B8` | `oklch(71.1% 0.035 257)` | body-secondary, metadata |
| `text1` | `#F1F5F9` | `oklch(96.8% 0.007 248)` | headlines, primary body |

## 2. Color tokens — accents (the 5 status hues + amber)

| Role | Hex | OKLCH | Usage |
|------|-----|-------|-------|
| `action` | `#F97316` | `oklch(70.5% 0.187 48)` | primary CTA, focus, loaders (safety orange) |
| `actionPressed` | `#EA6C0A` | `oklch(67.3% 0.179 49)` | pressed overlay on action |
| `verified` | `#22C55E` | `oklch(72.3% 0.192 150)` | success / verified checks |
| `urgent` | `#EF4444` | `oklch(63.7% 0.208 25)` | error / destructive |
| `available` | `#3B82F6` | `oklch(62.3% 0.188 260)` | "available now" status (never a CTA) |
| `star` | `#F59E0B` | `oklch(76.9% 0.165 70)` | rating amber |
| `onAction` | `#FFFFFF` | `oklch(100% 0 0)` | fg on action — **fails contrast, see audit P0** |

## 3. Color tokens — tinted bg/text pairs (compound chips/banners)

| Pair | Bg hex / OKLCH | Text hex / OKLCH | Contrast |
|------|----------------|------------------|:--------:|
| action | `#431407` `oklch(26.6% 0.076 36)` | `#FED7AA` `oklch(90.1% 0.073 71)` | 11.56 ✅ |
| verified | `#052E16` `oklch(26.6% 0.063 153)` | `#86EFAC` `oklch(87.1% 0.136 154)` | 10.62 ✅ |
| urgent | `#450A0A` `oklch(25.8% 0.089 26)` | `#FCA5A5` `oklch(80.8% 0.103 20)` | 8.51 ✅ |
| available | `#1E3A5F` `oklch(34.6% 0.074 256)` | `#93C5FD` `oklch(80.9% 0.096 252)` | 6.38 ✅ |

## 4. Type · spacing · radius · motion tokens

**Type** (`app_theme.dart:90-166`) — Oswald (display/headings/buttons) + Open Sans (body/labels):

| Role | Font | Size | Weight | Letter-spacing | Line-height | Color |
|------|------|:----:|:------:|:--------------:|:-----------:|-------|
| displayLarge | Oswald | 40 | 700 | 1.2 | — | text1 |
| displaySmall | Oswald | 40 | 700 | 1.0 | — | text1 |
| headlineLarge | Oswald | 32 | 700 | 0.8 | — | text1 |
| headlineMedium | Oswald | 24 | 600 | 0.5 | — | text1 |
| headlineSmall | Oswald | 20 | 600 | 0.3 | — | text1 |
| titleLarge | Oswald | 16 | 600 | — | — | text1 |
| titleMedium | Open Sans | 15 | 600 | — | 1.6 | text1 |
| bodyLarge | Open Sans | 15 | 400 | — | 1.6 | text1 |
| bodyMedium | Open Sans | 13 | 400 | — | *(none → ~1.36)* | text2 |
| bodySmall | Open Sans | 11 | 500 | — | — | text2 |
| labelLarge | Oswald | 14 | 700 | 1.5 | — | text1 |
| labelMedium | Open Sans | 12 | 600 | 0.5 | — | text2 |
| labelSmall | Open Sans | 10 | 600 | 0.8 | — | text3 |
| `brandDisplay()` | Oswald | 40 | 700 | 3.0 | — | (passed in) |

**Spacing** (`app_spacing.dart`, 4pt grid): `xs 4` · `sm 8` · `md 16` · `lg 24` · `xl 32` · `xxl 48`
**Radius** (`app_radii.dart`, 4–8 band): `badge 4` · `chip 6` · `btn 6` · `input 6` · `card 8` · `avatar 8`
**Motion** (`app_motion.dart`): `fast 150ms` · `medium 200ms` · curve `easeOutCubic` (no bounce, no `slow`)

---

## 5. The OKLCH gauge — is this good branding & practice?

### ✅ What the OKLCH numbers say is *right*

1. **The neutral ramp is textbook.** Hue is locked tight across all six steps (266→248°, effectively one slate-blue family) and chroma stays low and even (~0.04), dropping to ~0 only at the near-white `text1`. This is exactly how a tinted-neutral ramp should behave — it reads as "one slate," not six unrelated grays. Solid foundation.
2. **The tinted bg/text pairs are designed correctly.** Every `*Bg` sits at ~26% L (dark, surface-level) and every `*Tx` at ~80–90% L (light). Same-hue, opposite-lightness = automatic 8–11:1 contrast. Whoever built these understood the principle.
3. **Accent chroma and hue placement are good.** Chroma is consistent (0.165–0.208 — uniformly punchy) and the hues are well-separated into distinct families: orange 48°, amber 70°, green 150°, blue 260°, red 25°. No two status colors collide.
4. **The `brandFlame` gradient is perceptually smooth** — L descends 94→82→70→62→54% as the hue rotates yellow→orange→red (103°→35°). A genuinely nice flame ramp (logo-only, correctly fenced).

### ⚠️ What the OKLCH numbers expose as *off*

1. **The accents are NOT lightness-aligned — and that's the root of the contrast problem.** They span **L 62–77%**:
   - `action` (orange) **70.5%**, `verified` (green) **72.3%**, `star` **76.9%** → *light* accents
   - `urgent` (red) **63.7%**, `available` (blue) **62.3%** → *darker* accents
   
   White text needs roughly **L ≤ 45%** behind it to clear 4.5:1. So the high-L accents (orange, green) **can't carry white text** — that's *why* `onAction` white = 2.80:1 (audit P0), while white on the lower-L red still only scrapes 3.76:1. The fix choice is now a one-number decision: either **keep the bright ~70% accents and put dark text on them** (recommended — `onAction → #0F172A`), or **pull the accents down to ~55% L** so white works (which dulls the brand). This is the single most useful thing OKLCH tells you about this palette.

2. **The neutral ramp has holes exactly where contrast-safe UI needs to live.** The L steps are uneven: 20.8 → 27.9 → 37.2 → **[gap]** → 55.4 → 71.1 → **[gap]** → 96.8. There's nothing in the **40–55%** band (where a 3:1 border belongs) or the **60%** band (where a 4.5:1 tertiary text belongs). That's not a coincidence — it's why `text3` (55%) and `border` (37%) fail contrast. The proposed fixes literally fill the gaps: `text3 → #8B98AB` (67.6%), `borderStrong → #708096` (59.5%). So those aren't patches; they **complete the ramp**.

3. **"Available blue" shares the neutral's hue.** `available` is H **260°**; the slate neutrals are H **257°**. They differ almost only in chroma, so a saturated-blue status can read as "just a brighter slate." Minor, but if blue is meant to be a distinct signal, nudging its hue (toward ~250 or ~270) would separate it.

4. **Palette origin is Tailwind v3-era sRGB, not OKLCH.** These are the classic Tailwind hexes (`slate-900/800/700/500/400`, `orange-500`, `green-500`, `red-500`, `blue-500`, `amber-500`) — which were HSL-designed. Tailwind **v4** re-defined those exact roles in OKLCH for this reason. Jobdun is on the older foundation. It's perfectly serviceable, but if the goal is "OKLCH-correct," the move is to re-derive the ramp in OKLCH with **pinned L steps** (neutrals every ~10–12%, accents at one chosen L) and bake the result back to hex.

### Verdict

**Good palette, sound branding, one structural flaw.** The neutrals and the tinted pairs are genuinely well-made; the identity (dark slate + safety orange) is distinctive and category-right. The flaw is **lightness discipline on the accents and the gaps in the neutral ramp** — which is precisely what produces the contrast failures in the audit. You don't need to rebuild the palette. You need to: (a) decide dark-text-on-accent vs lower-L accents (the orange question), and (b) add the two missing ramp steps (`borderStrong`, a lighter `text3`). Do those and the palette is both on-brand *and* OKLCH-defensible.

If you want, the next step is a **proposed OKLCH-pinned ramp** — I'd re-space the neutrals to even ~11% L steps and pin the accents to a single L, then convert back to hex and re-run the contrast script so every pair is green before you change a line of Dart.

---

## 6. Notes

- **Light theme** (`app_colors.dart:167-191`) is defined but gated (app is dark-only). Its values have **never been contrast-checked** and aren't included above — treat as untested until wired (audit P3, `SUGGESTIONS.md S14`).
- **`onAction = #FFFFFF`** is listed as current but is the audit's P0 — shown here for completeness, not endorsement.
- OKLCH values computed via the sRGB→OKLab→OKLCH transform (Ottosson) over the literal token hexes; reproducible.
