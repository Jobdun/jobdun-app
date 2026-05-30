# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Jobdun
**Updated:** 2026-05-12
**Audience:** Construction/trades workers and builders — not a SaaS startup, not a consumer lifestyle app.
**Design Character:** Aggressive. Every UI decision asserts authority. Nothing apologizes for itself.

---

## Sources of Truth

When docs disagree with code, **code wins**. Tokens live in `lib/app/theme/` (`app_colors.dart`, `app_theme.dart`). This file describes intent; the tokens enforce it.

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
| Error | `#EF4444` | `Color(0xFFEF4444)` | Errors / destructive only — never decorative |
| Success | `#22C55E` | `Color(0xFF22C55E)` | Confirmations only |
| Warning | `#F59E0B` | `Color(0xFFF59E0B)` | Caution / pending / in-review / expiring — `c.warning` |

> The table is the summary. The verified source of truth (with tinted bg/text pairs, `onAction`, `borderStrong`, `available`, `star`) is `lib/app/theme/app_colors.dart`; every dark pair is enforced by `test/colors_contrast_test.dart`.

**Color Rules:**
- Background is ALWAYS `#0F172A`. Never use white (`#FFFFFF`) or light gray (`#F8FAFC`) as a screen background.
- Orange `#F97316` is reserved for CTAs and critical status indicators only — do not use it decoratively, and do not use it for a *status* (a status is not an action).
- **Caution ≠ error.** Pending / awaiting / in-review / expiring states use **Warning amber `#F59E0B`** (`c.warning` + `c.warningBg`/`c.warningTx`), NOT Error red (`c.urgent`) and NOT the brand orange (`c.action`).
- **`surfaceRaised` (`#334155`) carries primary text (`text1`) only.** Secondary/tertiary text (`text2`/`text3`) and interactive borders (`borderStrong`) fall below WCAG AA on it (4.04 / 3.54 / 2.57). Put muted text and input controls on `background` or `surface`.
- Foreground on the orange CTA is **dark** (`onAction` `#0F172A`, 6.37:1) — white-on-orange is 2.80:1 and fails. Likewise dark-on-orange for any filled orange tile/icon.
- **Status chips / tags use the semantic `*Bg`/`*Tx` pairs** (`warningBg`/`warningTx`, etc.; neutral terminal states = `surfaceRaised` + `text1`). NEVER `colour.withValues(alpha: …)` + same-colour text — it lands below AA (grey chips ≈ 2:1).
- **Feature/admin widgets read colour via `context.c`** (the JColors tokens), never `Theme.of(context).colorScheme` directly. The `ColorScheme` themes stock Material widgets; your code uses the tokens. (Enforced by `validate.sh`.)
- The Material `ColorScheme` is **single-accent**: `secondary`/`tertiary` map to the brand orange. Don't repurpose them for a distinct colour — add a token instead.
- No gradients. No blurs on backgrounds. No frosted glass. Flat.

---

## Accessibility (non-negotiable)

WCAG 2.2 AA is a hard requirement, enforced by `test/colors_contrast_test.dart` (both themes). When this doc and the code disagree, code wins (see *Sources of Truth*).

- **Contrast:** body/label text ≥ 4.5:1; large text (≥ 24px, or ≥ 18.66px bold) and UI components / icons / borders ≥ 3:1. Placeholders are content — 4.5:1 too.
- **Never colour alone** to convey state — pair every status colour with an icon or text (the application card backs its chip with a coloured status strip).
- **Touch targets ≥ 48dp** — floored globally in `AppTheme` (`MaterialTapTargetSize.padded` + `minimumSize: 48×48` on every button theme).
- **Dynamic Type:** honour the OS text scale, clamped 0.9–1.3 in `MaterialApp.builder`; fixed heights must grow with text.
- **Reduced motion:** every entrance/animation needs a `MediaQuery.disableAnimations` branch (the house `JStaggeredList` already does).
- **New colour token?** Add it to `JColors` + `toMap()`, then give it a guard pair — the coverage test fails if a token ships unguarded.

---

## Typography

