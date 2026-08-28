# FTUE hero assets

One full-bleed hero per onboarding slide. They render inside `FtueHero`
(`lib/features/ftue/presentation/widgets/ftue_hero.dart`) — `BoxFit.cover`,
top-aligned, with a `c.background` scrim fading the bottom 41% into the page.

| File | Slide | Headline |
|------|-------|----------|
| `slide_1_verified.webp` | 1 | ONLY VERIFIED. / NO TIMEWASTERS. |
| `slide_2_nearby.webp` | 2 | JOBS NEAR YOU. / APPLY IN THREE TAPS. |
| `slide_3_aussie_site.webp` | 3 | BUILT FOR / AUSSIE SITES. |

If a file is missing or fails to decode, the widget falls back to the page
background and fires `ftue.image_load_failed`. The FTUE keeps working either
way, so it is safe to ship without these in place.

---

## Where they come from

Source of truth is Figma — `JobDun-Screens` → **Onboard**, node `17:5084`
(file key `9JQxSZQEqo06TGKI8t717q`).

Each slide's visual is **two layers** in Figma:

1. `image 2` — a peach line-illustration (suburban street / street map /
   scaffolding + Australia outline), drawn at **70% opacity**.
2. `image 1` (slide 3: `image 3`) — a cut-out photo of a tradie in Jobdun
   uniform, full opacity, on top.

Both sit inside the 393×567 `Image Content` frame, each positioned by a
clipping box plus an inner transform on the `<img>`. Reproducing that nested
transform in Dart would be verbose and easy to get wrong, so the two layers are
**flattened at authoring time** into one transparent WebP per slide.

The compositor script and the exact per-layer geometry (taken verbatim from
`get_design_context` on nodes `50:9938`, `50:9973`, `36:8721`) live alongside
this note in the design-handoff bundle. To regenerate: re-export the six source
PNGs from the Figma nodes above, re-run the script, then convert:

```bash
magick <slide>.png -quality 88 -define webp:alpha-quality=90 <slide>.webp
```

---

## Specs

- **393×567 logical, exported at 3× → 1179×1701px.** That is the exact frame
  proportion; `BoxFit.cover` handles taller/shorter devices.
- **WebP with alpha, quality 88.** Visually identical to the source PNG at ~12%
  of the size (5.0 MB PNG → 616 KB for all three). Flutter decodes WebP with
  alpha natively on Android, iOS and web.
- **Transparent background — do not flatten onto white.** The transparency is
  load-bearing: it is what lets the hero sit on `c.background` and follow the
  active theme instead of punching a white rectangle into dark mode.
- **No pre-baked gradient.** The bottom fade is drawn in-app from
  `c.background` so it stays seamless against the page in both themes.

---

## Floating cards

The badges over each hero (`Licensed & Verified`, suburb pins, `Made in
Australia`, …) are **not** part of the image — they are Flutter widgets
(`FtueOverlayCard`) positioned as fractions of the hero box. That is what lets
slide 2 swap in the user's real suburbs from the IP-geo lookup. Keep them out
of the exported artwork.

Their glyphs come from Phosphor via `AppIcons`, except the Australia outline,
which has no Phosphor equivalent and ships as the exported Figma vector at
`lib/core/assets/icon-australia.svg`.
