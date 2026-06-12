# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Jobdun is a mobile-first job matching and workforce platform for the construction/trades industry. It connects two roles in the mobile app: **Builders** (post jobs, manage applicants) and **Trades/Crews** (browse and apply for jobs, upload verifications). **Admin is a separate web application** — the Flutter app has no admin UI.

- **Framework**: Flutter (Dart `^3.11.5`) — Android and iOS primary targets
- **Backend**: Supabase (Auth, PostgreSQL, Storage, Realtime, RLS, Edge Functions)
- **State management**: Riverpod 3 (`flutter_riverpod`) **only** — no Bloc, no `provider` package, no GetIt
- **Navigation**: GoRouter
- **Architecture**: Feature-first Clean Architecture (see *Engineering Standards (STRICT)* below — non-negotiable)

## Required skills — ALWAYS use (mandatory every session)

These four are non-negotiable on Jobdun. Invoke the relevant one **before** acting, not after. Process skills (superpowers) outrank implementation skills. All four are wired to travel with the repo: `ui-ux-pro-max` + `impeccable` live in `.claude/skills/` (committed), `context7` is project-scoped in `.mcp.json`, superpowers is global.

1. **`ui-ux-pro-max`** (`.claude/skills/ui-ux-pro-max/`) — any UI/UX work: planning, building, reviewing, color, type, layout, motion, spacing. Always pair with `design-system/jobdun/MASTER.md` then the `pages/<page>.md` override (see Design System below).
2. **`impeccable`** (`.claude/skills/impeccable/`) — design-quality / anti-AI-slop pass on every screen. Commands: `/impeccable shape` (plan UX before code), `/impeccable craft` (design-then-build), `/impeccable critique` + `/impeccable audit` (review), then refine with `/impeccable typeset | layout | colorize | animate | polish | distill | clarify | harden`. ⚠️ Flutter caveat: the `npx impeccable detect` CLI + Chrome detector parse web frameworks (TSX/Astro/CSS) and **won't parse Dart** — use the design-thinking commands, not the detector. Use it *together with* `ui-ux-pro-max` (Jobdun design-system knowledge) — they complement, not replace, each other.
3. **`superpowers`** (the `obra/superpowers-marketplace` plugin) — process discipline: `superpowers:brainstorming` before any feature/screen, `:test-driven-development` before code, `:systematic-debugging` before any fix, `:writing-plans` / `:executing-plans` for multi-step work, `:dispatching-parallel-agents` / `:subagent-driven-development` for orchestration, `:verification-before-completion` before claiming done / committing / opening a PR.
4. **`context7`** (MCP, `mcp__context7__*`) — pull version-accurate docs for Flutter, Dart, Supabase, Riverpod, GoRouter, and any package in *Key packages* below **before** relying on API details. Prefer Context7-verified APIs over memory.

Full inventory + plain-English usage: `docs/CLAUDE_SKILLS.md`.

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
- `design-system/jobdun/pages/notifications.md`
- `design-system/jobdun/pages/admin-web.md`
- `design-system/jobdun/pages/applications.md`

**Jobdun design tokens (from MASTER):**
- Background: `#0F172A` (dark slate — NOT white, never `#F8FAFC`)
- Surface: `#1E293B` (cards, inputs, bottom sheets)
- Surface Raised: `#334155` (elevated cards, secondary buttons)
- CTA / Accent: `#F97316` (safety orange — primary action color)
- Primary Text: `#F1F5F9` (on dark backgrounds)
- Secondary Text: `#94A3B8` (labels, hints, metadata)
- Border: `#334155`
- Error: `#EF4444` | Success: `#22C55E`
- Style: Aggressive Flat — dark, heavy weight, no shadows, icon-heavy, all-caps buttons
- Typography: Oswald (headings, display, buttons) + Open Sans (body, captions) via `google_fonts`. Reference: `lib/app/theme/app_theme.dart`.
- Transitions: 150–200ms ease, no bounce/spring
- Anti-patterns: white backgrounds, ghost buttons, soft welcome copy, large SSO buttons, gradients, thin fonts

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

