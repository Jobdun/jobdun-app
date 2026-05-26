# Jobdun — W1–W3 Reality Check

> **Last verified:** 2026-05-22 on branch `docs/location-picker-audit` (re-checked after Sentry + CI format + analysis_options docs landed).
> Symbols below mean: ✅ verified in code, ❌ not present, ⚠️ partial / different from spec, ❓ can't verify without live DB / runtime.
> W1, W2, and W3 are all audited against the actual codebase below.

---

## TL;DR for the lead (W1 → W3 status)

**Solid foundations (W1 + W2)**
- Clean Architecture scaffold, Riverpod ProviderScope at root, GoRouter with auth-aware redirect (`splash → ftue → login → home` + `verify-email` lockout), theme tokens (colors / spacing / radii / motion / gradients), error architecture (`Failure` + `ErrorMessages.from` maps Supabase errors → plain English).
- **Sentry now fully wired** — `sentry_flutter ^8.10.1` in `pubspec.yaml`, `SentryFlutter.init` in `main.dart` (catches unhandled async + build-phase errors), custom dark `ErrorWidget.builder` for release builds, and a `SentryReporter` wrapper at `lib/core/errors/sentry_reporter.dart` that's already consumed by `auth_provider.dart:134` and `profile_provider.dart:210` for explicit handled-error capture with tags. DSN is read from `AppEnv.sentryDsn` — Sentry no-ops cleanly when empty.
- **CI now enforces formatting** — `Check formatting: dart format --output=none --set-exit-if-changed .` runs before analyze + test (`.github/workflows/ci.yml:28-29`), mirroring `scripts/validate.sh` so the pre-push hook and CI give identical feedback.
- Env handled via `--dart-define` with `dotenv` fallback (`core/config/env.dart`); `service_role` never touched by the app.
- Auth: email/password, password reset, email verification, phone OTP, Google + Apple SSO, `signOut`, and `onAuthStateChange` listener that drives router refresh — all present.
- Role lockdown is **strong**: signup trigger refuses `admin`, an `UPDATE` trigger forbids role mutation from anyone but `service_role`, and every change is logged in `user_role_events`.
- ToS / Privacy Policy acceptance recorded with version + timestamp (`legal_acceptances`).

**Solid foundations (W3)**
- Builder + trade profile tables, `trade_categories` reference, profile pages, edit, validation.
- Storage buckets exist (`public-media`, `private-docs`) with owner-path RLS on `storage.objects`.
- `verification_documents` schema is rich — full audit columns (`expiry_date`, `reviewed_by`, `reviewed_at`, `review_notes`, `deleted_at`) after the schema-reconciliation migration.
- Trade upload screen (`verification_page.dart`) is wired end-to-end with image crop + JPEG compression.
- CI runs `flutter analyze` + `flutter test test/features/` on every PR.

**Gaps that need a decision before next sprint** (combined W1–W3)
1. **No upload guard-rails.** No max-file-size, no MIME allowlist, no retry/backoff. Anything `image_picker` returns goes through.
2. **No `feature_flags` table** (and no PostHog wiring).
3. **No expiry-reminder job** (Edge Function + cron) for verification docs — column captured, notifications not built.
4. **No soft delete on `builder_profiles` / `trade_profiles`.** Only `jobs`, `messages`, `verification_documents` have `deleted_at`.
5. **Schema drift vs. plan column names.** `trade_profiles` uses `full_name` / `primary_trade` (text) — not `display_name` / FK to `trade_categories`; no `licence_number` column (licences live in `verification_documents`); no plain `location` text column (the `places_columns` migration adds Google-Places fields).
6. **Bucket names differ from plan.** Plan says `avatars` / `portfolio` / `verification_docs`; actual is `public-media` + `private-docs`. Not wrong, just different.
7. **Admin review screen is out of scope for the Flutter app** (CLAUDE.md: admin is a separate web app). Plan's "Admin review screen exists" line is unmet in this repo *by design*.
8. **JTextField primitive exists but isn't used everywhere.** Raw `TextField` / `FormBuilderTextField` still appears in ~10 screens (`phone_auth_page`, `profile_edit_page`, `trade_category_picker`, `job_detail_page`, `jobs_page`, `message_thread_page`, etc.). Not a bug — a consistency debt.
9. **No explicit 44pt touch-target enforcement** in the global theme (no `MaterialTapTargetSize` / `minimumSize` set centrally). May still be fine per-widget; needs a contrast + tap-target audit pass.
10. **No env split (dev/staging/prod).** `env.dart` reads one `SUPABASE_URL` / `SUPABASE_ANON_KEY` from a single `.env` + `--dart-define`. No staging vs. prod separation in the build pipeline.
11. **No shadow-Supabase migration job in CI.** Migrations are not exercised in CI before merge.
12. **`analysis_options.yaml` is intentionally default `flutter_lints`** — the upgrade to `very_good_analysis` is deferred to a focused cleanup sprint (per the new file header comment), and the dart-metrics linter (`dart_code_linter`) was archived by its maintainer in 2024 so strict-metrics rely on code-review + `scripts/validate.sh` for the 500-LOC ceiling. Worth knowing — not a "bug".
13. **No admin RLS policy on `verification_documents`** — only owner-row policies (`select_own`, `insert_own`, `update_own`). The admin web app will need either a `service_role` Edge Function or a `WHERE EXISTS (… user_roles role='admin' …)` policy to read/approve/reject.
14. **No `Sentry.setUser(...)` on sign-in** — captured events therefore carry no `user_id`. Add a one-liner inside `_loadRoleForCurrentUser` / the auth listener so events are user-attributed.
15. **No index on `trade_profiles.primary_trade`** — category-based queries will table-scan. (Lat/lng indexes for the home map already exist.)

