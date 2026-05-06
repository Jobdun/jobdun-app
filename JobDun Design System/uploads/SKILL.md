---
name: galvanised
description: Apply the Galvanised design language when building any UI for the tradie marketplace app. Triggers on: "build a screen", "make a component", "design the [screen name]", "create the UI for", or any request to produce app UI. Covers React Native components, HTML mockups, and design specs. Always read this file before writing a single line of UI code.
---

# GALVANISED — Design Language
**Australian Tradie Marketplace · Android + iOS · v1.0**

Galvanised is a professional tool aesthetic. Not a consumer app. Not a startup. A precision instrument that builders and tradies reach for the same way they reach for a quality tape measure.

**Foundation colour:** `#252D34` — Galvanised steel framing. Load-bearing. Unapologetic.  
**Action colour:** `#CC4A10` — Signal orange. Industrial. Impossible to miss.

---

## 1. Core Principles

Before writing any code, commit to these five in order:

1. **Direct** — One clear action per screen. No metaphors. No onboarding confetti.
2. **Trustworthy** — Verification is architecture. Licence + insurance + ID status must be visible on every tradie card without tapping.
3. **Field-ready** — Bright sunlight. Dirty gloves. One hand. Every tap target, contrast ratio, and font size is designed for a building site, not a desk.
4. **Efficient** — A builder posting a job is losing money every extra second. Speed is respect.
5. **Earned** — Premium comes from precision. No gradients. No decorative animation. No gimmicks.

---

## 2. Color Tokens

### Primitives (never change)
```
--c-foundation:    #252D34   /* Galvanised steel — nav, avatars, primary btn light */
--c-action:        #CC4A10   /* Signal orange — CTAs, distance labels, active nav  */
--c-action-bg:     #FAE4D8   /* Action tint — badge bg, chip bg                   */
--c-action-tx:     #7A2808   /* Action text on tint bg                             */
--c-verified:      #0D8A5A   /* Emerald — licensed, confirmed, available           */
--c-verified-bg:   #E6F7F1
--c-verified-tx:   #0D6644
--c-urgent:        #C73B2E   /* FIXED — never changes between modes or schemes     */
--c-urgent-bg:     #FDECEA
--c-urgent-tx:     #A32E24
--c-available:     #1A7AD4   /* FIXED — never changes between modes or schemes     */
--c-available-bg:  #E6F3FF
--c-available-tx:  #1254A0
```

### Light Mode Semantic Tokens
```
--c-bg:        #F4F6F8   /* App background                  */
--c-surf:      #EAEEF2   /* Section bg, inputs, chips        */
--c-card:      #FFFFFF   /* Card surfaces                    */
--c-border:    #D4D9DF   /* All borders and dividers         */
--c-text-1:    #252D34   /* Primary text — names, headings   */
--c-text-2:    #5A6872   /* Secondary — trade type, meta     */
--c-text-3:    #A0ACB8   /* Tertiary — captions, placeholders*/
--c-btn-pri:   #252D34   /* Primary button bg                */
--c-btn-pri-t: #FFFFFF   /* Primary button text              */
```

### Dark Mode Semantic Tokens
```
--c-bg:        #0E1216
--c-surf:      #1C2428
--c-card:      #252D34
--c-border:    #303A44
--c-text-1:    #E8ECF2
--c-text-2:    #7A8898
--c-text-3:    #505C68
--c-btn-pri:   #CC4A10   /* Primary button FLIPS to action in dark */
--c-btn-pri-t: #FFFFFF
```

**Rule:** `--c-urgent` and `--c-available` NEVER change in dark mode. They are semantic signals, not brand colours.

---

## 3. Typography

**Font family:** Barlow Condensed (display, headings, numbers) + Barlow (body, labels, UI)  
**Import:** `https://cdn.jsdelivr.net/npm/@fontsource/barlow@5.0.17/index.css`  
**Import:** `https://cdn.jsdelivr.net/npm/@fontsource/barlow-condensed@5.0.17/index.css`

