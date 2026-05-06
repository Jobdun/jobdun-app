# JobDun App · UI Kit

A click-thru React prototype of the JobDun mobile app, faithful to the Galvanised design language defined in the project root.

## Screens (click-thru)
1. **Builder Home** — find a tradie feed (search, filter chips, available + offline lists)
2. **Tradie Profile** — verification strip, ratings, reviews, sticky Invite to Job CTA
3. **Job Feed (Tradie)** — Jobs Nearby, urgent pinned to top
4. **Job Detail** — meta grid, map snippet, builder card, Accept / Decline
5. **Post a Job** — flat form (no wizard) with urgent toggle
6. **Chat** — full-screen messaging, foundation/surf bubble pair, action-orange send

## Components (`*.jsx`)
- `components.jsx` — primitives: `Btn`, `Badge`, `Avatar`, `Chip`, `Search`, `Card`, `BottomNav`, `TradieCard`, `JobCard`, `Eyebrow`, `Display`, `H1`, `H3`, `SectionRow`
- `data.jsx` — sample tradies + jobs
- One file per screen

## Run
Open `index.html`. The bottom-row nav switches screens; the in-device bottom nav also navigates between Home / Jobs / Chat / Profile.

## Tokens
Pulls `tokens.css` + `colors_and_type.css` from the project root. All colours, spacing, radius, type sizes come from there.

## Caveats
- Built from spec only — no Figma or production code was attached. Cross-reference shipping app before treating any screen as canon.
- Chat avoids read receipts per voice/spec ("not in MVP").
- Map is a styled placeholder. Swap for Mapbox / Google Maps in production.