### Admin web app (separate entrypoint)

The admin console is a second Flutter entrypoint in the same repo, isolated under `lib/admin/`. It shares the Supabase project and design tokens with the mobile app but has its own router, login flow, and admin-role gate.

```bash
# Run admin web locally (Chrome)
flutter run -d chrome -t lib/admin/main_admin.dart

# Build admin web bundle (output: build/web/)
flutter build web -t lib/admin/main_admin.dart
```

Admin sign-in uses standard email/password through Supabase. The login service reads `user_role` from the JWT access token (injected by the `custom_access_token_hook`); any account where `user_role != 'admin'` is signed out before the session is returned. Admin role is non-self-assignable in DB (see `supabase/migrations/20260516000002_forbid_self_admin.sql`) — accounts must be promoted via `service_role` SQL.

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

### Engineering Standards (STRICT)

> Enforced by `analysis_options.yaml` (dart_code_linter) **and** `scripts/validate.sh` (file-size budget). Re-read at every Claude session start — these rules override the more permissive language elsewhere in this file.

**File-size budget**
- **Target ≤ 400 LOC** per `.dart` file (excluding `*.g.dart` / `*.freezed.dart` / `test/**`).
- **Hard ceiling: 500 LOC.** New files exceeding 500 LOC fail `scripts/validate.sh` and CI.
- Files currently above the ceiling are listed in `scripts/validate.sh → OVERSIZE_ALLOWLIST` (grandfathered debt). When you touch one of those files, split it before adding more lines — don't grow the allowlist.
- Splitting recipe: page → widgets (`<page>_widgets/`); controller → sub-controllers per bounded sub-domain; state class → its own file in `presentation/state/`.

**No god classes / god controllers**
- Max **10 public methods** per class. If a controller covers multiple bounded sub-domains (e.g. session + Google SSO + Apple SSO + phone OTP + register draft), split it into one notifier per sub-domain.
- Max **4 named parameters** per public method. Wrap larger inputs in a typed payload (`record` or class).
- **Cyclomatic complexity ≤ 10** per method.
- **Maximum nesting level: 3**.

**Riverpod provider rules**
- One state library only: `flutter_riverpod ^3.x`. No Bloc / no `provider` package / no GetIt.
- All controllers extend `Notifier<T>` or `AsyncNotifier<T>` — never legacy `StateNotifier`, never `ChangeNotifier`. The only allowed `ChangeNotifier` is the one GoRouter requires as `refreshListenable` (see `app/router/app_router.dart`).
- **Repo / data-source providers MUST be top-level public** (no leading `_`) so tests can override them via `ProviderScope(overrides: [...])`. Existing private `_xxxRepositoryProvider` declarations are debt — make them public when touched.
- **No direct Supabase from controllers.** A `Notifier` MUST NOT call `SupabaseConfig.client.from(...)` / `Supabase.instance.client...` for reads or writes. Route through the repo. `SupabaseConfig.client.auth.currentUser?.id` is allowed only via a shared `currentUserIdProvider` (add one if missing).
- **Initial-load triggers belong inside `Notifier.build()`** (`Future.microtask(_load)` is the canonical pattern — see `ftue_gate_provider.dart`). New pages MUST NOT add `addPostFrameCallback` solely to call `ref.read(...).loadXxx()` on mount.
- Per-action error/loading: prefer `AsyncValue<T>` returned per action over a single `String? error` + global `bool isLoading` on the state.
- **`.select()` at hot read sites.** Any `Notifier` whose state has > 6 fields requires `ref.watch(provider.select(...))` at every read site outside the owning feature folder.

**Layer rules (Clean Architecture)**
- `presentation/` MUST NOT import `data/` of the same feature directly — it imports `domain/` (entities, repo contracts, use cases). The provider file is the **only** seam that wires `data/` impls into a `Provider<Repository>` / `Provider<Service>`.
- `domain/` MUST NOT import `package:flutter/*`, `package:supabase_flutter/*`, or `core/config/*`.
- If `domain/usecases/<name>.dart` exists, the controller MUST call it — no skipping straight to the repo. **Half-built layers are deleted, not left as documentation.**
- For `currentUser?.id` reads from pages or controllers, use `ref.read(currentUserIdSyncProvider)` (or `readCurrentUserId(ref)`) — never `SupabaseConfig.client.auth.currentUser?.id` directly. The provider is overridable in tests.

