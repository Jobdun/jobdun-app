# Jobdun App

Jobdun is a mobile-first job matching and workforce platform for the construction/trades industry. The app connects **builders**, **trades/crews**, and **admins** in one system so jobs can be posted, discovered, assigned, tracked, reviewed, and verified.

The application is planned as a cross-platform **Android and iOS app** built with **Flutter**, using **Supabase** as the backend for authentication, database, storage, and real-time features.

---

## 1. Product Goal

Jobdun aims to reduce friction in finding reliable tradespeople and managing construction-related jobs.

### Main users

- **Builders / Companies**
  - Post jobs
  - Search for trades/crews
  - Review applicants
  - Manage job progress
  - Rate completed work

- **Trades / Crews**
  - Create a professional profile
  - Upload licences, insurance, and verification documents
  - Browse available jobs
  - Apply for jobsf
  - Receive notifications and job updates

- **Admins**
  - Review user verification documents
  - Manage users and reported issues
  - Moderate job posts
  - Monitor platform activity

---

## 2. Core Features

### Authentication

- Email/password login
- Google/Apple login support
- Role-based onboarding:
  - Builder
  - Trade/Crew
  - Admin
- Forgot password
- Email verification
- Session persistence

### User Profiles

#### Builder Profile

- Company name
- Contact person
- Business email
- Phone number
- Company address
- ABN/ACN or business identifier
- Company logo
- Company description
- Ratings and reviews

#### Trade/Crew Profile

- Full name or business name
- Trade category
- Skills/specializations
- Years of experience
- Service area/location
- Availability
- Licence number
- Insurance details
- Portfolio/photos
- Ratings and reviews
- Verification status

### Job Management

- Create job post
- Edit job post
- Delete/archive job post
- Job title
- Job description
- Location
- Budget/rate
- Start date
- Required skills/trades
- Required licences/insurance
- Job status:
  - Draft
  - Open
  - In Review
  - Assigned
  - In Progress
  - Completed
  - Cancelled

### Job Discovery

- Browse jobs
- Search jobs
- Filter by:
  - Location
  - Trade category
  - Budget/rate
  - Date
  - Job type
  - Verification requirement
- Save/bookmark jobs

### Applications

- Trade applies to a job
- Builder reviews applications
- Builder accepts/rejects applicants
- Application statuses:
  - Pending
  - Shortlisted
  - Accepted
  - Rejected
  - Withdrawn

### Messaging

- Builder-to-trade chat
- Job-specific conversation threads
- Message timestamps
- Read status
- Attachment support in future version

### Verification

- Upload licence documents
- Upload insurance documents
- Admin review workflow
- Verification badges:
  - Identity verified
  - Licence verified
  - Insurance verified
- Expiry date tracking

### Ratings and Reviews

- Builder rates trade/crew
- Trade/crew rates builder
- Review text
- Star rating
- Review moderation/reporting

### Notifications

- New job posted
- New application received
- Application accepted/rejected
- Message received
- Verification approved/rejected
- Job status changed

### Admin Panel / Admin Features

- View all users
- View all jobs
- Review uploaded documents
- Approve/reject verification
- Suspend users
- Moderate reviews
- View basic analytics

---

## 3. Tech Stack

### Mobile App

- **Flutter**
- **Dart**
- **Feature-first Clean Architecture**
- **Riverpod or Bloc** for state management
- **GoRouter** for navigation
- **Supabase Flutter SDK**

### Backend

- **Supabase Auth**
- **Supabase PostgreSQL**
- **Supabase Storage**
- **Supabase Realtime**
- **Supabase Row Level Security**
- **Supabase Edge Functions** when server-side logic is needed

### Optional Later Add-ons

- Firebase Cloud Messaging for push notifications
- Google Maps API for location/map features
- Sentry for crash/error monitoring
- PostHog or Firebase Analytics for product analytics
- RevenueCat or Stripe if paid subscriptions are added

---

## 4. Architecture

The app uses **feature-first clean architecture**.

Instead of organizing the code by technical layers only, each major business feature owns its own presentation, domain, and data layers.