**Recently closed** ✅ (since the first audit)
- Sentry installed + wired in `main.dart`, with `SentryReporter` helper, custom release-mode error widget, and consumers already in `auth` + `profile` providers.
- CI now runs `dart format --output=none --set-exit-if-changed .` before analyze + test.
- `analysis_options.yaml` now carries a deliberate, documented rationale for staying on `flutter_lints` (previously read as "missing config").

---

## W1 — Architecture & Setup
### Flutter app
- [x] ✅ Feature-first Clean Architecture — `lib/features/{auth,profile,jobs,applications,messaging,verification,ftue,home,legal,notifications,reviews}/` each with `data/ domain/ presentation/`.
- [x] ✅ Riverpod ProviderScope at root — `lib/main.dart:30-37` (overrides only for the persisted theme).
- [x] ✅ GoRouter with auth-aware redirect — `lib/app/router/app_router.dart:50-110` handles FTUE, splash, public routes, pending email verification, and auth-only pages.
- [x] ✅ Theme tokens defined — `lib/app/theme/` has `app_colors.dart`, `app_radii.dart`, `app_spacing.dart`, `app_motion.dart`, `app_gradients.dart`, `app_theme.dart`.
- [ ] ⚠️ JTextField primitive built **but not used everywhere**. Raw `TextField` / `FormBuilderTextField` appears in `phone_auth_page.dart:402`, `profile_edit_page.dart:617`, `trade_category_picker.dart:310/479`, `job_detail_page.dart:442/468`, `jobs_page.dart:146`, `message_thread_page.dart:299`, `profile_location_field.dart:222`, `job_location_field.dart:132`.
- [x] ✅ Formatter / validator utilities — `lib/core/utils/app_date_utils.dart`, `string_utils.dart`, `validators.dart` (includes 11-digit **ABN validator** at `validators.dart:29-33`), `lib/core/validators/phone_validator.dart`.
- [x] ✅ Error architecture: `lib/core/errors/{exceptions,failures,error_messages,sentry_reporter}.dart` — `Failure` types + `ErrorMessages.from` mapper + `fpdart` Either. **Top-level error boundary now in place** via custom `ErrorWidget.builder` in `main.dart:34-104` (dark fallback in release, default red/yellow in debug). `SentryFlutter.init` also hooks `FlutterError.onError` + `PlatformDispatcher.onError` for unhandled async/zone errors.
- [x] ✅ Sentry SDK installed — `sentry_flutter: ^8.10.1` in `pubspec.yaml:135`. DSN wired via `AppEnv.sentryDsn` (`core/config/env.dart:65`); init in `main.dart:41` uses the `appRunner` pattern so the app launches even when the DSN is blank (no-op). ❓ "Test crash visible in dashboard" — needs a live verification run with a real DSN.

