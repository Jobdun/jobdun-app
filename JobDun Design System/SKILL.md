---
name: jobdun-design
description: Use this skill to generate well-branded interfaces and assets for JobDun, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.
If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.
If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick orientation

JobDun is the Australian builder ↔ tradie marketplace. The design language is **Galvanised** — professional-tool aesthetic.

- **Foundation** `#252D34` (charcoal) — load-bearing structure
- **Action** `#CC4A10` (signal orange) — CTAs, distance, active nav
- **Type** Barlow + Barlow Condensed only (never Inter/Roboto/system)
- **Card radius** ≤ 14px · **Screen padding** always 20px · **Touch target** ≥ 48px
- **No emoji**, no exclamation marks in UI copy, no decorative animation, no gradients

Read `GALVANISED_SKILL_REFERENCE.md` first for the full ruleset, then `voice.md` for copy, `components.md` for RN code, `screens.md` for screen layouts. Tokens in `tokens.css` (web) and `tokens.rn.ts` (React Native).
