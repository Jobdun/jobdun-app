# Jobdun — W1–W3 Reality Check

> **Last verified:** 2026-05-22 on branch `docs/location-picker-audit`.
> Symbols below mean: ✅ verified in code, ❌ not present, ⚠️ partial / different from spec, ❓ can't verify without live DB / runtime.
> W1, W2, and W3 are all audited against the actual codebase below.

---

## TL;DR for the lead (W1 → W3 status)

**Solid foundations (W1 + W2)**
- Clean Architecture scaffold, Riverpod ProviderScope at root, GoRouter with auth-aware redirect (`splash → ftue → login → home` + `verify-email` lockout), theme tokens (colors / spacing / radii / motion / gradients), error architecture (`Failure` + `ErrorMessages.from` maps Supabase errors → plain English).
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
1. **No Sentry anywhere.** Not in `pubspec.yaml`, not in `main.dart`. Every "Sentry breadcrumb / dashboard / auth-failure capture" line of the plan is unmet.
2. **`analysis_options.yaml` is the default `flutter_lints`**, not `very_good_analysis`. The `dart_code_linter` strict-metrics block exists but is **commented out**. The 500-LOC ceiling is still enforced by `scripts/validate.sh`.
3. **CI is missing `dart format --set-exit-if-changed .`** and there is **no shadow-Supabase migration job** — migrations are not exercised in CI.
4. **No upload guard-rails.** No max-file-size, no MIME allowlist, no retry/backoff. Anything `image_picker` returns goes through.
5. **No `feature_flags` table** (and no PostHog wiring).
6. **No expiry-reminder job** (Edge Function + cron) for verification docs — column captured, notifications not built.
7. **No soft delete on `builder_profiles` / `trade_profiles`.** Only `jobs`, `messages`, `verification_documents` have `deleted_at`.
8. **Schema drift vs. plan column names.** `trade_profiles` uses `full_name` / `primary_trade` (text) — not `display_name` / FK to `trade_categories`; no `licence_number` column (licences live in `verification_documents`); no plain `location` text column (the `places_columns` migration adds Google-Places fields).
9. **Bucket names differ from plan.** Plan says `avatars` / `portfolio` / `verification_docs`; actual is `public-media` + `private-docs`. Not wrong, just different.
10. **Admin review screen is out of scope for the Flutter app** (CLAUDE.md: admin is a separate web app). Plan's "Admin review screen exists" line is unmet in this repo *by design*.
11. **JTextField primitive exists but isn't used everywhere.** Raw `TextField` / `FormBuilderTextField` still appears in ~10 screens (`phone_auth_page`, `profile_edit_page`, `trade_category_picker`, `job_detail_page`, `jobs_page`, `message_thread_page`, etc.). Not a bug — a consistency debt.
12. **No explicit 44pt touch-target enforcement** in the global theme (no `MaterialTapTargetSize` / `minimumSize` set centrally). May still be fine per-widget; needs a contrast + tap-target audit pass.
13. **No env split (dev/staging/prod).** `env.dart` reads one `SUPABASE_URL` / `SUPABASE_ANON_KEY` from a single `.env` + `--dart-define`. No staging vs. prod separation in the build pipeline.

---

## W1 — Architecture & Setup
### Flutter app
- [x] ✅ Feature-first Clean Architecture — `lib/features/{auth,profile,jobs,applications,messaging,verification,ftue,home,legal,notifications,reviews}/` each with `data/ domain/ presentation/`.
- [x] ✅ Riverpod ProviderScope at root — `lib/main.dart:30-37` (overrides only for the persisted theme).
- [x] ✅ GoRouter with auth-aware redirect — `lib/app/router/app_router.dart:50-110` handles FTUE, splash, public routes, pending email verification, and auth-only pages.
- [x] ✅ Theme tokens defined — `lib/app/theme/` has `app_colors.dart`, `app_radii.dart`, `app_spacing.dart`, `app_motion.dart`, `app_gradients.dart`, `app_theme.dart`.
- [ ] ⚠️ JTextField primitive built **but not used everywhere**. Raw `TextField` / `FormBuilderTextField` appears in `phone_auth_page.dart:402`, `profile_edit_page.dart:617`, `trade_category_picker.dart:310/479`, `job_detail_page.dart:442/468`, `jobs_page.dart:146`, `message_thread_page.dart:299`, `profile_location_field.dart:222`, `job_location_field.dart:132`.
- [x] ✅ Formatter / validator utilities — `lib/core/utils/app_date_utils.dart`, `string_utils.dart`, `validators.dart`, `lib/core/validators/phone_validator.dart`. ❓ Dedicated ABN formatter — not separately verified.
- [x] ⚠️ Error architecture: `lib/core/errors/{exceptions,failures,error_messages}.dart` — `Failure` types + `ErrorMessages.from` mapper + `fpdart` Either are all present. **No top-level error-boundary widget**; `core/widgets/error_view.dart` is a passive display, not a runtime boundary.
- [ ] ❌ Sentry — `grep sentry` returns nothing in `pubspec.yaml` / `lib/`. Not installed.

