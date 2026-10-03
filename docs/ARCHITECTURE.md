# Architecture — Jobdun (current state)

> Project-wide architecture reference. Pairs with [`CLAUDE.md`](../CLAUDE.md)
> (canonical rules, skills, commands) and [`AGENTS.md`](../AGENTS.md) (skill
> index). Read `CLAUDE.md` first for opinions and commands; this file documents
> *what is wired today, where the secrets sit, and the architectural shape* of
> the repo. Keep this in sync when features land, packages change, or the
> branch / store-readiness state shifts.

## What this is

- **Jobdun** — Flutter mobile app (Android + iOS) for the Australian construction
  trades workforce. Builders post jobs; trades/crews apply. Supabase backend.
- **Repo identity** — `au.com.jobdun.app` (Play package, renamed from
  `com.example.jobdun` on 2026-06-11, before first store upload).
- **Branch state** (as of session start):
  - `main` — production-ready, up to date with `origin/main` (HEAD `f474d2e`).
  - `develop` — **behind `main` by 1 commit** (`origin/main...origin/develop`
    shows `0` ahead / `1` behind — develop is a strict subset of main). Treat
    `main` as the latest. Work branches from `main` per `CLAUDE.md` branch
    strategy.
  - Working tree clean. No uncommitted edits.
- **Admin app** — separate Flutter web entrypoint at `lib/admin/main_admin.dart`,
  shares the same Supabase project + design tokens.

## Tech stack (pinned)

| Layer | Choice |
|---|---|
| Flutter | Dart `^3.11.5` (CI pins Flutter `3.41.7` — floating stable broke `phosphor_flutter` on 3.44) |
| Backend | Supabase (Auth + Postgres + Storage + Realtime + RLS + Edge Functions) |
| State | `flutter_riverpod ^3.3.1` — `Notifier` / `AsyncNotifier` only, no Bloc, no `provider` |
| Routing | `go_router ^17.2.3` |
| Auth | Supabase Auth — email/password, phone OTP, Google SSO, Apple SSO |
| Push | FCM via `firebase_core ^4.10.0` + `firebase_messaging ^16.3.0` |
| Maps | `flutter_map` + MapTiler raster tiles via `JBasemap` (`lib/core/design/widgets/map/j_basemap.dart`); reuses `MAPTILER_API_KEY`, falls back to key-less OpenStreetMap. **Not Carto** — it watermarks unauthenticated tiles "API KEY REQUIRED" (swapped 2026-08-30) |
| Geocoding | MapTiler REST (`JPlaceField`) |
| Cache | `hive_ce` + `flutter_secure_storage` (AES key in Keychain) |
| Observability | `sentry_flutter` (inert when `SENTRY_DSN` empty) |

## Features (lib/features/)

`auth`, `profile`, `jobs`, `applications`, `messaging`, `verification`, `reviews`,
`notifications`, **plus** the newer surfaces: `discovery`, `ftue`, `home`, `legal`,
`quotes`, `scheduling`, `timesheets`. Each is feature-first Clean Architecture
(`data/` → `domain/` → `presentation/`), domain is Flutter-/Supabase-free.

## Secrets & environment

| File | Status | Notes |
|---|---|---|
| `.env` (root) | **Present** | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `MAPTILER_API_KEY`. Loaded via `flutter_dotenv`. |
| `.env.example` | Present | Template; `SENTRY_DSN` left blank intentionally (Sentry no-ops without it). |
| `android/app/google-services.json` | **Placed this session** | FCM config for project `jobdun-627d2` (number `960216655470`). Two client entries: production `au.com.jobdun.app` + legacy `com.example.jobdun`. `android/settings.gradle.kts:24` already applies the `com.google.gms.google-services` plugin; `android/app/build.gradle.kts:10` applies it for the app module. **No native Firebase init code is required** — `firebase_core` picks this file up at build time. |
| `android/key.properties` | Gitignored | Release signing config (see `docs/RELEASE_SIGNING.md`). Falls back to debug signing when absent. |
| Supabase JWT custom hook | External config | Must be enabled in Supabase Dashboard → Auth → Hooks → select `public.custom_access_token` — injects the `user_role` claim. |