Never use: Inter, Roboto, SF Pro, system-ui, Arial, or any generic sans-serif as the primary font.

### Type Scale
| Token       | Family              | Size | Weight | Use                              |
|-------------|---------------------|------|--------|----------------------------------|
| Display     | Barlow Condensed    | 40px | 700    | Screen titles, hero headings     |
| H1          | Barlow Condensed    | 28px | 700    | Section headers in nav           |
| H2          | Barlow              | 20px | 600    | Card group labels                |
| H3          | Barlow              | 16px | 600    | Card name, in-card headings      |
| Body        | Barlow              | 15px | 400    | Job descriptions, profile bios   |
| Label       | Barlow              | 13px | 400    | Trade type, job count            |
| Caption     | Barlow              | 11px | 500    | Timestamps, meta, distance       |
| Stat        | Barlow Condensed    | 20px | 700    | Ratings, prices, earnings        |

### Typography Rules
- Letter-spacing on Condensed headings: `0.02em`
- Letter-spacing on eyebrow labels: `0.12em` + `text-transform: uppercase`
- Line-height on display: `1.0`
- Line-height on body: `1.7`
- Ratings and prices always use Barlow Condensed 700 — never Barlow Regular

---

## 4. Spacing — 4pt Grid

All spacing is a multiple of 4px.

| Token  | Value | Use                                          |
|--------|-------|----------------------------------------------|
| `xs`   | 4px   | Icon gap, internal badge padding             |
| `sm`   | 8px   | Badge row gaps, tight component spacing      |
| `md`   | 12px  | Icon-to-label gap, card internal row spacing |
| `lg`   | 16px  | Card padding, list item gap                  |
| `xl`   | 20px  | Screen horizontal padding (always 20px)      |
| `2xl`  | 32px  | Between card groups, major section spacing   |
| `3xl`  | 48px  | Minimum touch target height                  |

**Screen horizontal padding is always 20px. Never 16px, never 24px.**

---

## 5. Touch Targets & Accessibility

- Minimum touch target: **48px height** — no exceptions, not even for icon-only buttons
- Minimum contrast: **WCAG AA 4.5:1** on all text — test against outdoor sunlight, not a dimmed monitor
- Tap target padding: every interactive element must have at least 12px padding on all sides even if the visual is smaller
- Maximum transition duration: **150ms** — no bounce, no spring, no overshoot

---

## 6. Component Patterns

### 6.1 Tradie Card (the core component)
The most important component in the system. Every design decision flows through it.

**Structure (top to bottom):**
1. Avatar (48×48, 10px radius) + Name row (name left, rating right)
2. Trade type + job count (secondary text)
3. Divider (1px, `--c-border`)
4. Footer row: availability dot + status + separator + verified badge + distance (pushed right, action colour)

**Rules:**
- Rating number: Barlow Condensed 700, 18px, `--c-text-1`
- Distance: always `--c-action` colour — this is non-negotiable
- `✓ Verified` badge: always visible, never collapsed, `--c-verified-tx` colour
- Offline cards: `opacity: 0.45`, no verified strip, no distance highlight
- Card border-radius: **14px** maximum — never 16, never 20, never pill
- Card background: `--c-card`

```
┌─────────────────────────────────┐
│  [AVI]  Name              4.9/5 │
│         Electrician · 142 jobs  │
│ ─────────────────────────────── │
│  ● Available  ·  ✓ Verified  3.2km │
└─────────────────────────────────┘
```

### 6.2 Job Card
Used in the builder's job feed and urgent job alerts.

**Structure:**
- Top: 3px urgent bar (full width, `--c-urgent`) — only on urgent jobs
- Urgency badge
- Job title (Barlow Condensed 700, 20px)
- Description (2 lines max, truncate)
- Meta row: Rate · Start date · Distance (action colour)