**Display / Headings:** Oswald — condensed, bold, industrial authority
**Body / UI text:** Open Sans — clean, readable, professional
**Configure in `AppTheme` only — never call `GoogleFonts.*` per-widget.**

Scale ≈ 1.2 ("minor third"); body anchored at **16** (platform baseline). Distinct sizes
**40 / 32 / 26 / 22 / 18 / 16 / 14 / 12 / 11** — the old 15/14/13 1-px cluster is gone.
Sizes are **fixed logical px** — never `.sp` on `fontSize` (`.sp` scales by screen width and
ignores the OS text-size setting). The OS scaler is clamped to 0.9–1.3 in `MaterialApp.builder`.

| Role (M3) | Font | Weight | Size | Letter Spacing | Line-height | Usage |
|-----------|------|--------|------|----------------|-------------|-------|
| displayLarge   | Oswald    | 700 | 40 | 0    | 1.10 | Hero / splash |
| headlineLarge  | Oswald    | 700 | 32 | 0    | 1.15 | Screen titles |
| headlineMedium | Oswald    | 600 | 26 | 0.15 | 1.20 | Section titles |
| headlineSmall  | Oswald    | 600 | 22 | 0.15 | 1.25 | Sub-sections |
| titleLarge     | Oswald    | 600 | 18 | 0.15 | 1.30 | Card / section headers |
| titleMedium    | Open Sans | 600 | 16 | 0    | 1.50 | Emphasised body |
| titleSmall     | Open Sans | 600 | 14 | 0    | 1.40 | Small emphasised |
| bodyLarge      | Open Sans | 400 | 16 | 0    | 1.50 | Primary body |
| bodyMedium     | Open Sans | 400 | 14 | 0    | 1.50 | Secondary body (most-used) |
| bodySmall      | Open Sans | 500 | 12 | 0.1  | 1.40 | Caption / metadata (floor) |
| labelLarge     | Oswald    | 700 | 14 | 1.2  | 1.10 | Buttons — ALL CAPS |
| labelMedium    | Open Sans | 600 | 12 | 0.4  | 1.20 | Tags / chips |
| labelSmall     | Open Sans | 600 | 11 | 0.6  | 1.20 | Eyebrows |

Wordmark only (NOT a scale role): Oswald 700 · 40 · tracking **3.0** · `AppTypography.brandDisplay()`.

**Typography Rules:**
- Headings use Oswald (condensed weight does the visual work, no italic needed); body is Open Sans.
- Button text is Oswald w700 uppercase — apply CAPS via a widget transform, not by typing caps into strings.
- Tracking is neutral on display/headings, positive only on small caps/labels; the wordmark's wide 3.0 is deliberate brand.
- Pay rates, counts, ratings use `AppTypography.numeric()` (tabular figures) so digits don't jitter.
- No thin fonts anywhere. Minimum weight 400 for any visible text. Type floor is 11 (labels) / 12 (caption body).

