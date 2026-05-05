# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Jobdun is a mobile-first job matching and workforce platform for the construction/trades industry. It connects two roles in the mobile app: **Builders** (post jobs, manage applicants) and **Trades/Crews** (browse and apply for jobs, upload verifications). **Admin is a separate web application** — the Flutter app has no admin UI.

- **Framework**: Flutter (Dart `^3.11.5`) — Android and iOS primary targets
- **Backend**: Supabase (Auth, PostgreSQL, Storage, Realtime, RLS, Edge Functions)
- **State management**: Riverpod (preferred) or Bloc
- **Navigation**: GoRouter
- **Architecture**: Feature-first Clean Architecture

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
# installed
supabase_flutter, go_router, flutter_riverpod,
equatable, fpdart, json_annotation,
intl, connectivity_plus,
image_picker, file_picker, cached_network_image, url_launcher

# dev (installed)
build_runner, json_serializable, mocktail

# pending — add when freezed resolves with riverpod 3.x
# freezed_annotation, freezed
```

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