### Repo + CI
- [x] ✅ `.gitignore` excludes `.env*`, `/build/`, `*.key`, `*.pem`, `client_secret_*.json`, `*.p8`, OAuth plists.
- [ ] ⚠️ `analysis_options.yaml` uses default `flutter_lints` only. The `dart_code_linter` strict-metrics block (file-size, complexity, nesting, params) is **commented out**. Hard 500-LOC ceiling is still enforced separately by `scripts/validate.sh`.
- [x] ⚠️ CI runs `flutter analyze --no-fatal-infos` + `flutter test test/features/` on push/PR to `main`/`develop`. **Missing:** `dart format --set-exit-if-changed .`
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
- [x] ⚠️ Password min length — `FormBuilderValidators.minLength` used in `register_page.dart:549,588` (need to read the literal to confirm = 8). ❌ No additional strength rule (no upper/digit/symbol enforcement).
- [x] ✅ Auth errors mapped to plain English — `lib/core/errors/error_messages.dart` maps "invalid credentials" → "Incorrect email or password", "email not confirmed", "user already registered", "password too short", "rate limit", "network" cases.
- [x] ✅ ToS + Privacy Policy acceptance — `legal_acceptances` table with `(user_id, document_type, document_version, accepted_at, app_version)`, RLS read-own + admin-read-all, no UPDATE/DELETE policy (immutable). `supabase/migrations/20260512000001_legal_acceptances.sql`. Tests: `test/features/legal/legal_test.dart`.

### Quality
- [ ] ❓ WCAG AA contrast — no automated contrast check found; needs manual audit. Brand spec (`CLAUDE.md` design tokens) uses `#F1F5F9` on `#0F172A` (passes AA at body sizes).
- [ ] ❌ 44pt+ touch targets — no `MaterialTapTargetSize` / `minimumSize` enforced in `app_theme.dart`. Per-widget compliance not verified.
- [ ] ❌ Sentry captures auth failures — Sentry not installed (same gap as W1).

---

## W3 — Profiles + Uploads + Verification (start)

### Builder & Trade profiles
- [x] ✅ `builder_profiles` table exists — `company_name`, `abn`, `logo_url`, `description`, `created_at`, `updated_at`. `supabase/migrations/20260511000001_initial_schema.sql:30-39`. ⚠️ **MISSING:** `location`, `contact`, `deleted_at`.
- [x] ⚠️ `trade_profiles` table exists — `full_name`, `primary_trade` (text), `is_verified`, `bio`, `portfolio_urls`, `hourly_rate`, `day_rate`, `years_experience`. `supabase/migrations/20260511000001_initial_schema.sql:43-56`. **Plan drift:** uses `full_name` instead of `display_name`, no `licence_number` column (licences live in `verification_documents`), no `location` text column (place fields added in `20260522000001_places_columns.sql`), no `deleted_at`.
- [x] ✅ `trade_categories` reference table seeded with 19 canonical categories. `supabase/migrations/20260512000003_trade_categories.sql`. ⚠️ `trade_profiles.primary_trade` is `text` — not an FK; `trade_other` column captures custom entries.
- [x] ✅ RLS on `builder_profiles` / `trade_profiles`: authenticated SELECT, owner INSERT/UPDATE. `supabase/migrations/20260511000006_rls.sql:79-132`.
- [ ] ❓ Index on `trade_profiles(trade_category)` and `(location)` — not in the audited migrations; check `places_columns` migration for the location index.
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
- [x] ✅ `verification_documents` table with all audit columns: `doc_type`, `file_path`, `submitted_at`, `state`, `issuer`, `document_number`, `issued_date`, `expiry_date`, `rejection_reason`, `review_notes`, `reviewed_by`, `reviewed_at`, `deleted_at`, status enum (`pending`/`approved`/`rejected`/`expired`). `supabase/migrations/20260511000005_social.sql:23-37` + `20260516000001_schema_reconciliation.sql:20-37`.
- [x] ✅ RLS: owner SELECT/INSERT own rows. `20260511000006_rls.sql:309-326`. ❓ Admin SELECT-all + UPDATE-status policy — needs explicit verification against the `admin` role.
- [x] ✅ Trade profile screen has upload entry point — `lib/features/verification/presentation/pages/verification_page.dart`.
- [ ] ❌ Admin review screen — **not in this repo** (CLAUDE.md: "Admin is a separate web application — the Flutter app has no admin UI"). Out of Flutter scope by design.
- [ ] ❌ Approve/reject flow — same as above, lives in the admin web app, not this repo.
- [x] ✅ `expiry_date` column captured at upload (manual entry; no OCR yet). `20260516000001_schema_reconciliation.sql:31`.
- [ ] ❌ Scaffold for expiry reminder job (Edge Function + cron) — not present in `supabase/` (no functions folder visible; only `migrations`, `email-templates`, `snippets`).

---

## Cross-cutting (must be true by end of W3)
- [ ] ❓ Zero tables without RLS — every migration uses `ENABLE ROW LEVEL SECURITY`, but to confirm zero gaps you must run `SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=false;` against the live DB.
- [ ] ❌ Sentry dashboard shows real events — **Sentry not installed** (`sentry_flutter` not in `pubspec.yaml`).
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
| Sentry NOT installed | `pubspec.yaml` (no `sentry_flutter` entry) |
| `feature_flags` NOT present | `grep "feature_flag" supabase/migrations/*.sql` returns nothing |

## Related existing audits (already in repo)
- `docs/audit/00_EXECUTIVE_SUMMARY.md`
- `docs/audit/02_rls_auth.md`
- `docs/audit/04_storage_privacy.md`
- `docs/audit/08_observability_ops.md`
- `docs/JOBDUN_BACKEND_AUDIT.md`
- `docs/RBAC_SUPABASE_AUDIT.md`