### Target folder structure

```txt
lib/
  app/
    app.dart
    router/
      app_router.dart
    theme/
      app_theme.dart
    constants/
      app_constants.dart

  core/
    config/
      env.dart
      supabase_config.dart
    errors/
      failures.dart
      exceptions.dart
    network/
      network_info.dart
    utils/
      validators.dart
      date_utils.dart
    widgets/
      app_button.dart
      app_text_field.dart
      loading_view.dart
      error_view.dart

  features/
    auth/
      data/
        datasources/
          auth_remote_datasource.dart
        repositories/
          auth_repository_impl.dart
        models/
          user_model.dart
      domain/
        entities/
          app_user.dart
        repositories/
          auth_repository.dart
        usecases/
          sign_in.dart
          sign_up.dart
          sign_out.dart
          get_current_user.dart
      presentation/
        pages/
          login_page.dart
          register_page.dart
          onboarding_page.dart
        providers/
          auth_provider.dart
        widgets/

    profile/
      data/
      domain/
      presentation/

    jobs/
      data/
      domain/
      presentation/

    applications/
      data/
      domain/
      presentation/

    messaging/
      data/
      domain/
      presentation/

    verification/
      data/
      domain/
      presentation/

    reviews/
      data/
      domain/
      presentation/

    notifications/
      data/
      domain/
      presentation/

    admin/
      data/
      domain/
      presentation/

  main.dart
```

---

## 5. Clean Architecture Rules

### Presentation Layer

Responsible for UI and state management.

Examples:

- Screens/pages
- Widgets
- View models/providers/blocs
- Form validation display
- Loading/error states

The presentation layer should not directly call Supabase.

### Domain Layer

Responsible for business logic.

Examples:

- Entities
- Repository contracts
- Use cases
- Business rules

The domain layer should not depend on Flutter, Supabase, or external packages.

### Data Layer

Responsible for external data sources.

Examples:

- Supabase queries
- API calls
- DTOs/models
- Repository implementations
- Local cache

Only this layer should know how Supabase works.

---

## 6. Suggested Supabase Database Tables

### `profiles`

Stores common user profile data.

```sql
id uuid primary key references auth.users(id) on delete cascade,
role text not null check (role in ('builder', 'trade', 'admin')),
full_name text,
phone text,
avatar_url text,
created_at timestamp with time zone default now(),
updated_at timestamp with time zone default now()
```

### `builder_profiles`

```sql
id uuid primary key references profiles(id) on delete cascade,
company_name text not null,
business_email text,
business_phone text,
business_address text,
abn text,
company_description text,
company_logo_url text
```

### `trade_profiles`

```sql
id uuid primary key references profiles(id) on delete cascade,
business_name text,
trade_category text not null,
skills text[],
years_experience int,
service_area text,
availability_status text,
bio text,
portfolio_urls text[]
```

### `jobs`

```sql
id uuid primary key default gen_random_uuid(),
builder_id uuid references profiles(id) on delete cascade,
title text not null,
description text not null,
location text,
budget numeric,
start_date date,
trade_category text,
required_skills text[],
status text not null default 'open',
created_at timestamp with time zone default now(),
updated_at timestamp with time zone default now()
```

### `job_applications`

```sql
id uuid primary key default gen_random_uuid(),
job_id uuid references jobs(id) on delete cascade,
trade_id uuid references profiles(id) on delete cascade,
status text not null default 'pending',
cover_message text,
created_at timestamp with time zone default now(),
updated_at timestamp with time zone default now(),
unique(job_id, trade_id)
```

### `messages`

```sql
id uuid primary key default gen_random_uuid(),
job_id uuid references jobs(id) on delete cascade,
sender_id uuid references profiles(id) on delete cascade,
receiver_id uuid references profiles(id) on delete cascade,
message text not null,
is_read boolean default false,
created_at timestamp with time zone default now()
```

### `verification_documents`

