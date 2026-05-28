# Admin dashboard — wire real Supabase data

**Date:** 2026-05-28
**Branch base:** `chore/audit-followups-w1-w3` (current working branch)
**Status:** Approved — moving to implementation plan

## Goal

Make the Flutter admin web app (`lib/admin/`) functional enough that a signed-in admin can see real, live data from Supabase across the whole console:

- Dashboard tile counters show real numbers (no more `—`)
- Users page lists every profile (builder + trade + admin) with role + verified flag
- Jobs page lists every job across all statuses
- Audit page lists verification events + role audit log

Out of scope this pass: row-level actions (suspend, force-close, role override), drill-down detail pages, email exposure from `auth.users`, real-time updates, CSV export.

## Architectural blocker (must fix first)

Admin currently has **no RLS read access** to `profiles`, `builder_profiles`, `trade_profiles`, `user_roles`, `jobs`, or `applications`. Existing policies are owner-scoped only. The verifications tables already have admin-read policies (`verifications_admin_read`, `verification_documents_admin_select`, etc.) — we replicate that pattern.

**Migration:** `supabase/migrations/20260528000001_admin_read_policies.sql`

Adds `SELECT` policies named `<table>_admin_read` on:
- `public.profiles`
- `public.builder_profiles`
- `public.trade_profiles`
- `public.user_roles`
- `public.jobs`
- `public.applications`

Predicate (lifted verbatim from existing pattern):
```sql
EXISTS (
  SELECT 1 FROM public.user_roles ur
  WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
)
```

All policies wrapped in `DO $$ EXCEPTION WHEN duplicate_object THEN NULL $$` per the repo convention. Purely additive — no existing policy or trigger is modified. Mobile RLS behaviour is unchanged.

## Feature 1 — Dashboard tiles

Replace the 4 `'—'` placeholders in `admin_dashboard_page.dart` with live counts.

**Provider:** `lib/admin/features/admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart`
- `AsyncNotifier<AdminDashboardStats>` — runs 4 head-count queries in parallel inside `build()`:
  - `totalUsers` → `profiles` where `deleted_at is null`
  - `pendingVerifications` → `verification_documents` where `status='pending' and deleted_at is null`
  - `openJobs` → `jobs` where `status='open'`
  - `rejected7d` → `verification_documents` where `status='rejected' and reviewed_at >= now() - interval '7 days'`
- `Future<void> refresh()` — re-runs `build()` (sets state to loading, re-resolves)

Uses Supabase JS-equivalent `select('id', const FetchOptions(count: CountOption.exact, head: true))` so we never pull row bodies — server-side counts only.

**Repo:** `admin_dashboard_stats_repository.dart` (data layer)
**Entity:** `AdminDashboardStats { totalUsers, pendingVerifications, openJobs, rejected7d }`
**Use case:** `GetAdminDashboardStatsUseCase` returns `Future<Either<Failure, AdminDashboardStats>>`

**UI:** `_StatTile` reads from the provider via `ref.watch(...)`. Render rules:
- `loading` → show shimmer-styled `…` (use the existing `Gap`+`shimmer` pattern from the design system)
- `error` → show `—` and a small tooltip with the error
- `data` → show the number formatted with `NumberFormat.decimalPattern()` (so 1234 → "1,234")

**Tile labels:**
- "TOTAL USERS" — unchanged
- "PENDING VERIFICATIONS" — unchanged
- "OPEN JOBS" — unchanged
- "FLAGS THIS WEEK" → **renamed to "REJECTED (7D)"**, sublabel "Verifications rejected this week" — honest signal until a real reports system exists

## Feature 2 — Users page

Replace `AdminPlaceholderPage(title: 'USERS', …)` route with real page.

**New files** (one per layer, ≤400 LOC each):

- `lib/admin/features/admin_users/domain/entities/admin_user_row.dart`
  - `class AdminUserRow { id, displayName, role, isVerified, createdAt, avatarUrl }`
- `lib/admin/features/admin_users/domain/repositories/admin_users_repository.dart`
- `lib/admin/features/admin_users/domain/usecases/list_admin_users.dart`
  - `Future<Either<Failure, AdminUsersPage>> call({int limit, int offset, AdminUserRoleFilter filter, String? query})`
- `lib/admin/features/admin_users/data/repositories/admin_users_repository_impl.dart`
- `lib/admin/features/admin_users/presentation/providers/admin_users_provider.dart`
  - `AsyncNotifier<AdminUsersState>` — wraps `infinite_scroll_pagination`'s `PagingController` per design-system convention
  - Page size 50; ordered by `created_at desc`
- `lib/admin/features/admin_users/presentation/pages/admin_users_page.dart`
  - `AdminScaffold` body with: filter chip row (ALL / BUILDER / TRADE / ADMIN) + search TextField (display_name `ILIKE`) + `PagedListView<int, AdminUserRow>` rendering each user as a single-line row
  - First-page loading: `JSkeletonList`
  - Empty: pair of Lottie + headline + CTA per design system
  - Pull-to-refresh wraps the `PagedListView`

**Query shape (data layer):**
```dart
client.from('profiles')
  .select('id, display_name, avatar_url, is_verified, created_at, user_roles(role)')
  .filter('deleted_at', 'is', null)
  .order('created_at', ascending: false)
  .range(offset, offset + limit - 1);
```
Role filter and search are applied as additional `.eq()` / `.ilike()` clauses when set.

## Feature 3 — Jobs page

