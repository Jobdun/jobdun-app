# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Jobdun
**Updated:** 2026-05-07
**Audience:** Construction/trades workers and builders — not a SaaS startup, not a consumer lifestyle app.
**Design Character:** Aggressive. Every UI decision asserts authority. Nothing apologizes for itself.

---

## Design Philosophy

This is a platform for people who work with their hands. The UI should feel like it was built for them — not for a VC pitch deck. Heavy, deliberate, confident. No softness. No hedging.

**What "aggressive" means in practice:**
1. **Visual weight** — Thick buttons, dense layouts, bold type. Nothing thin or airy.
2. **Personality over convention** — Break safe defaults intentionally. This app has a face.
3. **No hedging** — Every button is filled. Every label is declarative. "LOG IN" not "Continue."
4. **Respect the user** — No handholding microcopy. No "Yay!" empty states. No friendly illustrations.

---

## Color Palette

| Role | Hex | Flutter | Usage |
|------|-----|---------|-------|
| Background | `#0F172A` | `Color(0xFF0F172A)` | App background — dark slate, NOT white |
| Surface | `#1E293B` | `Color(0xFF1E293B)` | Cards, bottom sheets, input fills |
| Surface Raised | `#334155` | `Color(0xFF334155)` | Elevated cards, selected states |
| CTA / Accent | `#F97316` | `Color(0xFFF97316)` | Primary actions, safety orange — dominant |
| CTA Pressed | `#EA6C0A` | `Color(0xFFEA6C0A)` | Pressed state for CTA |
| Primary Text | `#F1F5F9` | `Color(0xFFF1F5F9)` | Body text on dark |
| Secondary Text | `#94A3B8` | `Color(0xFF94A3B8)` | Labels, hints, metadata |
| Border | `#334155` | `Color(0xFF334155)` | Input borders, dividers |
| Error | `#EF4444` | `Color(0xFFEF4444)` | Errors only — never decorative |
| Success | `#22C55E` | `Color(0xFF22C55E)` | Confirmations only |

**Color Rules:**
- Background is ALWAYS `#0F172A`. Never use white (`#FFFFFF`) or light gray (`#F8FAFC`) as a screen background.
- Orange `#F97316` is reserved for CTAs and critical status indicators only — do not use it decoratively.
- No gradients. No blurs on backgrounds. No frosted glass. Flat.

---

## Typography

**Display / Headings:** Oswald — condensed, bold, industrial authority
**Body / UI text:** Open Sans — clean, readable, professional
**Configure in `AppTheme` only — never call `GoogleFonts.*` per-widget.**

| Role | Font | Weight | Size | Letter Spacing | Usage |
|------|------|--------|------|----------------|-------|
| Display | Oswald | 700 | 40sp+ | 1.2 | Hero headlines, splash, brand name |
| Heading 1 | Oswald | 700 | 32sp | 0.8 | Screen titles |
| Heading 2 | Oswald | 600 | 24sp | 0.5 | Section headers |
| Heading 3 | Oswald | 600 | 20sp | 0.3 | Sub-section headers |
| Title | Oswald | 600 | 16sp | 0 | Card headers |
| Body | Open Sans | 400–600 | 13–15sp | 0 | Body text, descriptions |
| Button | Oswald | 700 | 14sp | 1.5 | ALL CAPS button text |
| Label | Open Sans | 600 | 12sp | 0.5 | Tags, badges, chips |
| Caption | Open Sans | 500 | 11sp | 0 | Timestamps, secondary metadata |

**Typography Rules:**
- Headings use Oswald Bold — condensed weight does the visual work, no italic needed.
- Button text is Oswald w700 uppercase — heavy and directional.
- Body text is Open Sans — readable contrast to the condensed headings.
- No thin fonts anywhere. Minimum weight 400 for any visible text.

---

## Spacing

Use `Gap(n)` always. Never `SizedBox(height/width: n)`.
Use `flutter_screenutil` extensions (`.w`, `.h`, `.sp`, `.r`) — never raw pixel values.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4 | Icon internal gaps |
| sm | 8 | Tight inline spacing |
| md | 16 | Standard padding |
| lg | 24 | Section padding |
| xl | 32 | Large section gaps |
| 2xl | 48 | Screen-level margins |

---

## Component Specs (Flutter)

### Buttons

**Rule: No ghost buttons. No outline-only buttons. Every button is filled.**