```sql
id uuid primary key default gen_random_uuid(),
user_id uuid references profiles(id) on delete cascade,
document_type text not null,
file_url text not null,
status text not null default 'pending',
rejection_reason text,
expires_at date,
reviewed_by uuid references profiles(id),
reviewed_at timestamp with time zone,
created_at timestamp with time zone default now()
```

### `reviews`

```sql
id uuid primary key default gen_random_uuid(),
job_id uuid references jobs(id) on delete cascade,
reviewer_id uuid references profiles(id) on delete cascade,
reviewee_id uuid references profiles(id) on delete cascade,
rating int not null check (rating >= 1 and rating <= 5),
comment text,
created_at timestamp with time zone default now()
```

### `notifications`

```sql
id uuid primary key default gen_random_uuid(),
user_id uuid references profiles(id) on delete cascade,
title text not null,
body text not null,
type text,
is_read boolean default false,
created_at timestamp with time zone default now()
```

---

## 7. Supabase Setup Checklist

### Required Supabase services

- Supabase Auth
- PostgreSQL database
- Storage buckets
- Row Level Security policies
- Realtime for chat/messages
- Edge Functions for protected server-side flows if needed

### Storage buckets

Recommended buckets:

```txt
avatars
company-logos
portfolio-images
verification-documents
job-attachments
```

### Environment variables

Create an environment config file or use `--dart-define`.

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Never commit private service-role keys into the mobile app.

---

## 8. Local Development Setup

### Prerequisites

Install the following:

- Flutter SDK
- Dart SDK
- Android Studio
- Xcode for iOS development
- CocoaPods
- Git
- Supabase project access

Check Flutter installation:

```bash
flutter doctor
```

### Clone repository

```bash
git clone <repository-url>
cd Jobdun
```

### Install dependencies

```bash
flutter pub get
```

### Run Android

```bash
flutter run
```

### Run iOS

```bash
cd ios
pod install
cd ..
flutter run
```

### Run with environment variables

```bash
cp .env.example .env
# fill SUPABASE_URL and SUPABASE_ANON_KEY in .env
flutter run --dart-define-from-file=.env
```

`SUPABASE_ANON_KEY` should contain the client-safe key from Supabase's Connect dialog. Supabase's current docs refer to this as a publishable-or-anon key for Flutter clients.

### Current starter implementation

The repository now includes a basic Android-first starter flow:

- Splash screen
- Login screen
- Register screen
- Role-based onboarding
- Home dashboard
- Jobs placeholder screen
- Messages placeholder screen
- Profile placeholder screen
- Verification placeholder screen
- Admin placeholder screen

Current routing is powered by `GoRouter` and starter state is managed with `Riverpod`. Supabase credentials are read from `--dart-define-from-file=.env` through `lib/core/config/env.dart`, and `supabase_flutter` is initialized in `main.dart` when those values are present.

### Current Supabase auth wiring

- `supabase_flutter` is installed and initialized in [lib/main.dart](/Users/kuya/Documents/Jobdun/lib/main.dart)
- email/password sign-in uses `supabase.auth.signInWithPassword(...)`
- email/password sign-up uses `supabase.auth.signUp(...)`
- Android internet permission is enabled in [android/app/src/main/AndroidManifest.xml](/Users/kuya/Documents/Jobdun/android/app/src/main/AndroidManifest.xml)
- `.env` is ignored by git, and `.env.example` is provided as the template

---

## 9. Recommended Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter

  supabase_flutter: latest
  go_router: latest
  flutter_riverpod: latest
  freezed_annotation: latest
  json_annotation: latest
  equatable: latest
  image_picker: latest
  file_picker: latest
  cached_network_image: latest
  intl: latest
  url_launcher: latest

dev_dependencies:
  build_runner: latest
  freezed: latest
  json_serializable: latest
  flutter_lints: latest
  mocktail: latest
