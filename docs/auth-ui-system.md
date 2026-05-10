# Auth UI System

## Galvanised Design System

Source of truth: `JobDun Design System/` in the project root.

| File | Purpose |
|---|---|
| `GALVANISED_SKILL_REFERENCE.md` | Master ruleset — tokens, type scale, spacing, voice |
| `tokens.css` | All design tokens as CSS custom properties |
| `ui_kits/jobdun-app/theme.jsx` | Flutter Material 3 ColorScheme mapping |
| `voice.md` | Copy guidelines |
| `assets/` | SVG brand assets (mark-jobdun.svg, logo-jobdun.svg) |

### Core Tokens

| Token | Value | Flutter constant |
|---|---|---|
| Foundation (charcoal) | `#252D34` | `AppColors.foundation` |
| Action (signal orange) | `#CC4A10` | `AppColors.action` |
| Background | `#F4F6F8` | `AppColors.background` |
| Surface (input fill, section bg) | `#EAEEF2` | `AppColors.surface` |
| Card | `#FFFFFF` | `AppColors.card` |
| Border | `#D4D9DF` | `AppColors.border` |
| Text primary | `#252D34` | `AppColors.text1` |
| Text secondary | `#5A6872` | `AppColors.text2` |
| Text muted / placeholders | `#A0ACB8` | `AppColors.text3` |
| Verified green | `#0D8A5A` | `AppColors.verified` |
| Urgent red | `#C73B2E` | `AppColors.urgent` |

### Typography

| Role | Family | Size | Weight | Use |
|---|---|---|---|---|
| Display | Barlow Condensed | 40sp | 700 | Hero titles (CAPS OK) |
| H1 | Barlow Condensed | 28sp | 700 | Screen headings |
| H2 | Barlow | 20sp | 600 | Card group labels |
| H3 | Barlow | 16sp | 600 | Card names |
| Body | Barlow | 15sp | 400 | Descriptions, line-height 1.7 |
| Label | Barlow | 13sp | 400 | Trade type, job count |
| Caption | Barlow | 11sp | 500 | Timestamps, meta |
| Eyebrow | Barlow | 11sp | 600 | UPPERCASE labels, tracking 0.12em |
| Button | Barlow | 13sp | 600 | All button labels |

Font loading: `GoogleFonts.barlow()` and `GoogleFonts.barlowCondensed()` — both already in `google_fonts` package.

### Spacing (4pt grid)

Screen horizontal padding: **20px always** — `EdgeInsets.symmetric(horizontal: 20.w)`.

| Token | Value |
|---|---|
| `AppSpacing.xs` | 4 |
| `AppSpacing.sm` | 8 |
| `AppSpacing.md` | 12 |
| `AppSpacing.lg` | 16 |
| `AppSpacing.xl` | 20 (screen padding) |
| `AppSpacing.xxl` | 32 |

### Border Radius

| Token | Value | Use |
|---|---|---|
| `AppRadius.badge` | 5 | Status badges |
| `AppRadius.chip` | 8 | Filter chips, status banners |
| `AppRadius.btn` | 9 | All buttons |
| `AppRadius.card` | 14 | Cards — never exceed 14 |
| `AppRadius.input` | 10 | Text inputs |
| `AppRadius.avatar` | 10 | Avatar blocks (never circle) |

---

## Auth Screen Inventory

| Route | Widget | AuthState read | Form fields | Navigation triggers |
|---|---|---|---|---|
| `/splash` | `SplashPage` | `isAuthenticated`, `onboardingComplete` | — | Auto after 900ms |
| `/login` | `LoginPage` | `isLoading`, `errorMessage`, `infoMessage` | email, password | Success → router redirect; register link → `/register` |
| `/register` | `RegisterPage` | `isLoading`, `errorMessage`, `infoMessage` | full_name, email, password | Success → router redirect; sign in link → `/login` |
| `/verify-email` | `VerifyEmailPage` | `pendingVerificationEmail`, `isLoading`, `infoMessage`, `errorMessage` | — | Back to sign in → `clearPendingVerification()` |
| `/onboarding` | `OnboardingPage` | — | role selection (UserRole enum) | `completeOnboarding(role)` → router redirect to `/home` |

---

## Component Conventions

### AppButton — `lib/core/widgets/app_button.dart`

Five variants via `AppButtonVariant` enum. All buttons: height `48.h`, radius `9.r`.

| Variant | Background | Text | Use for |
|---|---|---|---|
| `primary` | `#252D34` foundation | white | Main CTAs — sign in, create account, next |
| `action` | `#CC4A10` signal orange | white | High-urgency actions |
| `outline` | transparent | `text1`, 1.5px border | Secondary actions |
| `ghost` | `#FFFFFF` card | `text2`, 1px border | Tertiary / resend |
| `text` | transparent | `action` orange | Links-in-text, back buttons |

Pass `isLoading: true` to show spinner — the button manages its own loading UI.

### StatusBanner — `lib/core/widgets/status_banner.dart`

```dart
StatusBanner(message: 'Invalid credentials.', isError: true)
StatusBanner(message: 'Email resent.', isError: false)
```

Error: urgentBg fill + urgent border + `Iconsax.warning_2`
Success: verifiedBg fill + verified border + `Iconsax.tick_circle`

### SocialAuthButtons — `lib/features/auth/presentation/widgets/social_auth_buttons.dart`

Drop-in widget. Reads `isLoading` from `authControllerProvider`. Renders Google + Apple (iOS/macOS only) as 48×48 ghost square buttons. All OAuth callbacks are internal.

---

## Copy Rules (voice.md summary)

- No exclamation marks in any UI copy
- No emoji in any UI copy
- Sentence case for labels — EXCEPTION: Display/H1 in Barlow Condensed may be ALL CAPS
- Australian spelling: Licence (not License), Colour, Behaviour
- Numbers as digits: "3 tradies" not "three tradies"
- Direct and calm: "Sign in." not "Welcome back! Let's go!"
- Eyebrow labels always UPPERCASE (they are typographically styled, not shouting)

---

## Do Not Touch Boundary

The auth UI only calls these methods on `authControllerProvider.notifier`:
- `signIn(email:, password:)`
- `register(email:, password:, fullName:)`
- `resendVerificationEmail()`
- `clearPendingVerification()`
- `signInWithGoogle()`
- `signInWithApple()`
- `completeOnboarding(UserRole)`

Never touch:
- `lib/features/auth/data/` — Supabase queries
- `lib/features/auth/domain/` — entities and use cases
- `AuthState` fields — read-only from UI
- `AuthController` business logic
- GoRouter configuration — `lib/app/router/`

---

## Package Usage in Auth Flow

| Package | Used for |
|---|---|
| `flutter_form_builder` | Declarative forms in login / register (replaces TextEditingController) |
| `form_builder_validators` | Required, email, minLength validators |
| `flutter_screenutil` | `.w` `.h` `.sp` `.r` responsive units — ScreenUtilInit in `app.dart` with `Size(390, 844)` |
| `google_fonts` | `GoogleFonts.barlow()` and `GoogleFonts.barlowCondensed()` for all text |
| `flutter_svg` | SVG brand mark on splash and onboarding welcome page |
| `iconsax` | All icons (sms, lock, eye, eye_slash, sms_notification, user, personalcard, tick_circle, warning_2, info_circle, briefcase) |
| `smooth_page_indicator` | Onboarding page dots — `ExpandingDotsEffect` with foundation active dot |
| `gap` | `Gap(n)` instead of `SizedBox(height: n)` / `SizedBox(width: n)` |