### Repo + CI
- [x] ✅ `.gitignore` excludes `.env*`, `/build/`, `*.key`, `*.pem`, `client_secret_*.json`, `*.p8`, OAuth plists.
- [x] ⚠️ `analysis_options.yaml` deliberately stays on default `flutter_lints` for now. The file's own header comment explains why: `dart_code_linter` was archived by its maintainer in 2024, modern alternatives (`very_good_analysis`, `solid_lints`) cover style but not the configurable file-size / complexity / nesting / param-count metrics CLAUDE.md asks for, and adopting `very_good_analysis` today would surface 100+ pre-existing infos. The 500-LOC hard ceiling is enforced by `scripts/validate.sh` (pre-push hook + CI); other strict-metrics rules are reviewer-enforced.
- [x] ✅ CI runs **`dart format --output=none --set-exit-if-changed .`** (`.github/workflows/ci.yml:28-29`) + `flutter analyze --no-fatal-infos` + `flutter test test/features/` on push/PR to `main`/`develop`.
- [ ] ⚠️ Env management — `lib/core/config/env.dart` reads ONE `SUPABASE_URL` + `SUPABASE_ANON_KEY` (dotenv + `--dart-define` fallback). No dev/staging/prod split in the build pipeline.
- [x] ✅ No `service_role` in the app — only two grep hits, both comments explaining what `service_role` *can* do server-side.

### Supabase
- [ ] ❓ Project tier (Free vs. Pro) — not visible from code.
- [x] ✅ Migrations folder set up & versioned — `supabase/migrations/` has 25 timestamped migrations.
- [ ] ❌ CI does NOT run migrations against a shadow Supabase project — `ci.yml` only runs Flutter analyze + test.
- [x] ⚠️ Baseline `profiles` table exists. Role lives in a **separate `user_roles` table** (not a column on `profiles`) with `CHECK (role IN ('builder','trade','admin'))`. `supabase/migrations/20260511000001_initial_schema.sql:19-23`.
- [ ] ❓ Zero tables without RLS — every migration calls `ENABLE ROW LEVEL SECURITY`, but confirming requires `SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=false;` against the live DB.

---

## W2 — Auth (all 3 roles)
### Flows
- [x] ⚠️ Create account: role + name + email + password is a **two-step wizard** in `register_page.dart` (step 1 = role picker unless `?role=` deep-link skips it, step 2 = credentials). Plan asked for a single screen — this is a deliberate split, not broken, but flag it.
- [x] ✅ "Create account" / "Log in" vocabulary — `login_page.dart:339-372` uses "Create account →". No user-facing "Sign in" / "Sign up" copy.
- [x] ✅ Email verification — `lib/features/auth/presentation/pages/verify_email_page.dart` + router lockout when `pendingVerificationEmail != null` (`app_router.dart`).
- [x] ✅ Password reset — `email_auth_service.dart:50` calls `resetPasswordForEmail`; UI at `forgot_password_page.dart`.
- [x] ✅ Sign out — `auth_provider.dart:480-482` calls `_email.signOut()`; logout sheet at `logout_confirm_sheet.dart`.
- [x] ✅ Auth state listener drives router refresh — `auth_provider.dart:66` subscribes to `client.auth.onAuthStateChange`; router uses `refreshListenable: notifier` (`app_router.dart:48`).

### Role handling
- [x] ✅ Role asked **once** — `register_page.dart` shows the role picker only when no role is already in `registerDraft` or `?role=` query param.
- [x] ✅ Role immutable client-side — `user_roles_update_own` RLS policy was **dropped** (`20260520000001_lock_user_role.sql:21`) AND a `BEFORE UPDATE` trigger raises `42501` on role change unless caller is `service_role`.
- [x] ✅ Admin role can only be set via Edge Function — `handle_new_user` ignores `admin` from client metadata (`20260516000002_forbid_self_admin.sql`); `forbid_self_admin` trigger blocks any non-superuser admin INSERT. Lifecycle audited in `user_role_events` (`20260520000002_role_audit_log.sql`).

### Security
- [x] ✅ RLS on `profiles` — `profiles_select_own`, `profiles_insert_own`, `profiles_update_own` (`20260511000006_rls.sql:15-42`). ⚠️ **No public-SELECT-on-non-PII policy** — public reads go through `builder_profiles` / `trade_profiles` (`select_authenticated`), so display name and avatar are not publicly readable to anon callers.
- [x] ✅ Password min length + strength check — `minLength(8)` + a custom `_strongPasswordValidator` + `_passwordStrength(pw)` classifier + live `_PasswordStrengthBar` widget. `register_page.dart:501, 588-595, 742-790`.
- [x] ✅ Auth errors mapped to plain English — `lib/core/errors/error_messages.dart` maps "invalid credentials" → "Incorrect email or password", "email not confirmed", "user already registered", "password too short", "rate limit", "network" cases.
- [x] ✅ ToS + Privacy Policy acceptance — `legal_acceptances` table with `(user_id, document_type, document_version, accepted_at, app_version)`, RLS read-own + admin-read-all, no UPDATE/DELETE policy (immutable). `supabase/migrations/20260512000001_legal_acceptances.sql`. Tests: `test/features/legal/legal_test.dart`.