**Rules:**
- Urgent bar spans full card width, sits flush with border-radius
- Non-urgent jobs have no coloured bar — no faking urgency

### 6.3 Buttons

| Variant  | Bg              | Text    | Use                          |
|----------|-----------------|---------|------------------------------|
| Primary  | `--c-btn-pri`   | `#FFFFFF` | Most important action per screen |
| Action   | `--c-action`    | `#FFFFFF` | Accept, confirm, send        |
| Outline  | transparent     | `--c-text-1` + border | Secondary nav action |
| Ghost    | `--c-card`      | `--c-text-2` + border | Dismiss, cancel, skip |
| Danger   | `--c-urgent-bg` | `--c-urgent-tx` + urgent border | Destructive / report |

- Height: **48px** minimum
- Padding: 0 22px
- Border-radius: **9px**
- Font: Barlow 600, 14px, letter-spacing 0.01em
- Max one Primary button per screen

### 6.4 Status Badges

| Badge              | Bg                | Text               | Dot               |
|--------------------|-------------------|--------------------|-------------------|
| Licensed & Verified| `--c-verified-bg` | `--c-verified-tx`  | `--c-verified`    |
| Available Now      | `--c-available-bg`| `--c-available-tx` | `--c-available`   |
| Urgent             | `--c-urgent-bg`   | `--c-urgent-tx`    | `--c-urgent`      |
| Pending Review     | `--c-action-bg`   | `--c-action-tx`    | `--c-action`      |
| Tradie Pro         | `--c-foundation`  | `#FFFFFF`          | none              |

- Height: 28px
- Padding: 0 11px
- Border-radius: 5px
- Font: Barlow 600, 11px, letter-spacing 0.02em
- Dot: 6×6px circle, 3px left of label

### 6.5 Filter Chips

- Active: bg `--c-foundation`, text `#FFFFFF`
- Inactive: bg `--c-surf`, text `--c-text-2`, border `--c-border`
- Height: 30px, padding 0 14px, border-radius 8px
- Font: Barlow 600, 12px

### 6.6 Avatar Initials

