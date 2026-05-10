# Jobdun Design System

Living team reference. Last updated: 2026-05-11.  
Source of truth: `lib/app/theme/` — never duplicate tokens here, link to them.

---

## Principles

1. **Dark-first.** Background is `#0F172A`. Never use white backgrounds in the app.
2. **Heavy weight.** Headings are Oswald w700. Body minimum w500. No thin fonts.
3. **Safety orange.** `#F97316` is the one brand action color. Don't add a second CTA color.
4. **Aggressive flat.** No drop shadows. No elevation. No gradients in layouts — only on wordmarks/logos via `AppGradients.brandFlame`.
5. **All-caps buttons.** Every button label is uppercase, tracked at `letterSpacing: 0.5+`.
6. **Icon-heavy.** Use `Iconsax.*` as default. Fall back to `Icons.*` only for Material-specific widgets.
7. **Transitions only.** 150–200ms ease curves. No bounce, no spring.
8. **Token everything.** If a color, size, or radius appears more than once, it needs a token.
9. **White has two legal uses.** (a) Text inside `ShaderMask` (annotate: `ShaderMask requires white for gradient`). (b) Text/icons on `c.action` orange or `c.verified` green backgrounds (annotate: `white-on-action`).

---

## Typography

All fonts configured in `lib/app/theme/app_theme.dart` via `GoogleFonts`. Never call `GoogleFonts.*` per-widget — use `Theme.of(context).textTheme.*` slots.

| Slot | Font | Weight | Size | Height | Letter Spacing | Use |
|------|------|--------|------|--------|----------------|-----|
| `displayLarge` | Oswald | w700 | 40sp | — | 1.2 | Hero wordmarks |
| `headlineLarge` | Oswald | w700 | 32sp | — | 0.8 | Page hero titles |
| `headlineMedium` | Oswald | w600 | 24sp | — | — | Section heroes |
| `headlineSmall` | Oswald | w700 | 20sp | — | — | Card titles, modal headers |
| `titleLarge` | Oswald | w700 | 16sp | — | — | Sub-headings |
| `titleMedium` | Open Sans | w600 | 15sp | — | — | Strong body labels |
| `titleSmall` | Open Sans | w600 | 13sp | — | — | Compact labels |
| `bodyLarge` | Open Sans | w400 | 15sp | 1.5 | — | Main body copy |
| `bodyMedium` | Open Sans | w400 | 13sp | 1.4 | — | Secondary body |
| `bodySmall` | Open Sans | w500 | 11sp | — | — | Captions, timestamps |
| `labelLarge` | Oswald | w700 | 14sp | — | 1.5 | Button labels |
| `labelMedium` | Open Sans | w600 | 12sp | — | — | Chip labels |
| `labelSmall` | Open Sans | w600 | 10sp | — | 0.8–1.32 | Field labels (ALL CAPS) |

**Brand display:** `AppTheme.brandDisplay(color)` — Inter Black 40sp, ls 3.0. Use only on the JOBDUN wordmark.

**Field labels convention:** `tt.labelSmall!.copyWith(letterSpacing: 0.12 * 11, color: c.text3)` — the `0.12 * 11` formula produces 1.32 tracking used consistently across all `ALL CAPS` section labels.

---

## Colors

Accessed via `context.c` (`JColors` ThemeExtension). Defined in `lib/app/theme/app_colors.dart`.

| Token | Dark Hex | Purpose |
|-------|----------|---------|
| `background` | `#0F172A` | Page background |
| `surface` | `#1E293B` | Cards, inputs, bottom sheets |
| `surfaceRaised` | `#334155` | Elevated cards, secondary buttons, avatar backgrounds |
| `card` | `#1A2744` | App bar, sticky headers, nav bar |
| `border` | `#334155` | Dividers, input outlines |
| `text1` | `#F1F5F9` | Primary text |
| `text2` | `#94A3B8` | Secondary text, labels |
| `text3` | `#64748B` | Hints, placeholders, captions |
| `action` | `#F97316` | Primary CTA, links, active states |
| `actionBg` | `#431407` | Tinted background for action states |
| `actionPressed` | `#EA6C0A` | Pressed state of action |
| `verified` | `#22C55E` | Verified checkmarks |
| `verifiedBg` | `#052E16` | Verification banner background |
| `verifiedTx` | `#86EFAC` | Text on verifiedBg |
| `urgent` | `#EF4444` | Error, urgent badge foreground |
| `urgentBg` | `#450A0A` | Urgent banner background |
| `urgentTx` | `#FCA5A5` | Text on urgentBg |
| `available` | `#60A5FA` | Availability indicator, links |
| `availableBg` | `#1E3A5F` | Available state background |
| `star` | `#FBBF24` | Star rating icon |