### Quality
- [ ] ❓ WCAG AA contrast — no automated contrast check found; needs manual audit. Brand spec (`CLAUDE.md` design tokens) uses `#F1F5F9` on `#0F172A` (passes AA at body sizes).
- [ ] ❌ 44pt+ touch targets — no `MaterialTapTargetSize` / `minimumSize` enforced in `app_theme.dart`. Per-widget compliance not verified.
- [x] ⚠️ Sentry captures auth failures — `auth_provider.dart:134` calls `SentryReporter.reportError(e, stackTrace, tags)` with `{feature: 'auth', action: <signIn/register/oauth/otp>}`. Unhandled auth exceptions also flow via the `SentryFlutter.init` zone hook. **Missing:** `Sentry.configureScope((s) => s.setUser(...))` is not called on sign-in (grep returns zero hits), so captured events do **not** carry `user_id`. Route tag is also not set.

---

## W3 — Profiles + Uploads + Verification (start)

### Builder & Trade profiles
- [x] ✅ `builder_profiles` table exists — `company_name`, `abn`, `logo_url`, `description`, `created_at`, `updated_at`. `supabase/migrations/20260511000001_initial_schema.sql:30-39`. ⚠️ **MISSING:** `location`, `contact`, `deleted_at`.
- [x] ⚠️ `trade_profiles` table exists — `full_name`, `primary_trade` (text), `is_verified`, `bio`, `portfolio_urls`, `hourly_rate`, `day_rate`, `years_experience`. `supabase/migrations/20260511000001_initial_schema.sql:43-56`. **Plan drift:** uses `full_name` instead of `display_name`, no `licence_number` column (licences live in `verification_documents`), no `location` text column (place fields added in `20260522000001_places_columns.sql`), no `deleted_at`.
- [x] ✅ `trade_categories` reference table seeded with 19 canonical categories. `supabase/migrations/20260512000003_trade_categories.sql`. ⚠️ `trade_profiles.primary_trade` is `text` — not an FK; `trade_other` column captures custom entries.
- [x] ✅ RLS on `builder_profiles` / `trade_profiles`: authenticated SELECT, owner INSERT/UPDATE. `supabase/migrations/20260511000006_rls.sql:79-132`.
- [x] ⚠️ Indexes — `places_columns` migration adds **`idx_trade_profiles_base_latlng (base_latitude, base_longitude)`** and `idx_builder_profiles_service_latlng`. ❌ **No index on `trade_profiles.primary_trade`** — category filtering will table-scan.
- [x] ✅ Profile view screen — `lib/features/profile/presentation/pages/`.
- [x] ✅ Profile edit screen with validation — `profile_edit_page.dart`.
- [ ] ❌ Soft delete (`deleted_at`) on profile tables — not present. Only `jobs`, `messages`, `verification_documents` have it.

### Photo & file uploads
- [x] ⚠️ PUBLIC bucket exists as `public-media` (combines avatars + portfolio), not separate `avatars` / `portfolio`. `supabase/migrations/20260511000006_rls.sql:358-362`.
- [x] ✅ PRIVATE bucket `private-docs` for verification. `supabase/migrations/20260511000006_rls.sql:401-405`.
- [x] ✅ RLS on `storage.objects` for both buckets: writes scoped to `auth.uid()` folder path. `20260511000006_rls.sql:364-435`.
- [x] ✅ Client-side image crop + JPEG compression (`compressQuality: 88`). `lib/features/verification/presentation/pages/verification_page.dart:44-48`, `portfolio_strip.dart:18`.
- [ ] ❌ File type allowlist enforced client AND server — **not found**. Relies on `image_picker` defaults; no Edge Function / DB trigger.
- [ ] ❌ Max file size enforced (e.g., 5MB hard cap) — **no `maxFileSize` / size check** found in profile or verification code.
- [ ] ❓ Upload progress UI — not verified.
- [ ] ❌ Retry with exponential backoff + jitter — **not found** in feature code or `core/`. Only places-service mentions retry, not uploads.
- [ ] ❌ Sentry breadcrumb on upload failure — Sentry is not installed.

### Verification + expiry reminders (start)

> **Direction change (2026-05-25):** verification is moving from "upload doc → admin reviews" to **API-first against ABR + state regulators**, with manual upload kept only as a fallback. The pending items below are still accurate for the *current* manual flow, but the forward plan, schema, and phase ordering live in `docs/VERIFICATION_AUDIT.md`. Treat that doc as the source of truth for product direction; this section remains the audit of what is in the repo today.