## Architecture rules (non-negotiable, see CLAUDE.md §Engineering Standards)

- File-size budget: **target ≤ 400 LOC, hard ceiling 500 LOC**. Oversize files
  live in `scripts/validate.sh → OVERSIZE_ALLOWLIST` and must be split when touched.
- Riverpod: `Notifier` / `AsyncNotifier` only; no `StateNotifier`, no `ChangeNotifier`
  (except the one GoRouter requires). Repo providers **must be public** (no `_`)
  so tests can override. No `SupabaseConfig.client.from(...)` inside notifiers —
  route through repos; use `currentUserIdSyncProvider` for `auth.currentUser?.id`.
- Layers: `presentation/` imports `domain/`; only the provider file wires `data/`
  impls in. `domain/` must not import Flutter, Supabase, or `core/config/*`.
- **Auth exception** — uses `data/services/` (Email/OAuth/Phone/RoleResolver),
  not use-cases-over-repo. Don't reintroduce `auth_repository.dart`.
- One widget per file; no method-returning-`Widget`; ≤ 10 public methods per class;
  ≤ 4 named params per method; cyclomatic ≤ 10; nesting ≤ 3.
- Use cases return `Future<Either<Failure, T>>` (fpdart).

## Validation (run before claiming done)

```bash
bash scripts/install-hooks.sh    # one-time: pre-push runs validate.sh
bash scripts/validate.sh         # design + format + lint + tests (~60s)
FULL=1 bash scripts/validate.sh  # + debug APK build (~5 min)
bash scripts/check-architecture.sh   # standalone Clean Arch audit
```

## Skills wired for this repo (`.claude/skills/`)

- `ui-ux-pro-max` — design system, palettes, components.
- `impeccable` — anti-AI-slop design pass (Flutter caveat: `npx impeccable detect`
  parses TSX/Astro/CSS only — use the design-thinking subcommands, not the detector).
- `play-review-check`, `app-store-review-check` — store-readiness audits.

Read `CLAUDE.md → Required skills` for the full set, including `superpowers` and
`context7` (MCP).

## Common pitfalls (from recent commits)

- `flutter_dotenv` throws `EmptyEnvFileError` if `.env` is empty — keep a non-empty
  stub committed (or rely on the one currently in place).
- `flutter_secure_storage 10.x` needs `minSdk ≥ 23` — `build.gradle.kts:44` raises
  the floor above Flutter's default 21.
- `google-services.json` is **gitignored** (`.gitignore:45`) — must be placed on
  each clone for FCM to work. **Done this session.**
- `phosphor_flutter` version is sensitive to Flutter SDK — CI pins `3.41.7`.
- `appColor(0xFF...)`, `AppColors.*`, `Colors.white` (without `// intentional`),
  inline gradients, raw `SizedBox(width:/height:)`, and `GoogleFonts.*` outside
  `lib/app/theme/app_theme.dart` are all rejected by `validate.sh` in `lib/features/`.

## Last release-related work

### 2026-10-03 — shared mobile fixes and API verification

Source version is `1.0.3+13`. Shared Flutter fixes cover job-feed error/loading
states, accessible back navigation, role-aware profile completion and banner
copy, account-scoped messaging/notifications, and idempotent image retry. These
implementations are shared by Android and iOS; native runtime parity still
requires platform-specific testing. The iOS foreground-only location build
configuration is included.

The October 3 local validation and three Deno feed tests passed. Live API
checks were read-only and anonymous; authenticated paired-user lifecycles and
full RLS coverage remain pending. See
`docs/verification/2026-10-01-android-audit/report.md` for scope and limitations.