> **Scale decision (2026-05-31):** supersedes the older 40/32/24/20/16 + 13–15 body ramp.
> Preserves the just-landed legibility floors (bodySmall 12, labelSmall 11) and the pending
> CTA-contrast fix (`onAction` → #0F172A). Proven on `/design-preview`; global theme migration
> (`app_theme.dart` `textTheme`) follows sign-off. Font **bundling** (kill runtime `google_fonts`)
> is a separate tracked migration — does not block the visual scale.

---

## Spacing

Use `Gap(n)` always. Never `SizedBox(height/width: n)`.
Use `flutter_screenutil` extensions (`.w`, `.h`, `.sp`, `.r`) — never raw pixel values.

| Token | Value | Usage |
|-------|-------|-------|
| xs  | 4  | Icon internal gaps, tight visual links |
| sm  | 8  | Tight inline spacing between related items |
| md  | 12 | Compact padding (chips, dense rows, inline groups) |
| lg  | 16 | Standard padding / card inset / list-row inset |
| xl  | 24 | Section padding, screen horizontal margins |
| 2xl | 32 | Large section gaps, hero-to-content spacing |
| 3xl | 48 | Screen-level margins, top-of-page rhythm |

> **Scale decision (2026-05-31):** moved to a denser 4 / 8 / **12** / 16 / 24 / 32 / 48
> rhythm. `12` is new (was absent); `md`→12 and `lg`→16 shift the workhorse paddings
> one step tighter to match Jobdun's "heavy, dense, no softness" character. This is the
> rulebook decision — the global `AppSpacing` migration (324 call sites) lands after the
> `/design-preview` sign-off; until then the new values are exercised in the preview only.

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

Use `AppIcons.*` from `lib/core/theme/app_icons.dart` (backed by `phosphor_flutter`). Bold weight = default/outline/inactive; Fill weight = active/selected and critical alerts. Nav pairs are records with `.outline` + `.filled` members. Feature code must NOT import `phosphor_flutter` or reference `PhosphorIconsBold.*` / `PhosphorIconsFill.*` directly — the catalogue is the single point of contact. Fall back to `Icons.*` only when no AppIcons entry exists (and add the entry next time you reach for it).
Icon color: `#94A3B8` default, `#F97316` for active/selected, `#F1F5F9` for primary actions.
Icon size: 20–24dp for navigation, 16–20dp for inline, 32–40dp for feature icons.

---

## Animations

- Transitions: 150–200ms ease. No longer.
- List items: `flutter_staggered_animations` — `AnimationLimiter + AnimationConfiguration`.
- Micro-interactions: `flutter_animate` — `.fadeIn()`, `.slideY()`, `.scale()`.
- Loading: `JSkeletonList` (`lib/core/design/widgets/j_skeleton_list.dart`) — wraps `skeletonizer` with the brand-tokened shimmer (base `c.surface`, highlight `c.surfaceRaised`, 1200ms pulse). Never raw `CircularProgressIndicator`/`LinearProgressIndicator` for list or page-body loading; spinners stay for overlay/inline progress only.
- List entry motion: `JStaggeredList` / `JStaggeredSliverList` — 200ms fade-slide per item. Respects `MediaQuery.disableAnimations`. Never call `AnimationLimiter`/`AnimationConfiguration` directly in feature code.
- Progress bars: `LinearPercentIndicator`/`CircularPercentIndicator` from `percent_indicator` for real percentages. Never wrap `LinearProgressIndicator` for that purpose.
- Bottom sheets: `showJSheet` (`lib/core/design/widgets/j_bottom_sheet.dart`). Never call `showModalBottomSheet` directly — Flutter's built-in lacks iOS drag-to-dismiss physics.
- Swipe actions: `flutter_slidable` with `HapticFeedback.lightImpact()` inside every `SlidableAction.onPressed`.
- Image uploads: route every `image_picker` call through `ImageUploadService.pickCropCompress` (`lib/core/services/image_upload_service.dart`) — pick the right `ImageAspect` (`square`/`portfolio`/`free`).
- Image viewers: `photo_view` / `PhotoViewGallery.builder` for tap-to-enlarge surfaces; wrap the thumb in a `Hero(tag: '<feature>:<id>')`.
- Long lists (>50 rows): `infinite_scroll_pagination`'s `PagedListView` with a controller-owned `PagingController`, page size 20, first-page `JSkeletonList` indicator, empty-state CTA, tap-to-retry error, and `RefreshIndicator` wrap.
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
- [ ] All text uses Oswald / Open Sans via AppTheme (no per-widget GoogleFonts calls)
- [ ] Gap(n) used for all spacing, never SizedBox
- [ ] All sizes use .w / .h / .sp / .r from flutter_screenutil
- [ ] Icons from `AppIcons.*` (no direct `phosphor_flutter` imports; `Icons.*` fallback only)
- [ ] Empty states have Lottie + headline + CTA
- [ ] Loading uses `JSkeletonList` on dark surface (never raw `skeletonizer` or `CircularProgressIndicator` in list/page-body contexts)
- [ ] No gradients, no blur effects, no heavy shadows
- [ ] Transitions 150–200ms, no spring/bounce
- [ ] Focus states visible (orange border on input focus)
