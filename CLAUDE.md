# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Jobdun is a mobile-first job matching and workforce platform for the construction/trades industry. It connects two roles in the mobile app: **Builders** (post jobs, manage applicants) and **Trades/Crews** (browse and apply for jobs, upload verifications). **Admin is a separate web application** — the Flutter app has no admin UI.

- **Framework**: Flutter (Dart `^3.11.5`) — Android and iOS primary targets
- **Backend**: Supabase (Auth, PostgreSQL, Storage, Realtime, RLS, Edge Functions)
- **State management**: Riverpod (preferred) or Bloc
- **Navigation**: GoRouter
- **Architecture**: Feature-first Clean Architecture

## Design System

**Skill installed:** `ui-ux-pro-max` (in `.claude/skills/ui-ux-pro-max/` — also globally in `~/.claude/skills/`)

Before building any screen, always read the design system:
1. Read `design-system/jobdun/MASTER.md` — global colors, fonts, effects, anti-patterns
2. Check `design-system/jobdun/pages/<page>.md` — if it exists, its rules override MASTER

Available page-specific overrides:
- `design-system/jobdun/pages/auth-onboarding.md`
- `design-system/jobdun/pages/jobs-feed.md`
- `design-system/jobdun/pages/profile-dashboard.md`
- `design-system/jobdun/pages/messaging.md`
- `design-system/jobdun/pages/admin-web.md`

**Jobdun design tokens (from MASTER):**
- Primary: `#64748B` (industrial slate)
- Secondary: `#94A3B8`
- CTA / Accent: `#F97316` (safety orange)
- Background: `#F8FAFC`
- Text: `#334155`
- Style: Flat Design — 2D, no heavy shadows, clean lines, icon-heavy
- Typography: Inter (all weights) via `google_fonts`
- Transitions: 150–200ms ease, no gratuitous animation
- Anti-patterns: outdated forms, hidden filters, heavy gradients

To regenerate design system for a new page:
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<description>" --design-system -p "Jobdun" --persist --page "<page-name>"
```

To query Flutter-specific guidelines:
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<topic>" --stack flutter
```

## Commands

```bash
# Install dependencies
flutter pub get

# Run (Android/iOS emulator or connected device)
flutter run

# Run iOS (first time or after adding packages)
cd ios && pod install && cd ..
flutter run

# Run with Supabase credentials
flutter run \
  --dart-define=SUPABASE_URL=your_supabase_project_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key

# Test
flutter test
flutter test test/widget_test.dart   # single file

# Analyze / lint
flutter analyze
dart format --set-exit-if-changed .  # CI format check

# Verify Flutter setup
flutter doctor
```

## Architecture

### Feature-first Clean Architecture

Each feature owns its own three layers. Code in one layer must not reach into sibling layers of another feature directly.

```
lib/
  app/          # App root, router (GoRouter), theme, constants
  core/         # Shared config, errors, utils, common widgets
  features/
    auth/
    profile/
    jobs/
    applications/
    messaging/
    verification/
    reviews/
    notifications/
  main.dart
```

Each feature folder contains:
- `data/` — Supabase queries, DTOs/models, repository implementations
- `domain/` — Entities, repository contracts, use cases (no Flutter/Supabase imports)
- `presentation/` — Pages, widgets, Riverpod providers/Blocs

**Key rule**: The domain layer must not depend on Flutter, Supabase, or any external package. Only the data layer talks to Supabase.

### Supabase config

Credentials are passed via `--dart-define` at build time and read from `core/config/env.dart`. Never use the service-role key in the Flutter app — only the anon key. Privileged operations go through RLS policies or Edge Functions.

A `handle_new_user()` DB trigger auto-inserts a row into `profiles` on every `auth.users` INSERT. This must exist before any sign-up is attempted.

### Key database tables

`profiles` → `builder_profiles` / `trade_profiles` (role split via FK), `jobs`, `job_applications`, `messages`, `verification_documents`, `reviews`, `notifications`.

Row Level Security is required on all tables. Users may only read/write their own data; admins are gated by role checks.

### Navigation routes (GoRouter)

`/splash` → `/login` → `/register` → `/onboarding` → `/home` → `/jobs` (nested: `/jobs/create`, `/jobs/:id`) → `/applications` → `/messages` (nested: `/messages/:conversationId`) → `/profile` (nested: `/profile/edit`) → `/verification` → `/reviews` → `/notifications`

`/jobs` uses nested routes to prevent `/jobs/create` from matching `:id`.

### Job status lifecycle