The current admin site is Next.js on Vercel, maintained in the separate
`admin-web` repository (intentionally ignored here). Its clean local checkout
matches GitHub commit `a5d3f5f`; this does not establish the deployed commit.
The old Flutter admin entrypoint and `scripts/deploy-admin.sh` remain legacy
code, not the deployment path for the observed live admin site.

### 2026-09-15 — apprenticeship vacancies and hiring

Apprenticeship vacancies now use `jobs.job_kind = apprenticeship`, separately
from ordinary trade jobs that invite apprentices. Dedicated apprenticeships
require employer-set, positive finite hourly pay and `open_to_apprentices`.
Creation, public browse, search filters, saved/home/builder cards, job details,
applications and applicant review carry this distinction. Invited apprentices
apply with their profile/resume; qualified trades retain quotes on trade jobs.
Apprentice profile completeness uses trade, about, resume, portfolio and suburb;
site tickets and apprenticeship stage remain optional.

Production migrations `20260915000001`–`20260915000003` and the updated
`jobs-feed` Edge Function are deployed. Database triggers enforce application
transitions and lock the vacancy while hiring, so competing hires cannot both
succeed. A hired trade declining reopens their assigned vacancy. Public views
retain their explicit privacy-safe projections. The schema snapshot is current.

Signed Android `1.0.3+9` is built and its manifest/upload certificate verified.
Full validation and Android screenshot capture pass. iOS build 9 uploaded,
then received ITMS-90683 for geolocator's unused always-location API. The
Podfile now compiles that API out with `BYPASS_PERMISSION_LOCATION_ALWAYS=1`;
source version is `1.0.3+10`. The exported build 10 IPA passes
`scripts/check_ios_location_permissions.py` and uploaded successfully to Apple;
processing/review remains pending. See the September 15 store
submission record for upload status. Play Store upload and
publication are **not performed**.
Work remains uncommitted on `feat/ui-refresh-figma-2026-08-28`, preserving the
existing September 7 edits. See the September 15 verification record for final
build and validation evidence.

### 2026-09-07 — apprentice production schema

Production `zethpanvkfyijislxesn` now has migrations `20260831000001` through
`20260831000005`, applied with the authenticated Supabase CLI after a dry run
and a schema-only backup. Live SQL and REST checks confirmed the five apprentice
columns on `trade_profiles`, `jobs.open_to_apprentices`, nine `site_tickets`
rows with RLS, and the relationship-gated resume storage policy.
`search_trades` accepts both legacy calls and the new apprentice argument;
`authenticated` can execute it, `anon` cannot (REST returns 401).

Live-app verification then caught missing projections beyond the original five
migrations. `20260907000001` adds the invitation flag to `jobs_public_browse`;
`20260907000002` adds apprentice identity/stage/tickets to
`trade_profiles_public`, preserving document/address privacy. The `jobs-feed`
Edge Function was redeployed with the same flag, and its projection test now
reads the real Dart source instead of comparing two stale copies.

The implemented model uses `apprenticeship_stage`, a `site_tickets` array, and
`resume_uploaded_at`. Neither `apprenticeship_started_at` nor a `trade_tickets`
table is referenced by this app or created by these migrations. Earlier release
notes listing them as required schema were inaccurate.

`supabase/schema.sql` was refreshed from production. The full validation suite
passes, including the corrected navigation/header expectations and the refreshed
builder-profile golden. `validate.sh` now runs all test directories.

Signed Android AAB and iOS IPA builds of `1.0.2 (8)` completed against production.
The iOS upload to App Store Connect succeeded; store publication is pending. See
`docs/verification/2026-09-07-production-release.md` for submission status.

`f474d2e` — *Merge PR #4: feat/trade-credentials-trust-layer*. Prior commits close
out Android Play store blockers (`dc11e91`), PII visibility split (`41e3212`,
F-RLS-03), schema-drift CI job, and the Flutter 3.41.7 pin. App is store-ready on
the Android side; iOS work ongoing.