Same shape as Users page. Mirrored layer structure under `lib/admin/features/admin_jobs/`.

**Entity:** `AdminJobRow { id, title, status, builderDisplayName, applicationCount, createdAt }`

**Query:**
```dart
client.from('jobs')
  .select('id, title, status, application_count, created_at, profiles!jobs_builder_id_fkey(display_name)')
  .order('created_at', ascending: false)
  .range(offset, offset + limit - 1);
```

Filter chips: ALL / DRAFT / OPEN / FILLED / CLOSED / CANCELLED (matches the actual `public.job_status` enum, not the documented lifecycle in CLAUDE.md which is drift). No search v1.

## Feature 4 — Audit page

**Entity:** `AdminAuditEvent { id, occurredAt, source, actorId, eventType, targetUserId, payloadPreview }`
- `source` is an enum: `verification` | `role`

**Repo strategy:** two parallel SELECTs (verification_events + user_role_events), normalised in the repo into `AdminAuditEvent`, then merged + sorted by `occurredAt desc` and paged. No DB-side UNION view needed — both tables are small and admin-only, and avoiding a view keeps the migration footprint at 1 file.

**Page:** simple timeline list, no filters v1. Each row shows timestamp (`Asia/Sydney`-formatted via `intl`), source pill, event type, actor short id (8 chars), target short id (8 chars), and a 1-line preview of the JSON payload.

## Routing changes

`lib/admin/app/router/admin_router.dart`:
- `/users` builder → `AdminUsersPage()` (was `AdminPlaceholderPage`)
- `/jobs` builder → `AdminJobsPage()` (was `AdminPlaceholderPage`)
- `/audit` builder → `AdminAuditPage()` (was `AdminPlaceholderPage`)

`AdminPlaceholderPage` stays (currently only imported by these three routes once moved off it, the file may be deleted in a follow-up — kept this pass for safety; rule "half-built layers are deleted, not left as documentation" applies once we confirm nothing else imports it).

**Sidebar:** drop the `comingSoon: true` flag on USERS, JOBS, AUDIT LOG `_NavItem`s — they're live now. Dashboard `_PlaceholderGrid` cards for Users/Jobs/Audit get `route:` set so they become clickable, matching the existing Verifications pattern.

## Provider conventions (CLAUDE.md STRICT compliance)

- All controllers extend `AsyncNotifier<T>` — no `StateNotifier`, no `ChangeNotifier`.
- All `*RepositoryProvider`s declared at top-level **public** (no leading `_`) so tests can override via `ProviderScope(overrides: [...])`.
- `Notifier.build()` triggers initial load directly — no `addPostFrameCallback`.
- No direct `SupabaseConfig.client.from(...)` from Notifiers. Notifier → use case → repo → Supabase.
- `currentUserIdSyncProvider` for any `auth.currentUser.id` reads.
- File-size budget: target ≤400 LOC, ceiling 500. Each page split into `presentation/pages/` + `presentation/widgets/` if it would otherwise breach.

## Risk register

| Risk | Mitigation |
|---|---|
| RLS migration accidentally exposes data to non-admin users | Predicate uses `EXISTS user_roles role='admin'` — same gate verified by 5+ existing policies. Wrapped in `DO $$` so re-applying is idempotent. Mobile app tests should pass unchanged. |
| Count queries on `profiles` / `jobs` get slow at scale | Indexes already exist: `jobs_status_idx`, `profiles_id` (pk). For initial launch the row count is small enough that `count: exact` is fine. Revisit when row counts hit ~100k. |
| `infinite_scroll_pagination` controller leaks if page is rebuilt | Use the pattern documented in `lib/features/jobs/presentation/pages/jobs_feed_page.dart` — controller created in `initState`, disposed in `dispose`. |
| Admin sees private email/PII via joined `user_roles` | `user_roles` exposes only `(user_id, role)` — no PII. Confirmed by reading 20260511000001 + 20260520000001. |

## Verification plan

1. Run new migration locally: `supabase db reset` then re-apply.
2. Run `bash scripts/validate.sh` — must pass.
3. Run admin web app: `flutter run -d chrome -t lib/admin/main_admin.dart` (will need `--dart-define`s for SUPABASE_URL/ANON_KEY).
4. Sign in as a promoted admin account (or promote one via `service_role` SQL).
5. Confirm: 4 tiles show numbers; clicking USERS/JOBS/AUDIT shows real lists; counts match `SELECT count(*)` taken directly in SQL editor.
6. Sign in as a non-admin in the **mobile** app, confirm: no regression — user still sees only own profile/jobs (RLS unaffected).

## Files created / modified

**Created:**
- `supabase/migrations/20260528000001_admin_read_policies.sql`
- `lib/admin/features/admin_dashboard/{domain,data,presentation}/...` (5 files)
- `lib/admin/features/admin_users/{domain,data,presentation}/...` (~7 files)
- `lib/admin/features/admin_jobs/{domain,data,presentation}/...` (~7 files)
- `lib/admin/features/admin_audit/{domain,data,presentation}/...` (~7 files)

**Modified:**
- `lib/admin/app/router/admin_router.dart` — three route builders point to real pages
- `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart` — `_StatTile` reads from provider; `_PlaceholderGrid` cards become clickable
- `lib/admin/features/admin_shell/presentation/widgets/admin_sidebar.dart` — drop `comingSoon` on three nav items

Estimated change: ~25 new files, 3 modified, ~1500 LOC total.
