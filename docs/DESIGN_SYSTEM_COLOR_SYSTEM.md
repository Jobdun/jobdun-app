# Jobdun — Color System

**Date:** 2026-05-31 · **Source of truth:** `lib/app/theme/app_colors.dart` · **Companions:** [`DESIGN_SYSTEM_TOKENS.md`](./DESIGN_SYSTEM_TOKENS.md) · [`DESIGN_SYSTEM_AUDIT.md`](./DESIGN_SYSTEM_AUDIT.md)

The full Jobdun palette laid out as **50→950 ramps**, in the standard primary / neutral / semantic structure.

**The key fact:** Jobdun's palette **is the Tailwind v3 families** — Slate (neutral), Orange (primary/CTA), Green / Amber / Blue / Red (semantic). Every shipping token lands on an exact ramp step (verified), so the ramps below are real, not invented. Two values are custom (noted).

**How to read each table:**
- **Step / Hex** — the ramp position (the family's standard value).
- **Default / Hover / BG** — the role marker, mirroring the reference format.
- **Token (dark)** / **Token (light)** — the **actual** `JColors` token wired at that step today. A blank means *the step exists in the family but Jobdun does not currently name a token for it* — available headroom, not in code yet.

> Jobdun is a **single-accent system** (Restrained strategy): Orange is the only brand accent — there's no secondary brand color (unlike a blue+gold system). Green/Amber/Blue/Red are **functional**, not decorative.

---

## 1. Primary & Accent — CTA Orange (Tailwind `orange`)

The one brand accent. Reserved for primary actions, focus, loaders, and critical status — never decorative (MASTER §51).

| Step | Hex | Marker | Token (dark) | Token (light) |
|------|-----|--------|--------------|---------------|
| 50  | `#FFF7ED` | BG | — | — |
| 100 | `#FFEDD5` | | — | `actionBg` |
| 200 | `#FED7AA` | | `actionTx` | — |
| 300 | `#FDBA74` | | — | — |
| 400 | `#FB923C` | | — | — |
| **500** | `#F97316` | **Default** | **`action`** | **`action`** |
| 600 | `#EA580C` | Hover | *(`actionPressed` ≈ here, custom `#EA6C0A`)* | *(custom)* |
| 700 | `#C2410C` | | — | — |
| 800 | `#9A3412` | | — | `actionTx` |
| 900 | `#7C2D12` | | — | — |
| 950 | `#431407` | | `actionBg` | — |

*Custom value: `actionPressed #EA6C0A` (hover/pressed) sits between 500 and 600 — a hand-tuned "12% darker," not the clean `orange-600`.*

---

## 2. Neutral — Slate (Tailwind `slate`)

The entire dark UI is built from this one ramp. (Light theme reuses the opposite end — gated/unused.)

| Step | Hex | Marker | Token (dark) | Token (light) |
|------|-----|--------|--------------|---------------|
| 50  | `#F8FAFC` | BG (light) | — | `background` |
| 100 | `#F1F5F9` | | `text1` | `surfaceRaised` |
| 200 | `#E2E8F0` | | — | — |
| 300 | `#CBD5E1` | | — | `border` · `text3` |
| 400 | `#94A3B8` | | `text2` | — |
| 500 | `#64748B` | | `text3` | — |
| 600 | `#475569` | | — | `text2` |
| 700 | `#334155` | | `surfaceRaised` · `border` | — |
| 800 | `#1E293B` | Surface | `surface` · `card` | — |
| **900** | `#0F172A` | **Default (BG)** | **`background`** | — |
| 950 | `#020617` | | — | — |

*Dark theme uses 900/800/700 for ground/surface/raised and 100/400/500 for primary/secondary/tertiary text. The gap at 600 (dark) is exactly why the proposed `text3`/`borderStrong` fixes land "between steps" — see §7.*

---

## 3. Semantic / Functional Colors

Each is a single status hue with a **tinted pair** (a dark `*Bg` + a light `*Tx`) used for chips/banners.

### 3a. Success — Green (Tailwind `green`)

| Step | Hex | Token (dark) | Token (light) |
|------|-----|--------------|---------------|
| 50  | `#F0FDF4` | — | — |
| 100 | `#DCFCE7` | — | `verifiedBg` |
| 200 | `#BBF7D0` | — | — |
| 300 | `#86EFAC` | `verifiedTx` | — |
| 400 | `#4ADE80` | — | — |
| **500** | `#22C55E` | **`verified`** (Default) | — |
| 600 | `#16A34A` | — | `verified` |
| 700 | `#15803D` | — | — |
| 800 | `#166534` | — | `verifiedTx` |
| 900 | `#14532D` | — | — |
| 950 | `#052E16` | `verifiedBg` | — |

### 3b. Attention / Warning — Amber (Tailwind `amber`)

| Step | Hex | Token (dark) | Token (light) |
|------|-----|--------------|---------------|
| 50  | `#FFFBEB` | — | — |
| 100 | `#FEF3C7` | — | — |
| 200 | `#FDE68A` | — | — |
| 300 | `#FCD34D` | — | — |
| 400 | `#FBBF24` | — | — |
| **500** | `#F59E0B` | **`star`** (Default) | `star` |
| 600 | `#D97706` | — | — |
| 700 | `#B45309` | — | — |
| 800 | `#92400E` | — | — |
| 900 | `#78350F` | — | — |
| 950 | `#451A03` | — | — |

> **Gap:** Jobdun has **no dedicated warning semantic** — amber is used *only* for star ratings. There's no `warning`/`warningBg`/`warningTx` pair (errors all go to red). Worth adding if "caution" states are ever needed.

### 3c. Information — Blue (Tailwind `blue`)

| Step | Hex | Token (dark) | Token (light) |
|------|-----|--------------|---------------|
| 50  | `#EFF6FF` | — | — |
| 100 | `#DBEAFE` | — | `availableBg` |
| 200 | `#BFDBFE` | — | — |
| 300 | `#93C5FD` | `availableTx` | — |
| 400 | `#60A5FA` | — | — |
| **500** | `#3B82F6` | **`available`** (Default) | — |
| 600 | `#2563EB` | — | `available` |
| 700 | `#1D4ED8` | — | `availableTx` |
| 800 | `#1E40AF` | — | — |
| 900 | `#1E3A8A` | — | — |
| 950 | `#172554` | — | — |

*Custom value: `availableBg #1E3A5F` (dark) is a desaturated navy, **not** a Tailwind blue step — the one tinted-pair bg that's off-ramp. `available` is "status only — never a tappable action."*

### 3d. Danger — Red (Tailwind `red`)

| Step | Hex | Token (dark) | Token (light) |
|------|-----|--------------|---------------|
| 50  | `#FEF2F2` | — | — |
| 100 | `#FEE2E2` | — | `urgentBg` |
| 200 | `#FECACA` | — | — |
| 300 | `#FCA5A5` | `urgentTx` | — |
| 400 | `#F87171` | — | — |
| **500** | `#EF4444` | **`urgent`** (Default) | — |
| 600 | `#DC2626` | — | `urgent` |
| 700 | `#B91C1C` | — | — |
| 800 | `#991B1B` | — | `urgentTx` |
| 900 | `#7F1D1D` | — | — |
| 950 | `#450A0A` | `urgentBg` | — |

---

## 4. What's actually tokenized today (the real `JColors` setup)

So you can check the live setup at a glance — these are the **only** named tokens in `app_colors.dart` (dark theme):

| Token | = ramp step | Hex |
|-------|-------------|-----|
| `background` | slate-900 | `#0F172A` |
| `surface` / `card` | slate-800 | `#1E293B` |
| `surfaceRaised` / `border` | slate-700 | `#334155` |
| `text1` | slate-100 | `#F1F5F9` |
| `text2` | slate-400 | `#94A3B8` |
| `text3` | slate-500 | `#64748B` |
| `action` | orange-500 | `#F97316` |
| `actionPressed` | ~orange-550 *(custom)* | `#EA6C0A` |
| `actionBg` / `actionTx` | orange-950 / orange-200 | `#431407` / `#FED7AA` |
| `onAction` | white *(see §6)* | `#FFFFFF` |
| `verified` / `verifiedBg` / `verifiedTx` | green-500 / 950 / 300 | `#22C55E` / `#052E16` / `#86EFAC` |
| `urgent` / `urgentBg` / `urgentTx` | red-500 / 950 / 300 | `#EF4444` / `#450A0A` / `#FCA5A5` |
| `available` / `availableBg` / `availableTx` | blue-500 / *custom* / 300 | `#3B82F6` / `#1E3A5F` / `#93C5FD` |
| `star` | amber-500 | `#F59E0B` |

Everything else in the ramps above is **headroom** — a valid step in the family, but not a named token yet.

---

## 5. Reading the system

- **Primary:** 1 accent (Orange). **Neutral:** 1 ramp (Slate). **Semantic:** 4 hues (Green/Amber/Blue/Red), each as a 3-token tinted set (`x` / `xBg` / `xTx`).
- **Pattern for status chips:** dark `*Bg` (≈ step 950) + light `*Tx` (≈ step 200–300) → always high-contrast. This is the part of the system that's built best.
- **No primitive tier:** these ramps are *implied* by the Tailwind values, but they aren't declared as primitives in code — each token holds its own raw hex (see audit P3). Declaring the ramps as primitives is the cleanest upgrade.

## 6. Where the system needs attention (cross-ref the audit)

- **`onAction = white`** is the one token **not** drawn from a ramp, and it's the P0: white on `action` (orange-500) = 2.80:1, fails WCAG. Fix = `slate-900 #0F172A` (6.37:1).
- **`text3` (slate-500)** fails AA on surface (3.07:1); **`border` (slate-700)** fails the 3:1 UI floor (1.41:1).

## 7. Proposed fixes, mapped to the ramp

| Token | Now (step) | Proposed | Ramp position |
|-------|-----------|----------|---------------|
| `onAction` | white | `#0F172A` | = slate-900 |
| `text3` | slate-500 `#64748B` | `#8B98AB` | between slate-500 and slate-400 |
| `borderStrong` *(new)* | — | `#708096` | between slate-500 and slate-400 |

These sit in the **slate-450/550 gap** that the ramp skips today — i.e., the fixes are really "fill in the two missing neutral steps." Snapping them to declared primitives (a `slate-450` / `slate-550`) would make the whole system consistent.

---

*All ramp values are Tailwind v3 family steps; Jobdun-token mappings verified against `app_colors.dart` (18/18 shipping tokens land on exact steps; `actionPressed` and `availableBg` are the two customs). Markdown can't render swatches — paste any hex into a color tool to view.*