**Auth feature exception — `data/services/` instead of `domain/usecases/`**
Auth uses `data/services/` (EmailAuthService, OAuthService, PhoneAuthService, RoleResolver) instead of the use-case-over-repo pattern. Reason: `SupabaseClient.auth` is not a queryable repository — it's a stateful auth client with cancellation, SSO challenges, and SMS round-trips. The repo/use-case indirection adds ceremony without value for these flows. Every other feature uses the use-case pattern; **auth is the documented exception**. Do not introduce `domain/usecases/` or `domain/repositories/auth_repository.dart` for auth — they were deleted as dead scaffold.

**Widget rules**
- One widget per file (`prefer-single-widget-per-file`). Private helper widgets (`class _FooBar extends StatelessWidget`) are allowed *only* if they have a single caller in the same file.
- No methods that return `Widget` (`avoid-returning-widgets`). Extract a private widget class instead.
- No empty blocks (`no-empty-block`).

**Verification**
```bash
bash scripts/validate.sh                # design + file-size + ARCH + format + analyze + tests
bash scripts/check-architecture.sh      # standalone Clean Architecture audit (7 checks)
flutter analyze --no-fatal-infos        # surfaces dart_code_linter INFOs
```

`scripts/check-architecture.sh` is the canonical layer-rules checker — runs domain-purity, layer-boundary, Supabase-isolation, use-case-coverage, repo-pairing, empty-dir, and `currentUserIdSyncProvider` checks. It's invoked by `validate.sh` (pre-push hook) and can be run standalone. Documented exceptions live in `ARCH_SUPABASE_ALLOWLIST` inside the script with a comment justifying each entry.

If a rule blocks legitimate work, propose the exception in the PR description before merging — do not silently disable the linter or grow the allowlist.

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

# Local cache / persistence (Phase 2/2.5 — docs/CACHING_ARCHITECTURE.md)
hive_ce, hive_ce_flutter   # disk-backed CacheStore (lib/core/cache/): stale-while-
                           # revalidate + offline last-known, bounded + encrypted at rest
flutter_secure_storage     # holds the Hive AES key in Keychain/Keystore (Phase 2.5)

# === UI/UX — Animations & Motion ===
flutter_animate    # composable widget animations (.animate().fadeIn().slideY())
lottie             # Lottie JSON animations — use for empty states, success, loading
animations         # Material motion transitions (SharedAxis, FadeThroughTransition)