- [x] ✅ `verification_documents` table with all audit columns: `doc_type`, `file_path`, `submitted_at`, `state`, `issuer`, `document_number`, `issued_date`, `expiry_date`, `rejection_reason`, `review_notes`, `reviewed_by`, `reviewed_at`, `deleted_at`, status enum (`pending`/`approved`/`rejected`/`expired`). `supabase/migrations/20260511000005_social.sql:23-37` + `20260516000001_schema_reconciliation.sql:20-37`.
- [x] ⚠️ RLS: owner SELECT/INSERT/UPDATE own rows only. `20260511000006_rls.sql:309-329`. ❌ **No admin SELECT-all or admin UPDATE-status policy** on `verification_documents` — review/approve/reject from the admin web app will need either a service-role Edge Function or a new policy keyed off `user_roles.role = 'admin'`.
- [x] ✅ Trade profile screen has upload entry point — `lib/features/verification/presentation/pages/verification_page.dart`.
- [ ] ❌ Admin review screen — **not in this repo** (CLAUDE.md: "Admin is a separate web application — the Flutter app has no admin UI"). Out of Flutter scope by design.
- [ ] ❌ Approve/reject flow — same as above, lives in the admin web app, not this repo.
- [x] ✅ `expiry_date` column captured at upload (manual entry; no OCR yet). `20260516000001_schema_reconciliation.sql:31`.
- [ ] ❌ Scaffold for expiry reminder job (Edge Function + cron) — not present in `supabase/` (no functions folder visible; only `migrations`, `email-templates`, `snippets`).

---

## Cross-cutting (must be true by end of W3)
- [ ] ❓ Zero tables without RLS — every migration uses `ENABLE ROW LEVEL SECURITY`, but to confirm zero gaps you must run `SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=false;` against the live DB.
- [x] ⚠️ Sentry dashboard shows real events — SDK + init + reporter wrapper are all in place (`sentry_flutter ^8.10.1`, `main.dart:41`, `core/errors/sentry_reporter.dart`). Final "events visible" verification needs a real DSN + a live build firing a test crash.
- [x] ✅ Status fields are enums or CHECK constraints — `document_status` enum, `user_roles.role` CHECK constraint, jobs / applications status enums.
- [x] ✅ No `service_role` usage in the app — only two grep hits, both in comments explaining what `service_role` *can* do server-side. `lib/features/auth/data/services/role_resolver.dart`, `lib/features/profile/data/datasources/profile_remote_datasource.dart`.
- [x] ✅ Smoke tests covering signup, login, profile create, file upload — 28+ test files under `test/features/` (auth, profile, applications, jobs, legal, ftue) + integration `rbac_test.dart`.
- [ ] ❌ `feature_flags` table or PostHog wired — **neither** present in migrations or pubspec.

---

## Evidence cheat-sheet (for the lead deck)

| Claim | Where to look |
|---|---|
| Buckets + RLS | `supabase/migrations/20260511000006_rls.sql:355-435` |
| Verification schema (full audit) | `supabase/migrations/20260511000005_social.sql:23-44` + `20260516000001_schema_reconciliation.sql:20-50` |
| Profile tables | `supabase/migrations/20260511000001_initial_schema.sql:30-56` |
| Trade categories seed | `supabase/migrations/20260512000003_trade_categories.sql` |
| Legal acceptance audit trail | `supabase/migrations/20260512000001_legal_acceptances.sql` |
| CI pipeline | `.github/workflows/ci.yml` |
| Trade upload (crop + compress) | `lib/features/verification/presentation/pages/verification_page.dart:44-48` |
| Sentry installed + wired | `pubspec.yaml:135` (`sentry_flutter ^8.10.1`); `lib/main.dart:41` (`SentryFlutter.init` + appRunner); `lib/core/errors/sentry_reporter.dart`; consumers `auth_provider.dart:134`, `profile_provider.dart:210` |
| `feature_flags` NOT present | `grep "feature_flag" supabase/migrations/*.sql` returns nothing |

## Related existing audits (already in repo)
- `docs/audit/00_EXECUTIVE_SUMMARY.md`
- `docs/audit/02_rls_auth.md`
- `docs/audit/04_storage_privacy.md`
- `docs/audit/08_observability_ops.md`
- `docs/JOBDUN_BACKEND_AUDIT.md`
- `docs/RBAC_SUPABASE_AUDIT.md`
