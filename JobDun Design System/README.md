# JobDun · Galvanised Design System

**JobDun** is an Australian two-sided marketplace connecting **builders** with **tradies**. The product solves the trust + coordination problem on both sides: builders waste time chasing unreliable tradies; tradies waste time on bad-faith builders. JobDun's answer is a transparent scorecard built organically from real jobs, plus loyalty mechanics and a flat usage fee that pays for itself on a single job.

The design language is called **Galvanised** — a professional-tool aesthetic. Not consumer. Not startup-y. Built like a precision instrument that a tradie reaches for the way they reach for a quality tape measure.

> **Foundation:** `#252D34` (galvanised-steel charcoal) · **Action:** `#CC4A10` (signal orange)
> **Type:** Barlow + Barlow Condensed · **Spacing:** 4pt grid · **Card radius ≤ 14px**

---

## Sources & Provenance

This system was built from a uploaded design language pack:

| File (in this project) | Original | Purpose |
|---|---|---|
| `GALVANISED_SKILL_REFERENCE.md` | `SKILL.md` | Master ruleset — read this first |
| `tokens.css` | `tokens.css` | Web tokens — copy-paste ready |
| `tokens.rn.ts` | `tokens.rn.ts` | React Native tokens (light + dark) |
| `voice.md` | `voice.md` | Copy guidelines + brand vocabulary |
| `components.md` | `components.md` | Annotated React Native components |
| `screens.md` | `screens.md` | Screen inventory + layout rules |

No Figma, no codebase repository, and no production app screenshots were attached — this system is the *intended* spec, not a recreation of shipping product. UI kit screens here are faithful to the spec but should be reviewed against any real product UI before being treated as canon.

---

## Index

```
README.md                       ← you are here
GALVANISED_SKILL_REFERENCE.md   master design rules
SKILL.md                        agent skill entrypoint (Claude Code compatible)

tokens.css                      primitive + semantic CSS tokens
tokens.rn.ts                    React Native token object + useTheme()
colors_and_type.css             webfont @font-face + element defaults

voice.md                        copy guidelines
components.md                   RN component reference
screens.md                      screen inventory

assets/                         logos, mark, brand assets
fonts/                          Barlow + Barlow Condensed (woff2)
preview/                        design-system preview cards (tab cards)
ui_kits/
  jobdun-app/                   mobile UI kit — click-thru prototype
    index.html                  iOS frame, multi-screen click-thru
    *.jsx                       screen + component sources
```

---

## Content Fundamentals

Galvanised copy reads like one builder talking to another on a job site. The voice rules:

- **Direct.** Subject, verb, object. No preamble.
  - ✓ "Job posted. 3 tradies notified."
  - ✕ "Your job is live! Let the magic begin 🎉"
- **Specific.** Numbers as digits, always. "3 tradies", "3.2 km", "142 jobs", "7am".
- **Calm.** **No exclamation marks** in system UI. Competent people don't shout.
- **Honest.** "Payment failed." Not "Payment couldn't process."
- **Sentence case** for all UI labels (display headings are the only ALL CAPS exception, e.g. `FIND A TRADIE`).
- **Australian spelling** — *Licence*, *Licenced*, *Insurance*. Not License/Licensed.
- **Em-dash** (—) for ranges + separations, never a hyphen.
- **No emoji** in navigation, buttons, badges, or form labels. Status uses dots and check marks (✓), not emoji.

### Brand vocabulary
| Use | Don't use |
|---|---|
| Tradie / Tradies | Contractor, service professional |
| Builder | Client, customer |
| Crew | Team |
| Job | Project, booking, task |
| Site | Location, property |
| Rate | Price, cost |
| Quote | Estimate, proposal |
| Timesheet | Hours log |
| Check-in / Check-out | Clock-in |

Avoid: *professional, verified expert, service provider, booking, gig, talent.*

### Voice in action
| Context | Galvanised | Off-brand |
|---|---|---|
| Empty state | "No jobs posted yet. Post your first job to find available tradies nearby." | "Nothing to see here yet!" |
| Error | "Payment failed. Check your card details and try again." | "Oops! Something went wrong." |
| Push | "Marcus K. accepted your job — Site starts 7am tomorrow" | "Great news! Your job has been accepted!" |
| Confirm | "Post Job" | "Submit", "Confirm" |

Pull-quotes from `voice.md`: short, specific, actionable. Max 60 chars on push titles, 120 on push body.

---

## Visual Foundations

### Colour
A two-colour brand carried by **foundation charcoal `#252D34`** (load-bearing — nav, primary buttons in light mode, avatars) and **signal orange `#CC4A10`** (CTAs, active nav, distance labels — *always* the action colour). Distance is in action orange on every surface, no exceptions.

