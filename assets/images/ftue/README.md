# FTUE Photography Brief

Two hero photos sit at the top of FTUE slides 1 and 3. They render inside
`FtueHeroPhoto` (`lib/features/ftue/presentation/widgets/ftue_hero_photo.dart`)
— 16:11 rounded card, navy bottom gradient applied in-app, hi-vis corner
accent. Do NOT pre-bake any filters or colour grading; the app handles all
treatment.

If an image is missing or fails to load, the widget falls back to a navy
placeholder and fires `ftue.image_load_failed` — the FTUE keeps working
either way, so it's safe to ship without these in place.

---

## slide_1_verified.jpg

**Subject** Close-up of a tradie's hand holding an Australian trade
licence card or hi-vis ID badge.

**Composition** Hand fills the lower-left third. Licence card angled,
slightly out of focus on the edges.

**Lighting** Natural daylight, slightly overcast or golden hour. NOT studio
lighting.

**Mood** Honest, grounded, real. Calloused hand preferred — looks lived-in.

**Colour** Will display full-colour, so warm earth tones + cool blue licence
card contrast well with the hi-vis orange brand accent.

**Avoid** Pristine studio hands, model-perfect skin, fake-looking licence
props, anything that screams "stock photo".

**Specs** 1600×1100px minimum (16:11), JPG, 85% quality, target <250KB.

---

## slide_3_aussie_site.jpg

**Subject** Group shot of 2–3 Australian tradies on a real construction
site, mid-conversation or working.

**Composition** Wide framing — environment visible (scaffolding, residential
build, ute in background).

**Lighting** Bright Australian daylight. Harsh shadows are fine — they read
as "real."

**Mood** Engaged, not posed. Tradies looking at each other or at work, NOT
at camera.

**Colour** Hi-vis vests (orange/yellow) are a bonus — they tie to the brand
palette.

**Avoid** US-style hard-hat colours (white = American site lead), corporate
site visits, suits, anyone in office attire, palm trees (reads as
Florida/Queensland sub-tropical specifically).

**Specs** 1600×1100px minimum (16:11), JPG, 85% quality, target <300KB.

---

## Sourcing options (in priority order)

1. **Commission shoot** — $1500–3000, ~2 weeks, best quality
2. **Stocksy United** — premium stock, $50–200/image. Search
   "australian tradesman" + "construction worker"
3. **EyeEm** — genuinely AU-shot photos, $100–300/image
4. **Unsplash** — free, last resort; heavy curation required to avoid the
   stock-photo feel

---

## Treatment

Both images receive a subtle navy bottom-gradient overlay IN THE APP (not
pre-baked). Keep the source files clean — no filtering, grading, or
sharpening passes.

---

## Currently shipped (v1)

Both files were sourced from the Unsplash free library
(https://unsplash.com/license — commercial use, no attribution required;
crediting anyway out of courtesy):

- `slide_1_verified.jpg` — Unsplash photo ID `VLPUm5wP5Z0`
  (https://unsplash.com/photos/VLPUm5wP5Z0) — close-up of a tradie in
  orange hi-vis + helmet drilling timber on-site. Stands in for the
  hand-and-licence brief until a commissioned shoot lands.
- `slide_3_aussie_site.jpg` — Unsplash photo ID `x-ghf9LjrVg`
  (https://unsplash.com/photos/x-ghf9LjrVg) — group of six hi-vis workers
  on an elevated slab/rebar site. Matches the "real Aussie site" energy
  the brief calls for.

Both fetched at `?w=1600&q=85&auto=format&fm=jpg&fit=crop&crop=entropy`
to hit the 16:11 target. Replace these whenever a commissioned shoot is
ready — file names are stable so the slide widgets need no edit.