---

## Gradients

Defined in `lib/app/theme/app_gradients.dart`.

### `AppGradients.brandFlame`

```dart
static const brandFlame = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFF176), // warm yellow
    Color(0xFFFFB300), // amber
    Color(0xFFF97316), // safety orange
    Color(0xFFE64A19), // deep orange
    Color(0xFFBF360C), // burnt orange
  ],
);
```

**Usage:** Only via `ShaderMask` on text (wordmarks, page titles). The child text widget **must** use `color: Colors.white` with the intentional comment `// intentional: ShaderMask requires white for gradient`.

**Never use:** As a container background, button gradient, or card fill. Anti-pattern.

---

## Spacing

Defined as `AppSpacing` in `lib/app/theme/app_colors.dart`.

| Token | Value | `.w` / `.h` usage |
|-------|-------|-------------------|
| `AppSpacing.xs` | 4dp | `Gap(AppSpacing.xs.h)` |
| `AppSpacing.sm` | 8dp | `Gap(AppSpacing.sm.w)` |
| `AppSpacing.md` | 16dp | `EdgeInsets.all(AppSpacing.md)` |
| `AppSpacing.lg` | 24dp | `EdgeInsets.all(AppSpacing.lg)` |
| `AppSpacing.xl` | 32dp | `EdgeInsets.symmetric(horizontal: AppSpacing.xl.w)` |
| `AppSpacing.xxl` | 48dp | `EdgeInsets.only(bottom: AppSpacing.xxl)` |

Values **10, 12, 14, 20** have no token — use raw `.w`/`.h` (e.g., `Gap(12.h)`).

Always use `Gap(n)` instead of `SizedBox(height: n)` or `SizedBox(width: n)`.

---

## Border Radius

Defined as `AppRadius` in `lib/app/theme/app_colors.dart`.

| Token | Value | Use |
|-------|-------|-----|
| `AppRadius.btn` | 8r | Buttons |
| `AppRadius.card` | 12r | Cards, info panels |
| `AppRadius.chip` | 20r | Filter chips, badges |
| `AppRadius.input` | 8r | Text fields, search bars |
| `AppRadius.avatar` | 999r | Circular avatars |
| `AppRadius.badge` | 999r | Notification dots |

---

## Elevation

`AppElevation.none = 0.0` — Jobdun uses no drop shadows. All depth is created via border color and `surfaceRaised` background contrast.

---

## Icon Sizes

Defined as `AppIconSize` in `lib/app/constants/app_constants.dart`.

| Token | Value | Use |
|-------|-------|-----|
| `AppIconSize.sm` | 16dp | Inline text icons, row indicators |
| `AppIconSize.md` | 20dp | Nav bar, header actions |
| `AppIconSize.lg` | 24dp | Empty states, feature icons |
| `AppIconSize.xl` | 32dp | Hero icons |
| `AppIconSize.feature` | 40dp | Onboarding feature illustrations |

---

## Buttons

All button labels uppercase, tracked. Use `AppButton` from `lib/core/widgets/app_button.dart`.

| Variant | Background | Text | Height | Radius |
|---------|-----------|------|--------|--------|
| `primary` (default) | `c.action` | `Colors.white` + intentional comment | 48h | `AppRadius.btn` |
| `secondary` | `c.surfaceRaised` | `c.text1` | 48h | `AppRadius.btn` |
| `ghost` | transparent | `c.action` | 48h | `AppRadius.btn` |

**States:**
- Loading: `CircularProgressIndicator(color: c.text1, strokeWidth: 2)` inside `SizedBox.square(dimension: 18.r)`
- Disabled: `c.surfaceRaised` background, reduced opacity on text

---

## Form Inputs

Configured globally in `app_theme.dart` `InputDecorationTheme`. No per-widget overrides needed except `style:` for the text color.

| State | Border | Fill |
|-------|--------|------|
| Default | `c.border` 1px | `c.surface` |
| Focused | `c.action` 2px | `c.surface` |
| Error | `c.urgent` 1px | `c.surface` |
| Disabled | `c.border @ 40%` | `c.surface @ 50%` |

**Pattern:**
```dart
TextField(
  style: tt.bodyLarge!.copyWith(color: c.text1),
  decoration: InputDecoration(
    hintText: '...',
    // Do NOT set hintStyle — inherited from theme
    border: InputBorder.none, // theme handles all states
    filled: false,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
    isDense: true,
  ),
)
```

