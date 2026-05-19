# Jobdun

Mobile-first job matching and workforce platform for the construction and trades industry.

## Roles

- **Builder** — post jobs, review applicants, manage projects
- **Trade / Crew** — browse jobs, apply, upload verification documents

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter (Dart `^3.11.5`) — Android & iOS |
| Backend | Supabase (Auth, PostgreSQL, Storage, Realtime, RLS) |
| State | Riverpod 3.x (`NotifierProvider`) |
| Navigation | GoRouter 17.x |
| Architecture | Feature-first Clean Architecture |

---

## Quick Start

### 1. Prerequisites

- Flutter SDK `^3.11.5` (`flutter doctor` should pass)
- A Supabase project with the schema deployed (see [Database Setup](#database-setup))
- Google Maps API key (optional — app runs without it, map view shows grey tiles)

### 2. Clone and install

```bash
git clone <repo-url>
cd jobdun
flutter pub get
```

### 3. Environment

Create a `.env` file in the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
GOOGLE_WEB_CLIENT_ID=your_google_web_client_id
GOOGLE_IOS_CLIENT_ID=your_google_ios_client_id
MAPS_API_KEY=your_google_maps_api_key
```

### 4. Run

```bash
# Android / iOS emulator or connected device
flutter run

# Pass env at runtime (alternative to .env file)
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

---

## Database Setup

The `supabase/migrations/` directory contains all 8 SQL migration files. Apply them in order via the Supabase Dashboard SQL editor or the Supabase CLI:

```bash
# Using Supabase CLI (recommended)
supabase login
supabase link --project-ref your-project-ref
supabase db push

# Or apply manually in Supabase Dashboard -> SQL Editor
# Run each file in order: 000001 -> 000008
```

### After deploying migrations

Enable the **custom_access_token hook** in the Supabase Dashboard:

> Authentication -> Hooks -> Custom Access Token Hook -> select `public.custom_access_token`

This injects the `user_role` JWT claim that the Flutter app uses to determine the user's role (builder vs trade) without an extra DB round-trip.

---

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device / emulator
flutter test             # Run all tests (21 passing)
flutter analyze          # Static analysis -- must be clean
dart format .            # Format all Dart files
```

---

## Architecture

```
lib/
  app/          # Router, theme, constants, app widget
  core/         # Config, errors, utils, shared widgets, design system
  features/
    auth/        # Sign in, register, phone OTP, onboarding
    profile/     # Profile view + edit, builder/trade profiles
    jobs/        # Job feed, job detail, job create
    applications/ # Application list, status management
    messaging/   # Conversations, message thread
    verification/ # Document upload and status
    reviews/     # Star ratings and comments
    notifications/ # Push notification inbox
  main.dart
```

Each feature: `data/` (Supabase, DTOs) -> `domain/` (entities, use cases, repository contracts) -> `presentation/` (pages, providers, widgets).

---

## Sprint 1 -- Completed (2026-05-11)

| Deliverable | Status |
|---|---|
| Supabase migrations (8 files, all tables + RLS + trigger + JWT hook) | Done |
| Phone/OTP authentication | Done |
| Logout confirmation bottom sheet | Done |
| Auth UI polish | Done |
| Google Maps home page toggle | Done |
| AdaptiveIcon widget | Done |
| JobdunLogo widget | Done |
| 21 tests passing, CI/CD configured | Done |

## Sprint 2 -- Planned

- Role-based route guards in GoRouter redirect
- Jobs feed pagination with `infinite_scroll_pagination`
- Apply-to-job flow from job detail page
- Realtime messaging with Supabase Realtime
- Push notification integration
- Lottie empty states throughout the app
- Verification document upload (camera + file picker)
- Profile edit page fully wired