Three semantic-status colours are **fixed** and never shift between light and dark: **verified emerald `#0D8A5A`**, **urgent red `#C73B2E`**, **available blue `#1A7AD4`**. Each comes with a tint background + dark text variant for chips and badges.

Background hierarchy (light): `bg #F4F6F8` → `surf #EAEEF2` → `card #FFFFFF` — three steps that create elevation without shadow.
Dark mode: `bg #0E1216` → `surf #1C2428` → `card #252D34`. The primary button **flips** from foundation to action in dark, because foundation on dark is invisible.

### Type
**Barlow Condensed** for display, headings, ratings, prices, earnings — anything that needs presence. **Barlow** for body, labels, UI. *Never* Inter, Roboto, SF Pro, or system-ui as primary. Letter-spacing on Condensed headings: `0.02em`. Eyebrow labels: `0.12em` + uppercase. Stats and prices are **always** Barlow Condensed 700.

### Spacing
4pt grid: `4 / 8 / 12 / 16 / 20 / 32 / 48 / 64`. **Screen horizontal padding is always 20px.** Not 16, not 24. Minimum touch target is 48px high.

### Backgrounds, motion, surface
- **No gradients.** No mesh, no glow, no decorative gradient bg.
- **No background imagery** behind UI. Solid `--c-bg`.
- **No decorative animation.** No Lottie, no confetti, no spring.
- Allowed: 100ms fade between screens, 1s opacity-pulse skeleton loaders. **Max 150ms** for any transition. `ease`. No bounce.

### Hover / press
- Press: `opacity: 0.85` (or `0.9` on cards). No shrink, no colour shift.
- Disabled: `opacity: 0.4`.
- Offline tradie cards: `opacity: 0.45` (lossy at-a-glance signal — they're not actionable).

### Borders, radius, shadow
- Card radius **≤ 14px** — never 16, never pill. Buttons 9px. Chips 8px. Badges 5px. Avatar blocks 10px (never circular — this isn't a social app).
- `1px` solid `--c-border` on cards, dividers, inputs. **Borders carry the elevation, not box-shadow.** Shadow-heavy cards are a Galvanised antipattern.
- One light shadow allowed: sticky CTA bar (`0 -2px 8px rgba(37,45,52,0.04)`), to lift it off content.

### Layout rules
- Status bar always at top, system-aware.
- Bottom nav: 62px tall, 4 tabs (Home / Jobs / Chat / Profile). 10px bottom-padding for the home indicator.
- One Display or H1 per screen. One **primary** button per screen — never two.
- Verification badge on tradie cards is **always visible** — never collapsed, never gated behind a tap.

### Imagery vibe
The system reads as charcoal + signal-orange against bright neutral grey. There is **no decorative photography** in the spec. If photography enters the system later, brief should call for high-contrast worksite photography — overcast Australian light, hi-vis, real tools, real hands. Never stock smiles in hard-hats.

---

## Iconography

The Galvanised spec calls for **outline-style icons, 1.7px stroke, 22px** in nav. No icon font is shipped in the design system pack, so this design system uses **[Lucide](https://lucide.dev)** as the substitute — its 1.5–2px outline weight matches the Galvanised brief almost exactly, and it's loadable from CDN.

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.js"></script>
<script>lucide.createIcons();</script>
```

> ⚠️ **Substitution flagged.** No icon set was bundled with the source pack. Lucide is a stand-in. If JobDun has a custom icon set in production, drop the SVGs into `assets/icons/` and document overrides in this section.

**Iconography rules**
- Outline only. No filled icons except the active bottom-nav tab (action orange fill on icon background tint).
- Status uses **dots and check marks (✓)** rather than icons. Verified is the literal text "✓ Verified" — not a shield icon.
- **No emoji** anywhere in the UI — not in nav, badges, buttons, error toasts, or empty states.
- **No unicode-as-icon** (no ⚡, no ⏰, no 🛠 stand-ins). Use Lucide.
- Icons in the body of cards should be sized to the type beside them — a `text-3` icon at 16px, never standalone-ornamental.

---

## At a glance — what *never* changes
| Rule | Value |
|---|---|
| Touch target | ≥ 48px height |
| Contrast | ≥ WCAG AA 4.5:1 |
| Max transition | 150ms |
| Decorative animation | 0 |
| Verified badge | always visible on tradie cards |
| Urgent colour | `#C73B2E` only — fixed across modes |
| Card radius | ≤ 14px |
| Distance colour | `--c-action` always |
| Screen horizontal padding | 20px always |
| Primary CTAs per screen | 1 max |
| Font family | Barlow + Barlow Condensed only |