---

## Components

### `JobCard` — `lib/core/design/widgets/job_card.dart`
Job listing card. Props: `title`, `description`, `rate`, `startDate`, `distanceKm`, `isUrgent`, `onTap`.  
When to use: job list, search results.  
When NOT to use: inside a bottom sheet or modal (use a compact inline layout instead).

### `GvChip` — `lib/core/design/widgets/gv_chip.dart`
Filter chip. Props: `label`, `active`, `onTap`.  
Active state: `c.action` background, `Colors.white` text (intentional).  
Use in horizontal `ListView.separated` with `Gap(AppSpacing.sm.w)` separator.

### `StatusBadge` — `lib/core/design/widgets/status_badge.dart`
Inline status indicator. Props: `label`, `color`, `bgColor`.  
Use for application/job status (Pending, Accepted, Rejected, etc.).

### `AvatarBlock` — `lib/core/design/widgets/avatar_block.dart`
Initials avatar with size variants. Props: `initials`, `size` (72, 48, 36).

### `TradieCard` — `lib/core/design/widgets/tradie_card.dart`
Tradie search result card. Props: `name`, `trade`, `rating`, `suburb`, etc.

### `EmptyState` — `lib/core/design/widgets/empty_state.dart`
Full-screen empty state. Props: `lottieAsset`, `headline`, `body`, `ctaLabel`, `onCta`.  
Always pair with a Lottie animation. Never show a blank screen.

### `BottomSheetHeader` — `lib/core/design/widgets/bottom_sheet_header.dart`
Drag handle + optional title for bottom sheets. Props: `title`.  
Use at the top of all `showMaterialModalBottomSheet` content.

### `AppButton` — `lib/core/widgets/app_button.dart`
Primary/secondary/ghost button. Props: `label`, `variant`, `onPressed`, `isLoading`.

---

## Icon Vocabulary

| Action | Iconsax name |
|--------|-------------|
| Search | `Iconsax.search_normal` |
| Filter / Trade | `Iconsax.filter` |
| Location | `Iconsax.location` |
| Urgent / Flash | `Iconsax.flash_1` |
| Verified | `Iconsax.verify` |
| Message | `Iconsax.message` |
| Send | `Iconsax.send_1` |
| Notification | `Iconsax.notification` |
| Profile | `Iconsax.profile_circle` |
| Jobs / Briefcase | `Iconsax.briefcase` |
| Applications | `Iconsax.document_text` |
| Edit | `Iconsax.edit_2` |
| Close | `Iconsax.close_circle` |
| Back | `Iconsax.arrow_left` |
| Add | `Iconsax.add` |
| Check / Success | `Iconsax.tick_circle` |
| Star / Rating | `Iconsax.star` |
| Upload | `Iconsax.document_upload` |
| Settings | `Iconsax.setting_2` |
| More options | `Iconsax.more` |
| Lock | `Iconsax.lock` |
| Shield | `Iconsax.shield_tick` |

---

## Non-Negotiable Rules

1. **Never call `GoogleFonts.*` per-widget.** Configure once in `app_theme.dart`.
2. **Never use `SizedBox` for spacing.** Use `Gap(AppSpacing.*)`.
3. **Never hardcode `Color(0xFF...)` in feature or core code.** Use `context.c.*`.
4. **Never use `Colors.white` without an intentional annotation comment.**
5. **Never use `LinearGradient` inline.** Use `AppGradients.brandFlame`.
6. **Never use white or light backgrounds.** Background is `#0F172A`.
7. **Never use raw `EdgeInsets` pixels when a token exists.** Map 8→sm, 16→md, 24→lg, 32→xl, 48→xxl.
8. **Never skip `flutter analyze` before committing.** Zero errors required.
9. **Never add `GoogleFonts.*` imports in feature files.** Imports belong only in `app_theme.dart`.

---

## Accessibility

| Pair | Ratio | Status |
|------|-------|--------|
| text1 on background | 14.7:1 | ✅ |
| text2 on surface | 5.3:1 | ✅ |
| text3 on surface | 3.1:1 | ⚠️ (hints/decorative — exempt from AA) |
| actionTx on actionBg | 8.2:1 | ✅ |
| verifiedTx on verifiedBg | 9.1:1 | ✅ |
| urgentTx on urgentBg | 7.4:1 | ✅ |
| White text on action (buttons) | 2.5:1 | ❌ Known trade-off — mitigated by w700+ weight |

WCAG AA minimum: 4.5:1 normal text, 3:1 large text (≥18pt or ≥14pt bold).