# === UI/UX — Typography & Icons ===
google_fonts       # Inter / Poppins — use via AppTheme.textTheme
flutter_svg        # SVG rendering for illustrations and custom icons
phosphor_flutter   # Phosphor icon set (Bold = default/outline, Fill = active) — wired through `lib/core/theme/app_icons.dart`

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
- **Icons**: always reference `AppIcons.*` from `lib/core/theme/app_icons.dart` — the single point of contact with `phosphor_flutter`. Feature code must NOT import `phosphor_flutter` or reference `PhosphorIconsBold.*` / `PhosphorIconsFill.*` directly. Bold weight = default/outline/inactive; Fill weight = active/selected and critical alerts. Fall back to `Icons.*` only for Material-specific cases.
- **Fonts**: configure `google_fonts` in `AppTheme` (e.g. Inter for body, Poppins for headings) — never call `GoogleFonts.*` per-widget.
- **Animations**: wrap any list of 4+ items with `JStaggeredList` (`lib/core/design/widgets/j_staggered_list.dart`) — 200ms fade-slide is the house pattern. For sliver-based screens use `JStaggeredSliverList`. Use `flutter_animate` for one-off micro-interactions (fade, slide, scale). Never call `AnimationLimiter` / `AnimationConfiguration` directly in feature code.
- **Loading**: use `JSkeletonList` (`lib/core/design/widgets/j_skeleton_list.dart`) for content-shaped loading — wrap real-shaped widgets fed with placeholder data. Never use raw `CircularProgressIndicator` / `LinearProgressIndicator` for list or page-body loading. Keep spinners only for overlay/inline progress (avatar upload, recenter button). Use `shimmer` for image placeholders inside `CachedNetworkImage`.
- **Progress bars**: use `LinearPercentIndicator` / `CircularPercentIndicator` from `percent_indicator` for any progress with a real percentage. Never wrap a raw `LinearProgressIndicator` for that purpose.
- **Empty states**: pair a Lottie animation + headline + CTA — never show a blank screen.
- **Bottom sheets**: use `showJSheet` from `lib/core/design/widgets/j_bottom_sheet.dart`. Never call `showModalBottomSheet` directly — Flutter's built-in lacks iOS drag-to-dismiss physics and breaks consistency.
- **Swipe actions**: wire row-level destructive/state-change actions through `flutter_slidable`. Always call `HapticFeedback.lightImpact()` inside `SlidableAction.onPressed` so the confirm feels physical. Per-side state (archive, mute) must persist server-side — see `supabase/migrations/20260520000004_swipe_actions.sql` for the conversation/saved-jobs schema pattern.
- **Image uploads**: always pipe `image_picker` through `ImageUploadService.pickCropCompress` (`lib/core/services/image_upload_service.dart`). Pick the right `ImageAspect` — `square` (avatars/logos), `portfolio` (4:3), `free` (verification docs). Never call `ImagePicker().pickImage` directly from feature code.
- **Image viewers**: use `photo_view` (`PhotoView` or `PhotoViewGallery.builder`) for any tap-to-enlarge surface (portfolio thumbs, verification docs, message attachments). Wrap the thumb in a `Hero(tag: '<feature>:<id>')` so the transition flows.
- **Long-list pagination**: feeds that can grow past ~50 rows (jobs feed, future search results) must use `infinite_scroll_pagination`'s `PagedListView` driven by a controller-owned `PagingController`. Page size = 20, prefetch threshold default. Provide first-page `JSkeletonList` indicator + empty-state CTA + tap-to-retry error indicator. Wrap in a `RefreshIndicator` calling `pagingController.refresh()`. Repository methods must accept optional `limit` + `offset`; one-shot fetches (use cases, home mini-feeds) pass null to disable pagination.
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

## CI/CD

### Run validation locally

```bash
# Fast checks — design system + format + lint + tests (~60s)
bash scripts/validate.sh

# Full check including debug APK build (~5 min)
FULL=1 bash scripts/validate.sh
```

### Install the pre-push hook (run once after cloning)

```bash
bash scripts/install-hooks.sh
```

After installation every `git push` automatically runs `bash scripts/validate.sh` (without `FULL=1`).

### GitHub Actions

| Workflow | File | Triggers | What it does |
|----------|------|----------|--------------|
| CI | `.github/workflows/ci.yml` | Push/PR to `main` or `develop` | Design checks, format, lint, tests, coverage |
| CD | `.github/workflows/cd.yml` | Push to `main` only | CI checks + release APK artifact (7-day retention) |

### Required GitHub Secrets

Add in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `SUPABASE_URL` | Supabase project URL (e.g. `https://xxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |

`GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID` are intentionally left empty in CI — Google Sign-In is not exercised in tests.

### What `scripts/validate.sh` checks

**Design system (grep-based, ~1s):**
- No `GoogleFonts.*` outside `lib/app/theme/app_theme.dart`
- No `Colors.white` without `// intentional` comment in `lib/features/`
- No raw `SizedBox(width:/height:` spacing in `lib/features/` — use `Gap(n)` instead
- No hardcoded `Color(0xFF...)` in `lib/features/`
- No inline gradient (`colors: [Color` / `colors: [Colors`) in `lib/features/`
- No `AppColors.*` static references in `lib/features/`

**Flutter (~30–60s):**
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --no-fatal-infos`
- `flutter test --coverage`

**Build (optional, `FULL=1` only, ~5 min):**
- `flutter build apk --debug --no-pub`