- Size: 44–50px depending on context
- Border-radius: 10px (never circle — this isn't a social app)
- Foundation colour as default. Blue variants for secondary profiles.
- Font: Barlow Condensed 700, ~14px, letter-spacing 0.04em

### 6.7 Bottom Navigation

- 4 tabs: Home, Jobs, Chat, Profile
- Active tab: icon in `--c-action`, label in `--c-action`, icon uses action-bg fill tint
- Inactive tabs: icon and label in `--c-text-3`
- Background: `--c-surf`
- Top border: 1px `--c-border`
- Height: 62px with 10px bottom padding (for home indicator)
- Tab icons: outline style, 1.7px stroke, 22px

---

## 7. Screen Layout Rules

### Every screen must have:
1. A status bar (9:41, signal, battery — respects system dark/light)
2. A clear heading hierarchy — one Display or H1, then H2 for sections
3. A single primary action (button or FAB) — not two
4. Consistent 20px horizontal padding

### Header pattern (Builder home)
```
[Eyebrow: role label in --c-text-2]
[Display heading: Barlow Condensed 700]
[Location: ↓ City, State — in --c-action colour, 11px Barlow 600]
                                    [Notif icon button: 34×34px]
```

### Search bar
- Height: 40px
- Background: `--c-surf`
- Border: 1px `--c-border`
- Border-radius: 10px
- Left icon: magnifier in `--c-text-3`, 16px
- Placeholder: Barlow 400, 12px, `--c-text-2`

---

## 8. Animation Rules

| Property            | Value     | Notes                              |
|---------------------|-----------|------------------------------------|
| Max transition      | 150ms     | Hard ceiling — no exceptions       |
| Easing              | ease      | No spring, no bounce, no overshoot |
| Decorative animation| NONE      | Zero confetti, zero Lottie players |
| Skeleton loaders    | allowed   | Simple opacity pulse, 1s, ease     |
| Page transitions    | fade only | 100ms fade between screens         |

---

## 9. Dark Mode Implementation

### React Native (NativeWind / StyleSheet)
Use `useColorScheme()` to switch token sets. Define a `useTheme()` hook that returns the full token object.

```ts
const tokens = {
  light: {
    bg: '#F4F6F8', surf: '#EAEEF2', card: '#FFFFFF',
    border: '#D4D9DF', text1: '#252D34', text2: '#5A6872',
    text3: '#A0ACB8', btnPri: '#252D34', btnPriText: '#FFFFFF',
    // primitives
    foundation: '#252D34', action: '#CC4A10', actionBg: '#FAE4D8',
    actionTx: '#7A2808', verified: '#0D8A5A', verifiedBg: '#E6F7F1',
    verifiedTx: '#0D6644', urgent: '#C73B2E', urgentBg: '#FDECEA',
    urgentTx: '#A32E24', available: '#1A7AD4', availableBg: '#E6F3FF',
    availableTx: '#1254A0',
  },
  dark: {
    bg: '#0E1216', surf: '#1C2428', card: '#252D34',
    border: '#303A44', text1: '#E8ECF2', text2: '#7A8898',
    text3: '#505C68', btnPri: '#CC4A10', btnPriText: '#FFFFFF',
    // primitives — fixed, same as light
    foundation: '#252D34', action: '#CC4A10', actionBg: '#FAE4D8',
    actionTx: '#7A2808', verified: '#0D8A5A', verifiedBg: '#E6F7F1',
    verifiedTx: '#0D6644', urgent: '#C73B2E', urgentBg: '#FDECEA',
    urgentTx: '#A32E24', available: '#1A7AD4', availableBg: '#E6F3FF',
    availableTx: '#1254A0',
  }
}
```

### Key dark mode behaviour
- Primary button flips from `#252D34` (light) to `#CC4A10` (dark) — foundation navy is invisible on dark bg
- Card surfaces step UP: bg → surf → card creates visible elevation without shadows
- Urgent and Available never change — they are semantic, not structural

---

## 10. What Never Changes

These rules apply regardless of screen, feature, or developer preference:

| Rule | Value |
|------|-------|
| Touch targets | ≥ 48px height |
| Contrast ratio | ≥ 4.5:1 WCAG AA |
| Max transition | 150ms |
| Decorative animation | 0 |
| Verified badge visibility | Always visible on tradie cards |
| Urgent colour | `#C73B2E` only |
| Card border-radius | ≤ 14px |
| Distance colour | `--c-action` always |
| Screen horizontal padding | 20px always |
| Primary CTAs per screen | 1 maximum |
| Font family | Barlow + Barlow Condensed only |

---

## 11. What to Avoid

- **Rounded pill cards** — 14px max, not 24px, not pill
- **Decorative gradients** — no mesh gradients, no glow effects
- **Emoji in UI** — never in navigation, badges, or buttons
- **Exclamation marks in copy** — refer to VOICE.md
- **Multiple primary buttons** — one per screen, always
- **Hiding the verified badge** — never collapse, never behind a tap
- **Icon-only buttons under 48px** — even small icons need 48px tap area
- **Changing urgent red** — it's a semantic signal, not a brand choice
- **Inter, Roboto, or system fonts** — Barlow family only
- **Shadow-heavy cards** — use border + bg elevation instead of box-shadow

---

## 12. File References

| File              | Purpose                                          |
|-------------------|--------------------------------------------------|
| `SKILL.md`        | This file — read first for every UI task         |
| `tokens.css`      | Complete CSS custom properties, copy-paste ready |
| `tokens.rn.ts`    | React Native token object, light + dark          |
| `components.md`   | Annotated component patterns with code examples  |
| `voice.md`        | Copy guidelines, do/don't, brand vocabulary      |
| `screens.md`      | Screen inventory, layout rules per screen type   |