```dart
// Primary CTA — filled orange, heavy
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFF97316),
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 56.h),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
    elevation: 0,
  ),
  child: Text('LOG IN', style: TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  )),
)

// Secondary action — filled slate, NOT ghost
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF334155),
    foregroundColor: Color(0xFFF1F5F9),
    minimumSize: Size(double.infinity, 56.h),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
    elevation: 0,
  ),
  child: Text('CREATE ACCOUNT', ...),
)
```

**Button text vocabulary:**
- "LOG IN" — not "Sign in" or "Continue"
- "CREATE ACCOUNT" — not "Sign up" or "Get started"
- "APPLY NOW" — not "Apply" or "Submit application"
- "POST JOB" — not "Create" or "Add job"
- "CONFIRM" — not "OK" or "Yes, continue"

### Cards

```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFF1E293B),   // Surface, not white
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(color: Color(0xFF334155), width: 1),
  ),
  padding: EdgeInsets.all(16.w),
)
```

No card shadows. Border instead of shadow for edge definition.

### Input Fields

```dart
TextFormField(
  style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 14.sp),
  decoration: InputDecoration(
    filled: true,
    fillColor: Color(0xFF1E293B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6.r),
      borderSide: BorderSide(color: Color(0xFF334155)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6.r),
      borderSide: BorderSide(color: Color(0xFFF97316), width: 2),
    ),
    hintStyle: TextStyle(color: Color(0xFF94A3B8)),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
  ),
)
```

No light-colored input backgrounds. Inputs are dark surface fills with bright focus borders.

### Status Chips / Tags

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
  decoration: BoxDecoration(
    color: Color(0xFF334155),
    borderRadius: BorderRadius.circular(4.r),
  ),
  child: Text('OPEN', style: TextStyle(
    color: Color(0xFF22C55E),
    fontSize: 11.sp,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  )),
)
```

Status chips use all-caps labels. Colors: Open=green, In Progress=orange, Closed=secondary text.

### Bottom Sheets

Use `modal_bottom_sheet` (not Flutter's built-in). Background is `#1E293B`, handle bar in `#334155`.

---

## Icons

Use `Iconsax.*` by default. Fall back to `Icons.*` only when no Iconsax equivalent exists.
Icon color: `#94A3B8` default, `#F97316` for active/selected, `#F1F5F9` for primary actions.
Icon size: 20–24dp for navigation, 16–20dp for inline, 32–40dp for feature icons.

---

## Animations

- Transitions: 150–200ms ease. No longer.
- List items: `flutter_staggered_animations` — `AnimationLimiter + AnimationConfiguration`.
- Micro-interactions: `flutter_animate` — `.fadeIn()`, `.slideY()`, `.scale()`.
- Loading: `skeletonizer` wrapping real widgets. Dark skeleton base (`#1E293B`), shimmer in `#334155`.
- Empty states: Lottie animation + bold headline + single filled CTA. Never blank. Never text-only.
- No bounce animations. No spring physics. Construction workers don't need playful.

---

## Navigation Bar

Bottom nav background: `#0F172A` (same as background — no separation line needed).
Selected icon: `#F97316`. Unselected: `#64748B`. No labels on nav items.

---

## Anti-Patterns (Do NOT Use)

- ❌ White or light gray (`#F8FAFC`) as screen background — signals "safe SaaS"
- ❌ Ghost/outline-only buttons — signals hedging
- ❌ Title case or sentence case button text — use ALL CAPS
- ❌ Soft/rounded border radius above 12 — keep it sharp (4–8)
- ❌ Friendly microcopy ("You're all set!", "Yay!", "Almost there!")
- ❌ Gradients — flat only
- ❌ Heavy drop shadows — use borders for card definition
- ❌ Google/Apple SSO as the dominant auth option — Jobdun owns the auth experience
- ❌ Thin fonts (weight 300 or 400 for headings)
- ❌ Emojis as icons
- ❌ Skeleton/loading states on white — match background color

---

## Pre-Delivery Checklist

Before delivering any UI code, verify:

- [ ] Background is `#0F172A`, never white
- [ ] All buttons are filled (no ghost buttons)
- [ ] Button text is uppercase + bold (FontWeight.w700+)
- [ ] All text uses Barlow / Barlow Condensed via AppTheme (no per-widget GoogleFonts calls)
- [ ] Gap(n) used for all spacing, never SizedBox
- [ ] All sizes use .w / .h / .sp / .r from flutter_screenutil
- [ ] Icons from Iconsax (with Icons.* fallback only)
- [ ] Empty states have Lottie + headline + CTA
- [ ] Loading uses skeletonizer on dark surface, not white
- [ ] No gradients, no blur effects, no heavy shadows
- [ ] Transitions 150–200ms, no spring/bounce
- [ ] Focus states visible (orange border on input focus)