`Draft` → `Open` → `In Review` → `Assigned` → `In Progress` → `Completed` / `Cancelled`

### Application status lifecycle

`Pending` → `Shortlisted` → `Accepted` / `Rejected` / `Withdrawn`

## Key packages

```yaml
# Core / backend
supabase_flutter, go_router, flutter_riverpod,
equatable, fpdart, json_annotation,
intl, connectivity_plus,
image_picker, file_picker, cached_network_image,
url_launcher, google_sign_in, sign_in_with_apple, crypto

# === UI/UX — Animations & Motion ===
flutter_animate    # composable widget animations (.animate().fadeIn().slideY())
lottie             # Lottie JSON animations — use for empty states, success, loading
animations         # Material motion transitions (SharedAxis, FadeThroughTransition)

# === UI/UX — Typography & Icons ===
google_fonts       # Inter / Poppins — use via AppTheme.textTheme
flutter_svg        # SVG rendering for illustrations and custom icons
iconsax            # 1000+ Iconsax icon set (prefer over Material Icons)

# === UI/UX — Responsive Layout ===
flutter_screenutil # SizeExtension — use .w / .h / .sp / .r for responsive units
gap                # Gap(16) instead of SizedBox(height: 16)

# === UI/UX — Loading & Skeleton States ===
shimmer            # Shimmer.fromColors — shimmer loading placeholders
skeletonizer       # Skeletonizer(child: ...) — auto-generate skeleton from real widgets

# === UI/UX — Components ===
smooth_page_indicator   # onboarding page dots (ExpandingDotsEffect preferred)
flutter_slidable         # SlidableAction on job cards (archive, shortlist)
badges                   # Badge() — notification dot overlays
percent_indicator        # CircularPercentIndicator / LinearPercentIndicator
expandable               # ExpandablePanel — job description, profile sections
flutter_staggered_animations  # AnimationLimiter + AnimationConfiguration for lists
modal_bottom_sheet       # showMaterialModalBottomSheet — iOS-style bottom sheets

# === UI/UX — Forms & Input ===
flutter_form_builder     # FormBuilder + FormBuilderTextField etc.
form_builder_validators  # FormBuilderValidators.required() / .email() etc.
pinput                   # OTP / PIN input for auth (Pinput widget)

# === UI/UX — Media & Image Handling ===
photo_view               # PhotoView — zoomable doc/image viewer
flutter_image_compress   # FlutterImageCompress.compressWithFile — compress before upload
image_cropper            # ImageCropper().cropImage — crop avatar/logo before upload

# === UI/UX — Data Display ===
fl_chart                 # BarChart / LineChart — earnings dashboard, analytics
flutter_rating_bar       # RatingBar — star ratings on profiles
table_calendar           # TableCalendar — trade availability calendar
infinite_scroll_pagination  # PagedListView / PagedGridView — job feed pagination

# dev
build_runner, json_serializable, mocktail

# pending — add when freezed resolves with riverpod 3.x
# freezed_annotation, freezed
```

### UI/UX conventions

- **Spacing**: always use `Gap(n)` — never raw `SizedBox(height/width: n)`.
- **Sizing**: always use `flutter_screenutil` extensions (`.w`, `.h`, `.sp`, `.r`) — never hardcode raw pixels.
- **Icons**: use `Iconsax.*` by default; fall back to `Icons.*` only for Material-specific cases.
- **Fonts**: configure `google_fonts` in `AppTheme` (e.g. Inter for body, Poppins for headings) — never call `GoogleFonts.*` per-widget.
- **Animations**: wrap list items with `flutter_staggered_animations`; use `flutter_animate` for micro-interactions (fade, slide, scale).
- **Loading**: use `skeletonizer` for data-driven screens; `shimmer` for image placeholders.
- **Empty states**: pair a Lottie animation + headline + CTA — never show a blank screen.
- **Bottom sheets**: use `modal_bottom_sheet` (not Flutter's built-in) for consistent iOS-style sheets.
- **Forms**: use `flutter_form_builder` for all forms; validate with `form_builder_validators`.

Use case return type: `Future<Either<Failure, T>>` from `fpdart`.

Use pinned versions before production release.

## Supabase storage buckets

`avatars`, `company-logos`, `portfolio-images`, `verification-documents`, `job-attachments`

## Branch strategy

```
main        production-ready
develop     integration
feature/*   features
fix/*       bug fixes
release/*   release prep
```

PRs require: passing `flutter analyze` + `flutter test`, at least one reviewer, screenshots for UI changes, migration notes for DB changes.