```

Use pinned versions before production release instead of `latest`.

---

## 10. Navigation Plan

Suggested app routes:

```txt
/splash
/login
/register
/onboarding
/home
/jobs
/jobs/:id
/jobs/create
/applications
/messages
/messages/:conversationId
/profile
/profile/edit
/verification
/admin
/admin/users
/admin/jobs
/admin/verifications
```

---

## 11. Role-Based Access

### Builder

Can:

- Create jobs
- Edit own jobs
- View applicants for own jobs
- Accept/reject applicants
- Message applicants
- Leave reviews

### Trade/Crew

Can:

- Browse jobs
- Apply for jobs
- Manage own profile
- Upload verification documents
- Message builders
- Leave reviews

### Admin

Can:

- View all users
- View all jobs
- Review verification documents
- Suspend users
- Moderate platform content

---

## 12. Security Requirements

### Must-have security rules

- Enable Row Level Security on all Supabase tables.
- Users can only update their own profile.
- Builders can only update jobs they own.
- Trades can only apply as themselves.
- Users can only read messages where they are sender or receiver.
- Admin-only tables/actions must be protected by role checks.
- Verification documents must not be publicly accessible.
- Never expose Supabase service-role key in Flutter.

### Example security principle

The mobile app should only use the Supabase anon key. Any privileged operation must happen through:

- Supabase RLS policies
- Supabase Edge Functions
- Backend service using service-role key

---

## 13. Testing Strategy

### Unit Tests

Test:

- Use cases
- Validators
- Domain rules
- Repository behavior with mocked datasources

### Widget Tests

Test:

- Login screen
- Register screen
- Job card
- Job form
- Profile form
- Error/loading states

### Integration Tests

Test:

- Sign up flow
- Login flow
- Create job flow
- Apply to job flow
- Messaging flow
- Verification upload flow

### Backend/Supabase Tests

Test:

- RLS policies
- Table constraints
- Storage access rules
- Database triggers
- Edge Functions

---

## 14. Observability and Monitoring

Recommended tools:

- Sentry for crash reporting
- Supabase logs for backend/debugging
- PostHog or Firebase Analytics for product analytics
- GitHub Actions for CI checks

Track:

- App crashes
- Login failures
- Job creation failures
- Application submission failures
- Message send failures
- Verification upload failures
- Slow Supabase queries

---

## 15. CI/CD Plan

### GitHub Actions checks

Run on pull request:

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed .
```

### Release pipeline

Recommended flow:

1. Pull request opened
2. Code review
3. Static analysis
4. Unit/widget tests
5. Merge to `main`
6. Internal build
7. TestFlight / Google Play Internal Testing
8. Production release

---

## 16. Initial MVP Scope

Recommended MVP features:

1. Auth and role-based onboarding
2. Builder profile
3. Trade profile
4. Create job
5. Browse jobs
6. Apply to job
7. View applications
8. Basic messaging
9. Verification document upload
10. Admin verification review

Avoid overbuilding early. Marketplace quality depends first on reliable job posting, search, applications, trust, and communication.

---

## 17. Future Features

- Push notifications
- Map-based job discovery
- AI job matching
- AI profile improvement suggestions
- Smart trade recommendations for builders
- Subscription plans
- In-app payments
- Dispute handling
- Advanced analytics dashboard
- Crew/team management
- Calendar scheduling
- Timesheets
- Attendance tracking
- Invoice generation

---

## 18. Engineering Principles

- Keep business logic out of UI.
- Keep Supabase logic out of domain layer.
- Use typed models and entities.
- Validate inputs on client and backend.
- Design for offline/poor-network behavior where possible.
- Use clear error states and retry flows.
- Protect all user data with RLS.
- Keep features independently maintainable.
- Avoid hardcoding environment values.
- Add tests before scaling the team.

---

## 19. Repository Notes

This repository should be treated as the main mobile app codebase for Jobdun.

Recommended branch strategy:

```txt
main        production-ready code
develop     integration branch
feature/*   individual feature branches
fix/*       bug fix branches
release/*   release preparation branches
```

Recommended pull request rules:

- No direct push to `main`
- At least one reviewer
- Passing CI required
- Clear PR description
- Screenshots/videos for UI changes
- Migration notes for database changes

---

## 20. License

Private repository. All rights reserved by Jobdun unless stated otherwise.
