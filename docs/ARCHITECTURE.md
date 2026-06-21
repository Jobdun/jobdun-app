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
| Maps | `flutter_map` + Carto raster tiles (no Google Maps key required) |
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

`f474d2e` — *Merge PR #4: feat/trade-credentials-trust-layer*. Prior commits close
out Android Play store blockers (`dc11e91`), PII visibility split (`41e3212`,
F-RLS-03), schema-drift CI job, and the Flutter 3.41.7 pin. App is store-ready on
the Android side; iOS work ongoing.
