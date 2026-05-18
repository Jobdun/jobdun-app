# Jobdun — UI/UX Review (for second-opinion AI)

> Self-contained. Paste into another AI and ask: "Is this the best UI/UX
> setup for this product, and what would you change?" Includes weaknesses
> on purpose. Graded against standard UX priorities (accessibility, touch,
> performance, layout, type/color, motion, style).

## Product context that should drive UI/UX

Mobile app for **Australian construction tradies** (chippies, sparkies,
brickies, builders) + Builders who hire them. Users are often: **outdoors in
bright sunlight**, **wearing gloves or with dirty/wet hands**, **on older /
mid-range Android**, **a wide age range**, frequently **one-handed on site**.
This context matters more than aesthetic trends.

## Current UI/UX setup (factual)

- **Style:** "Aggressive Flat", **dark-only**. bg `#0F172A`, surface
  `#1E293B`, CTA safety-orange `#F97316`, no shadows, all-caps buttons,
  icon-heavy, 150–200ms transitions, no bounce.
- **Type:** Oswald (headings/buttons) + Open Sans (body) via `google_fonts`
  centralised in `AppTheme` (enforced — no per-widget font calls).
- **Tokens:** `AppIconSize` scale, `AppTouchTarget` (44 iOS / 48 Android,
  fixed dp), `AppSpacing`, `AppRadius`, `AppSelection`, `AppNavBar` (72dp),
  `JColors` theme extension. CI grep-guards block raw colors, raw icon
  sizes, raw `SizedBox` spacing, off-theme fonts.
- **Components:** `TappableIcon` (guaranteed ≥44/48 hit area + semantics),
  `JobCard`, `GvChip`, `AppButton`, labelled adaptive bottom nav, honest
  "coming soon" stubs for deferred features.
- **Icons:** Tabler via an `AppIcons` semantic catalogue (consistent set).
- **A11y done:** app-wide ≥44/48 touch targets (audited + guarded),
  semantic labels on icon-only controls, screen-reader labels decoupled
  from short visible nav labels, nav label text-scale clamped to 1.2,
  colour-not-only state where feasible.

## Grade by category

| Area | Grade | Notes |
|---|---|---|
| Touch & interaction | **A−** | Standardised 44/48 targets, ≥8 spacing, fixed-dp chrome. Strong for gloved hands. |
| Visual consistency | **A−** | Token system + CI guards is unusually disciplined; one icon-set migration mid-build, now consistent. |
| Motion | **B+** | 150ms, no bounce — appropriate. `prefers-reduced-motion` / `disableAnimations` not explicitly honoured. |
| Style fit | **B+** | Dark, heavy, utilitarian suits the trade. But see "dark-only outdoors" risk. |
| Accessibility (contrast) | **C+ / unknown** | Secondary text `#94A3B8` and especially `#64748B` on near-black `#0F172A` is borderline for the 4.5:1 normal-text minimum — **needs measured audit**. |
| Readability | **C+** | Body 13–15, captions 11, nav label ~10. Below the 16-on-mobile guideline. Risky for outdoor glare + older users + gloves. |
| Loading / perceived perf | **B−** | Skeleton/shimmer conventions exist but inconsistently wired; some screens just spin. |
| Content honesty | **A** | Deferred features are truthful "coming soon", never faked — good UX integrity. |

## Honest weaknesses / risks to pressure-test

1. **Dark-only for an outdoors product.** Tradies work in direct sun.
   A pure dark UI can be the *harder* choice for sunlight legibility
   despite looking modern. Is dark-only right here, or is a high-contrast
   / light / auto mode warranted for the field context?
2. **Small type + low secondary contrast.** 10–13pt text in `#64748B`/
   `#94A3B8` on `#0F172A`, used outdoors with gloves, by a wide age
   range. This is the single biggest real-world usability risk and likely
   the first thing field testing would surface.
3. **Color-contrast not formally measured.** Slate-500-on-near-black is
   plausibly below WCAG AA — needs an actual contrast pass on every
   text/background token pair, not vibes.
4. **Reduced-motion not handled.** Minor, but a real a11y gap.
5. **Empty/loading states uneven.** Some are polished honest stubs;
   others are bare spinners. Inconsistent perceived quality.
6. **One-handed reach.** 5-tab bottom nav is good for thumbs; but primary
   actions/filter sheets — are key controls inside the bottom-third reach
   zone on large phones?
7. **Glove/wet-hand input.** Targets are ≥48 (good) but small text fields
   (search, budget inputs) and date pickers may still be fiddly on site.

## Questions for the second-opinion AI

1. For an **outdoor, sunlight, gloved** trade audience — is dark-only the
   right call, or should there be a light/high-contrast/auto mode?
2. Are the **type scale (10–15pt) and secondary text colours** acceptable
   for this audience, or must they be larger / higher-contrast?
3. Which **WCAG checks** would you run first on these exact tokens
   (`#F1F5F9/#94A3B8/#64748B` on `#0F172A/#1E293B`)?
4. Is a **token system + CI grep-guards** the right level of design
   governance pre-launch, or overkill / under-kill?
5. What's the **highest-ROI UI/UX fix** before launch given the field
   context (sun, gloves, mid-range Android)?
6. Bottom nav at **72dp, 24 icon, ~10pt label, colour-only active** —
   good, or should active state also carry a non-colour cue?

## My one-line verdict

The *system* (tokens, touch targets, consistency, honesty) is genuinely
strong and ahead of typical MVP discipline. The *risk* is field
readability — dark-only + small, low-contrast secondary text for a
sunlight/gloves/older audience. That, not aesthetics, is what a second
opinion should hammer on.
