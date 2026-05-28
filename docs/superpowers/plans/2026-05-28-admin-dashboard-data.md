# Admin Dashboard — Wire Real Supabase Data — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter admin web app (`lib/admin/`) show real Supabase data across the dashboard, users, jobs, and audit views.

**Architecture:** Per-feature Clean Architecture under `lib/admin/features/` — each new feature has `domain/` (entity + repo contract + use case), `data/` (Supabase-backed repo impl), and `presentation/` (AsyncNotifier provider + page widgets). One additive Supabase migration grants admin-role SELECT on `profiles`, `builder_profiles`, `trade_profiles`, `user_roles`, `jobs`, `job_applications`. Mobile RLS is unchanged.

**Tech Stack:** Flutter 3.11.5, Riverpod 3 (`AsyncNotifier`), GoRouter, Supabase Postgres + RLS, `fpdart`, `infinite_scroll_pagination`, `mocktail` for tests.

**Spec:** `docs/superpowers/specs/2026-05-28-admin-dashboard-data-design.md`

---

## File Structure

**Created files:**

```
supabase/migrations/
  20260528000001_admin_read_policies.sql

lib/admin/features/admin_dashboard/
  domain/entities/admin_dashboard_stats.dart
  domain/repositories/admin_dashboard_stats_repository.dart
  domain/usecases/get_admin_dashboard_stats.dart
  data/repositories/admin_dashboard_stats_repository_impl.dart
  presentation/providers/admin_dashboard_stats_provider.dart

lib/admin/features/admin_users/
  domain/entities/admin_user_row.dart
  domain/repositories/admin_users_repository.dart
  domain/usecases/list_admin_users.dart
  data/repositories/admin_users_repository_impl.dart
  presentation/providers/admin_users_provider.dart
  presentation/pages/admin_users_page.dart
  presentation/widgets/admin_user_list_row.dart

lib/admin/features/admin_jobs/
  domain/entities/admin_job_row.dart
  domain/repositories/admin_jobs_repository.dart
  domain/usecases/list_admin_jobs.dart
  data/repositories/admin_jobs_repository_impl.dart
  presentation/providers/admin_jobs_provider.dart
  presentation/pages/admin_jobs_page.dart
  presentation/widgets/admin_job_list_row.dart

lib/admin/features/admin_audit/
  domain/entities/admin_audit_event.dart
  domain/repositories/admin_audit_repository.dart
  domain/usecases/list_admin_audit_events.dart
  data/repositories/admin_audit_repository_impl.dart
  presentation/providers/admin_audit_provider.dart
  presentation/pages/admin_audit_page.dart
  presentation/widgets/admin_audit_event_row.dart

test/admin/features/admin_dashboard/domain/usecases/
  get_admin_dashboard_stats_test.dart
test/admin/features/admin_users/domain/usecases/
  list_admin_users_test.dart
test/admin/features/admin_jobs/domain/usecases/
  list_admin_jobs_test.dart
test/admin/features/admin_audit/domain/usecases/
  list_admin_audit_events_test.dart
```

**Modified files:**

- `lib/admin/app/router/admin_router.dart` — three route builders point to real pages
- `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart` — `_StatTile` reads from provider; `_PlaceholderGrid` cards get `route:` set
- `lib/admin/features/admin_shell/presentation/widgets/admin_sidebar.dart` — drop `comingSoon: true` on Users/Jobs/Audit nav items
- `lib/admin/features/admin_shell/presentation/pages/admin_placeholder_page.dart` — **delete** at end of plan (no remaining importers)

---

## Conventions (read once, apply throughout)

- All `Notifier` / `AsyncNotifier` controllers extend Riverpod 3's `AsyncNotifier<T>`. Never `StateNotifier`, never `ChangeNotifier`.
- All `*RepositoryProvider` and `*UseCaseProvider` declarations live at **top-level public** (no leading underscore). Tests override them via `ProviderScope(overrides: [...])`.
- Notifiers MUST NOT call `SupabaseConfig.client.from(...)` directly. They go through a use case → repository → datasource (Supabase).
- Initial load triggers inside `AsyncNotifier.build()`. No `addPostFrameCallback`.
- Use case return type: `Future<Either<Failure, T>>` (`fpdart`).
- File-size budget: target ≤400 LOC, ceiling 500. Split widgets out of page files when needed.
- After each Task, run `flutter analyze --no-fatal-infos` before committing. If it fails, fix before commit.

---

## Task 1: Migration — admin read policies

**Files:**
- Create: `supabase/migrations/20260528000001_admin_read_policies.sql`

- [ ] **Step 1: Create the migration file**

Write the migration that adds `<table>_admin_read` SELECT policies on six tables. Predicate matches existing `verification_documents_admin_select` (i.e. `EXISTS user_roles role='admin'`). Each `CREATE POLICY` is wrapped in `DO $$ … EXCEPTION WHEN duplicate_object … END $$` per repo convention (see `supabase/migrations/20260511000006_rls.sql`).

```sql
-- ============================================================
-- Migration: admin read policies for profiles + jobs + role tables
-- Purpose : enable the admin web app to read the full dataset
--           it needs for dashboard counts, users list, jobs
--           list, and audit views. Mobile RLS is untouched —
--           all existing owner-scoped policies remain.
-- Pattern : mirrors verification_documents_admin_select / etc.
-- ============================================================

-- profiles ---------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "profiles_admin_read"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- builder_profiles -------------------------------------------
DO $$ BEGIN
  CREATE POLICY "builder_profiles_admin_read"
    ON public.builder_profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- trade_profiles ---------------------------------------------
DO $$ BEGIN
  CREATE POLICY "trade_profiles_admin_read"
    ON public.trade_profiles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- user_roles -------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "user_roles_admin_read"
    ON public.user_roles FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- jobs -------------------------------------------------------
DO $$ BEGIN
  CREATE POLICY "jobs_admin_read"
    ON public.jobs FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- job_applications -------------------------------------------
DO $$ BEGIN
  CREATE POLICY "job_applications_admin_read"
    ON public.job_applications FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

- [ ] **Step 2: Apply the migration locally**

Run:
```bash
supabase db reset
```
Expected: migration applies cleanly, no errors. If `supabase` CLI is not linked locally, apply via SQL editor in Supabase Studio instead — copy the file contents and run.

- [ ] **Step 3: Smoke-test from psql / Studio**

As a non-admin user (use a fresh test account), confirm `select count(*) from profiles` still returns only 1 (their own row). As an admin user, confirm `select count(*) from profiles` returns the full count. If the project doesn't have an admin account yet, promote one:
```sql
update public.user_roles set role = 'admin' where user_id = '<your-test-uuid>';
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260528000001_admin_read_policies.sql
git commit -m "feat(rls): admin SELECT policies on profiles, jobs, role tables

Mirrors the existing verifications_admin_read pattern so the admin web
console can read the full dataset. Mobile RLS unchanged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Dashboard stats — domain layer

**Files:**
- Create: `lib/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart`
- Create: `lib/admin/features/admin_dashboard/domain/repositories/admin_dashboard_stats_repository.dart`
- Create: `lib/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats.dart`
- Create: `test/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats_test.dart`

- [ ] **Step 1: Write the entity**

```dart
// lib/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart
import 'package:equatable/equatable.dart';

class AdminDashboardStats extends Equatable {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingVerifications,
    required this.openJobs,
    required this.rejectedLast7Days,
  });

  final int totalUsers;
  final int pendingVerifications;
  final int openJobs;
  final int rejectedLast7Days;

  @override
  List<Object?> get props => [
        totalUsers,
        pendingVerifications,
        openJobs,
        rejectedLast7Days,
      ];
}
```

- [ ] **Step 2: Write the repository contract**

```dart
// lib/admin/features/admin_dashboard/domain/repositories/admin_dashboard_stats_repository.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_dashboard_stats.dart';

abstract class AdminDashboardStatsRepository {
  Future<Either<Failure, AdminDashboardStats>> getStats();
}
```

- [ ] **Step 3: Write the use case**

```dart
// lib/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_dashboard_stats.dart';
import '../repositories/admin_dashboard_stats_repository.dart';

class GetAdminDashboardStats {
  const GetAdminDashboardStats(this._repository);

  final AdminDashboardStatsRepository _repository;

  Future<Either<Failure, AdminDashboardStats>> call() => _repository.getStats();
}
```

- [ ] **Step 4: Write the failing test**

```dart
// test/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/repositories/admin_dashboard_stats_repository.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminDashboardStatsRepository {}

void main() {
  late GetAdminDashboardStats useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = GetAdminDashboardStats(repo);
  });

  test('delegates to repository.getStats and returns the result', () async {
    const stats = AdminDashboardStats(
      totalUsers: 42,
      pendingVerifications: 5,
      openJobs: 11,
      rejectedLast7Days: 2,
    );
    when(() => repo.getStats()).thenAnswer((_) async => const Right(stats));

    final result = await useCase();

    expect(result, const Right<Failure, AdminDashboardStats>(stats));
    verify(() => repo.getStats()).called(1);
  });

  test('propagates repository failures', () async {
    when(() => repo.getStats()).thenAnswer(
      (_) async => const Left(ServerFailure('boom')),
    );

    final result = await useCase();

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/admin/features/admin_dashboard/domain test/admin/features/admin_dashboard
git commit -m "feat(admin): dashboard stats domain layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Dashboard stats — data layer + provider

**Files:**
- Create: `lib/admin/features/admin_dashboard/data/repositories/admin_dashboard_stats_repository_impl.dart`
- Create: `lib/admin/features/admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart`

- [ ] **Step 1: Write the repository impl**

`head: true, count: CountOption.exact` gives a server-side count without pulling rows. The "rejected past 7 days" cutoff is computed client-side then sent as an ISO timestamp.

```dart
// lib/admin/features/admin_dashboard/data/repositories/admin_dashboard_stats_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/repositories/admin_dashboard_stats_repository.dart';

class AdminDashboardStatsRepositoryImpl
    implements AdminDashboardStatsRepository {
  AdminDashboardStatsRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, AdminDashboardStats>> getStats() async {
    try {
      final results = await Future.wait([
        _countTotalUsers(),
        _countPendingVerifications(),
        _countOpenJobs(),
        _countRejectedLast7Days(),
      ]);
      return Right(AdminDashboardStats(
        totalUsers: results[0],
        pendingVerifications: results[1],
        openJobs: results[2],
        rejectedLast7Days: results[3],
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<int> _countTotalUsers() async {
    final res = await _client
        .from('profiles')
        .select('id')
        .isFilter('deleted_at', null)
        .count(CountOption.exact);
    return res.count;
  }

  Future<int> _countPendingVerifications() async {
    final res = await _client
        .from('verification_documents')
        .select('id')
        .eq('status', 'pending')
        .isFilter('deleted_at', null)
        .count(CountOption.exact);
    return res.count;
  }

  Future<int> _countOpenJobs() async {
    final res = await _client
        .from('jobs')
        .select('id')
        .eq('status', 'open')
        .count(CountOption.exact);
    return res.count;
  }

  Future<int> _countRejectedLast7Days() async {
    final cutoff =
        DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
    final res = await _client
        .from('verification_documents')
        .select('id')
        .eq('status', 'rejected')
        .gte('reviewed_at', cutoff)
        .count(CountOption.exact);
    return res.count;
  }
}
```

- [ ] **Step 2: Write the provider**

`AsyncNotifier.build()` runs the use case once on first read. Public providers, no underscores.

```dart
// lib/admin/features/admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_dashboard_stats_repository_impl.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/repositories/admin_dashboard_stats_repository.dart';
import '../../domain/usecases/get_admin_dashboard_stats.dart';

final adminDashboardStatsRepositoryProvider =
    Provider<AdminDashboardStatsRepository>(
  (ref) => AdminDashboardStatsRepositoryImpl(),
);

final getAdminDashboardStatsProvider = Provider<GetAdminDashboardStats>(
  (ref) => GetAdminDashboardStats(ref.watch(adminDashboardStatsRepositoryProvider)),
);

final adminDashboardStatsProvider =
    AsyncNotifierProvider<AdminDashboardStatsController, AdminDashboardStats>(
  AdminDashboardStatsController.new,
);

class AdminDashboardStatsController extends AsyncNotifier<AdminDashboardStats> {
  @override
  Future<AdminDashboardStats> build() async {
    final useCase = ref.read(getAdminDashboardStatsProvider);
    final result = await useCase();
    return result.fold((f) => throw Exception(f.message), (s) => s);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(getAdminDashboardStatsProvider);
      final result = await useCase();
      return result.fold((f) => throw Exception(f.message), (s) => s);
    });
  }
}
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_dashboard
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/features/admin_dashboard/data lib/admin/features/admin_dashboard/presentation
git commit -m "feat(admin): dashboard stats data layer + provider

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Wire stats into the dashboard tiles

**Files:**
- Modify: `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart`

- [ ] **Step 1: Read the current file**

Open `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart`. The `_StatTile` widget currently takes `value: '—'`. We replace its hardcoded values with reads from the new provider, and add a `_StatValue` Consumer widget so each tile shows loading/error/data per-field.

- [ ] **Step 2: Add imports + helper Consumer + intl formatting**

Add at the top of the file:

```dart
import 'package:intl/intl.dart';

import '../../../admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart';
```

- [ ] **Step 3: Replace `_StatsStrip` to read from the provider**

Replace the entire `_StatsStrip` class with this version. It watches `adminDashboardStatsProvider` and passes the resolved counts (or `null` while loading / on error) to each tile.

```dart
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final stats = statsAsync.valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _StatTile(
            label: 'TOTAL USERS',
            value: _format(stats?.totalUsers, statsAsync),
            sublabel: 'Builders + Trades',
          ),
          _StatTile(
            label: 'PENDING VERIFICATIONS',
            value: _format(stats?.pendingVerifications, statsAsync),
            sublabel: 'Awaiting review',
            highlight: true,
          ),
          _StatTile(
            label: 'OPEN JOBS',
            value: _format(stats?.openJobs, statsAsync),
            sublabel: 'Across all builders',
          ),
          _StatTile(
            label: 'REJECTED (7D)',
            value: _format(stats?.rejectedLast7Days, statsAsync),
            sublabel: 'Verifications rejected this week',
          ),
        ];

        final cols = constraints.maxWidth >= 1100
            ? 4
            : (constraints.maxWidth >= 720 ? 2 : 1);
        const spacing = 16.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map((t) => SizedBox(width: tileWidth, child: t))
              .toList(),
        );
      },
    );
  }

  static String _format(int? value, AsyncValue<Object?> async) {
    if (async.isLoading) return '…';
    if (async.hasError) return '—';
    if (value == null) return '—';
    return NumberFormat.decimalPattern().format(value);
  }
}
```

- [ ] **Step 4: Run analyzer**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_shell
```
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart
git commit -m "feat(admin): dashboard tiles read live counts from Supabase

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Users — domain layer

**Files:**
- Create: `lib/admin/features/admin_users/domain/entities/admin_user_row.dart`
- Create: `lib/admin/features/admin_users/domain/entities/admin_user_filter.dart`
- Create: `lib/admin/features/admin_users/domain/repositories/admin_users_repository.dart`
- Create: `lib/admin/features/admin_users/domain/usecases/list_admin_users.dart`
- Create: `test/admin/features/admin_users/domain/usecases/list_admin_users_test.dart`

- [ ] **Step 1: Write the entity**

```dart
// lib/admin/features/admin_users/domain/entities/admin_user_row.dart
import 'package:equatable/equatable.dart';

class AdminUserRow extends Equatable {
  const AdminUserRow({
    required this.id,
    required this.displayName,
    required this.role,
    required this.isVerified,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String role; // 'builder' | 'trade' | 'admin' | 'unknown'
  final bool isVerified;
  final DateTime createdAt;
  final String? avatarUrl;

  @override
  List<Object?> get props =>
      [id, displayName, role, isVerified, createdAt, avatarUrl];
}
```

- [ ] **Step 2: Write the filter enum**

```dart
// lib/admin/features/admin_users/domain/entities/admin_user_filter.dart
enum AdminUserRoleFilter { all, builder, trade, admin }
```

- [ ] **Step 3: Write the repo contract**

```dart
// lib/admin/features/admin_users/domain/repositories/admin_users_repository.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_filter.dart';
import '../entities/admin_user_row.dart';

abstract class AdminUsersRepository {
  Future<Either<Failure, List<AdminUserRow>>> listUsers({
    required int limit,
    required int offset,
    AdminUserRoleFilter filter = AdminUserRoleFilter.all,
    String? query,
  });
}
```

- [ ] **Step 4: Write the use case**

```dart
// lib/admin/features/admin_users/domain/usecases/list_admin_users.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_filter.dart';
import '../entities/admin_user_row.dart';
import '../repositories/admin_users_repository.dart';

class ListAdminUsersParams {
  const ListAdminUsersParams({
    required this.limit,
    required this.offset,
    this.filter = AdminUserRoleFilter.all,
    this.query,
  });

  final int limit;
  final int offset;
  final AdminUserRoleFilter filter;
  final String? query;
}

class ListAdminUsers {
  const ListAdminUsers(this._repository);

  final AdminUsersRepository _repository;

  Future<Either<Failure, List<AdminUserRow>>> call(
    ListAdminUsersParams params,
  ) {
    return _repository.listUsers(
      limit: params.limit,
      offset: params.offset,
      filter: params.filter,
      query: params.query,
    );
  }
}
```

- [ ] **Step 5: Write the test**

```dart
// test/admin/features/admin_users/domain/usecases/list_admin_users_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_users/domain/entities/admin_user_filter.dart';
import 'package:jobdun/admin/features/admin_users/domain/entities/admin_user_row.dart';
import 'package:jobdun/admin/features/admin_users/domain/repositories/admin_users_repository.dart';
import 'package:jobdun/admin/features/admin_users/domain/usecases/list_admin_users.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminUsersRepository {}

void main() {
  late ListAdminUsers useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminUsers(repo);
  });

  test('forwards params to repository', () async {
    final row = AdminUserRow(
      id: 'u1',
      displayName: 'Alice',
      role: 'trade',
      isVerified: true,
      createdAt: DateTime(2026, 1, 1),
    );
    when(() => repo.listUsers(
          limit: 50,
          offset: 0,
          filter: AdminUserRoleFilter.trade,
          query: 'ali',
        )).thenAnswer((_) async => Right([row]));

    final result = await useCase(const ListAdminUsersParams(
      limit: 50,
      offset: 0,
      filter: AdminUserRoleFilter.trade,
      query: 'ali',
    ));

    expect(result.isRight(), isTrue);
    verify(() => repo.listUsers(
          limit: 50,
          offset: 0,
          filter: AdminUserRoleFilter.trade,
          query: 'ali',
        )).called(1);
  });

  test('propagates failures', () async {
    when(() => repo.listUsers(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
          query: any(named: 'query'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(const ListAdminUsersParams(limit: 50, offset: 0));

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 6: Run test**

```bash
flutter test test/admin/features/admin_users/domain/usecases/list_admin_users_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/admin/features/admin_users/domain test/admin/features/admin_users
git commit -m "feat(admin): users list domain layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Users — data layer

**Files:**
- Create: `lib/admin/features/admin_users/data/repositories/admin_users_repository_impl.dart`

- [ ] **Step 1: Write the impl**

The FK embed `user_roles(role)` returns an array when the join is one-to-many; we take the first row. `display_name ILIKE` for search.

```dart
// lib/admin/features/admin_users/data/repositories/admin_users_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/admin_users_repository.dart';

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  AdminUsersRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminUserRow>>> listUsers({
    required int limit,
    required int offset,
    AdminUserRoleFilter filter = AdminUserRoleFilter.all,
    String? query,
  }) async {
    try {
      var builder = _client
          .from('profiles')
          .select(
            'id, display_name, avatar_url, is_verified, created_at, '
            'user_roles!user_roles_user_id_fkey(role)',
          )
          .isFilter('deleted_at', null);

      if (filter != AdminUserRoleFilter.all) {
        // Filter via the joined table — Supabase supports `user_roles.role`.
        builder = builder.eq('user_roles.role', _roleString(filter));
      }
      if (query != null && query.trim().isNotEmpty) {
        builder = builder.ilike('display_name', '%${query.trim()}%');
      }

      final rows = await builder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_toRow)
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  String _roleString(AdminUserRoleFilter f) => switch (f) {
        AdminUserRoleFilter.all => 'all',
        AdminUserRoleFilter.builder => 'builder',
        AdminUserRoleFilter.trade => 'trade',
        AdminUserRoleFilter.admin => 'admin',
      };

  AdminUserRow _toRow(Map<String, dynamic> r) {
    final roles = r['user_roles'];
    String role = 'unknown';
    if (roles is List && roles.isNotEmpty) {
      role = (roles.first as Map<String, dynamic>)['role'] as String? ?? 'unknown';
    } else if (roles is Map<String, dynamic>) {
      role = roles['role'] as String? ?? 'unknown';
    }
    return AdminUserRow(
      id: r['id'] as String,
      displayName: (r['display_name'] as String?)?.trim().isNotEmpty == true
          ? (r['display_name'] as String).trim()
          : '${(r['id'] as String).substring(0, 8)}…',
      role: role,
      isVerified: (r['is_verified'] as bool?) ?? false,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      avatarUrl: r['avatar_url'] as String?,
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_users
```
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/features/admin_users/data
git commit -m "feat(admin): users list data layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Users — provider with infinite_scroll_pagination

**Files:**
- Create: `lib/admin/features/admin_users/presentation/providers/admin_users_provider.dart`

- [ ] **Step 1: Write the provider**

We use `infinite_scroll_pagination`'s `PagingController` directly inside the controller. The controller exposes the `PagingController` plus filter/query setters that reset the pager.

```dart
// lib/admin/features/admin_users/presentation/providers/admin_users_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_users_repository_impl.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../../domain/usecases/list_admin_users.dart';

const int kAdminUsersPageSize = 50;

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>(
  (ref) => AdminUsersRepositoryImpl(),
);

final listAdminUsersProvider = Provider<ListAdminUsers>(
  (ref) => ListAdminUsers(ref.watch(adminUsersRepositoryProvider)),
);

class AdminUsersState {
  const AdminUsersState({
    required this.filter,
    required this.query,
  });

  final AdminUserRoleFilter filter;
  final String query;

  AdminUsersState copyWith({AdminUserRoleFilter? filter, String? query}) =>
      AdminUsersState(
        filter: filter ?? this.filter,
        query: query ?? this.query,
      );
}

final adminUsersProvider =
    NotifierProvider<AdminUsersController, AdminUsersState>(
  AdminUsersController.new,
);

class AdminUsersController extends Notifier<AdminUsersState> {
  late final PagingController<int, AdminUserRow> pagingController;

  @override
  AdminUsersState build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
    return const AdminUsersState(filter: AdminUserRoleFilter.all, query: '');
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminUsersProvider);
    final result = await useCase(ListAdminUsersParams(
      limit: kAdminUsersPageSize,
      offset: offset,
      filter: state.filter,
      query: state.query.isEmpty ? null : state.query,
    ));
    result.fold(
      (failure) => pagingController.error = failure.message,
      (rows) {
        final isLast = rows.length < kAdminUsersPageSize;
        if (isLast) {
          pagingController.appendLastPage(rows);
        } else {
          pagingController.appendPage(rows, offset + rows.length);
        }
      },
    );
  }

  void setFilter(AdminUserRoleFilter f) {
    if (f == state.filter) return;
    state = state.copyWith(filter: f);
    pagingController.refresh();
  }

  void setQuery(String q) {
    if (q == state.query) return;
    state = state.copyWith(query: q);
    pagingController.refresh();
  }

  Future<void> refresh() async {
    pagingController.refresh();
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_users
```
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/features/admin_users/presentation/providers
git commit -m "feat(admin): users list provider with paging

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Users — page widget

**Files:**
- Create: `lib/admin/features/admin_users/presentation/widgets/admin_user_list_row.dart`
- Create: `lib/admin/features/admin_users/presentation/pages/admin_users_page.dart`

- [ ] **Step 1: Write the row widget**

Compact horizontal row: avatar circle, name + role pill + verified tick, created date right-aligned. Matches the dark Aggressive Flat tokens from the design system.

```dart
// lib/admin/features/admin_users/presentation/widgets/admin_user_list_row.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../domain/entities/admin_user_row.dart';

class AdminUserListRow extends StatelessWidget {
  const AdminUserListRow({super.key, required this.row});

  final AdminUserRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          _Avatar(url: row.avatarUrl, name: row.displayName),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                    ),
                    if (row.isVerified) ...[
                      const Gap(6),
                      Icon(AppIcons.verified, size: 14, color: c.action),
                    ],
                  ],
                ),
                const Gap(2),
                Text(
                  row.role.toUpperCase(),
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.text3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initialFallback(c, initial),
                placeholder: (_, __) => _initialFallback(c, initial),
              )
            : _initialFallback(c, initial),
      ),
    );
  }

  Widget _initialFallback(AppColorsExt c, String letter) => Container(
        color: c.surfaceRaised,
        alignment: Alignment.center,
        child: Text(
          letter,
          style: GoogleFonts.oswald(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.text2,
          ),
        ),
      );
}
```

- [ ] **Step 2: Write the page**

```dart
// lib/admin/features/admin_users/presentation/pages/admin_users_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../providers/admin_users_provider.dart';
import '../widgets/admin_user_list_row.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller =
        ref.watch(adminUsersProvider.notifier).pagingController;
    final stateValue = ref.watch(adminUsersProvider);

    return AdminScaffold(
      title: 'USERS',
      activeRoute: AdminRoutes.users,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(active: stateValue.filter),
          const Gap(12),
          _SearchField(initial: stateValue.query),
          const Gap(16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(adminUsersProvider.notifier).refresh(),
              child: PagedListView<int, AdminUserRow>(
                pagingController: controller,
                builderDelegate: PagedChildBuilderDelegate<AdminUserRow>(
                  itemBuilder: (_, row, __) => AdminUserListRow(row: row),
                  firstPageProgressIndicatorBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  newPageProgressIndicatorBuilder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.text3,
                        ),
                      ),
                    ),
                  ),
                  firstPageErrorIndicatorBuilder: (_) => _ErrorBlock(
                    message: controller.error?.toString() ?? 'Failed to load.',
                    onRetry: () => controller.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => _EmptyBlock(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.active});
  final AdminUserRoleFilter active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      (AdminUserRoleFilter.all, 'ALL'),
      (AdminUserRoleFilter.builder, 'BUILDERS'),
      (AdminUserRoleFilter.trade, 'TRADES'),
      (AdminUserRoleFilter.admin, 'ADMINS'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (filter, label) in filters)
          _Chip(
            label: label,
            isActive: filter == active,
            onTap: () =>
                ref.read(adminUsersProvider.notifier).setFilter(filter),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: isActive ? c.action : c.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? c.background : c.text1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.initial});
  final String initial;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: _ctrl,
      onSubmitted: (v) =>
          ref.read(adminUsersProvider.notifier).setQuery(v.trim()),
      style: GoogleFonts.openSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.text1,
      ),
      decoration: InputDecoration(
        hintText: 'Search display name…',
        hintStyle: GoogleFonts.openSans(fontSize: 13, color: c.text3),
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'COULDN\'T LOAD USERS',
            style: GoogleFonts.oswald(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          const Gap(8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(fontSize: 12, color: c.text2),
          ),
          const Gap(16),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          'No users match.',
          style: GoogleFonts.openSans(fontSize: 13, color: c.text2),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_users
```
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/features/admin_users/presentation
git commit -m "feat(admin): users list page

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Users — wire route + sidebar SOON badge

**Files:**
- Modify: `lib/admin/app/router/admin_router.dart`
- Modify: `lib/admin/features/admin_shell/presentation/widgets/admin_sidebar.dart`
- Modify: `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart`

- [ ] **Step 1: Replace the `/users` route builder**

In `admin_router.dart`, change the import line to add:
```dart
import '../../features/admin_users/presentation/pages/admin_users_page.dart';
```
Then replace the `/users` `GoRoute`:
```dart
GoRoute(
  path: AdminRoutes.users,
  builder: (context, state) => const AdminUsersPage(),
),
```

- [ ] **Step 2: Drop `comingSoon: true` on the USERS nav item**

In `admin_sidebar.dart`, find the `_NavItem(... label: 'USERS', ...)` block and remove the `comingSoon: true,` line.

- [ ] **Step 3: Make the USERS dashboard card clickable**

In `admin_dashboard_page.dart`, in `_PlaceholderGrid` find the USERS `_ComingSoonCard` and add `route: AdminRoutes.users,`.

- [ ] **Step 4: Run analyzer**

```bash
flutter analyze --no-fatal-infos lib/admin
```
Expected: zero errors.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/app/router/admin_router.dart lib/admin/features/admin_shell/presentation
git commit -m "feat(admin): wire users page into router + sidebar

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: Jobs — domain layer

**Files:**
- Create: `lib/admin/features/admin_jobs/domain/entities/admin_job_row.dart`
- Create: `lib/admin/features/admin_jobs/domain/entities/admin_job_filter.dart`
- Create: `lib/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart`
- Create: `lib/admin/features/admin_jobs/domain/usecases/list_admin_jobs.dart`
- Create: `test/admin/features/admin_jobs/domain/usecases/list_admin_jobs_test.dart`

- [ ] **Step 1: Entity**

```dart
// lib/admin/features/admin_jobs/domain/entities/admin_job_row.dart
import 'package:equatable/equatable.dart';

class AdminJobRow extends Equatable {
  const AdminJobRow({
    required this.id,
    required this.title,
    required this.status,
    required this.builderDisplayName,
    required this.applicationCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status; // draft | open | filled | closed | cancelled
  final String builderDisplayName;
  final int applicationCount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        builderDisplayName,
        applicationCount,
        createdAt,
      ];
}
```

- [ ] **Step 2: Filter enum**

```dart
// lib/admin/features/admin_jobs/domain/entities/admin_job_filter.dart
enum AdminJobStatusFilter { all, draft, open, filled, closed, cancelled }

String? adminJobStatusFilterToDb(AdminJobStatusFilter f) => switch (f) {
      AdminJobStatusFilter.all => null,
      AdminJobStatusFilter.draft => 'draft',
      AdminJobStatusFilter.open => 'open',
      AdminJobStatusFilter.filled => 'filled',
      AdminJobStatusFilter.closed => 'closed',
      AdminJobStatusFilter.cancelled => 'cancelled',
    };
```

- [ ] **Step 3: Repo contract**

```dart
// lib/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_job_filter.dart';
import '../entities/admin_job_row.dart';

abstract class AdminJobsRepository {
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  });
}
```

- [ ] **Step 4: Use case**

```dart
// lib/admin/features/admin_jobs/domain/usecases/list_admin_jobs.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_job_filter.dart';
import '../entities/admin_job_row.dart';
import '../repositories/admin_jobs_repository.dart';

class ListAdminJobsParams {
  const ListAdminJobsParams({
    required this.limit,
    required this.offset,
    this.filter = AdminJobStatusFilter.all,
  });

  final int limit;
  final int offset;
  final AdminJobStatusFilter filter;
}

class ListAdminJobs {
  const ListAdminJobs(this._repository);

  final AdminJobsRepository _repository;

  Future<Either<Failure, List<AdminJobRow>>> call(
    ListAdminJobsParams params,
  ) {
    return _repository.listJobs(
      limit: params.limit,
      offset: params.offset,
      filter: params.filter,
    );
  }
}
```

- [ ] **Step 5: Test**

```dart
// test/admin/features/admin_jobs/domain/usecases/list_admin_jobs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_filter.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_row.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/usecases/list_admin_jobs.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminJobsRepository {}

void main() {
  late ListAdminJobs useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminJobs(repo);
  });

  test('forwards params to repository', () async {
    final row = AdminJobRow(
      id: 'j1',
      title: 'Build a deck',
      status: 'open',
      builderDisplayName: 'Acme',
      applicationCount: 3,
      createdAt: DateTime(2026, 1, 1),
    );
    when(() => repo.listJobs(
          limit: 50,
          offset: 0,
          filter: AdminJobStatusFilter.open,
        )).thenAnswer((_) async => Right([row]));

    final result = await useCase(const ListAdminJobsParams(
      limit: 50,
      offset: 0,
      filter: AdminJobStatusFilter.open,
    ));

    expect(result.isRight(), isTrue);
    verify(() => repo.listJobs(
          limit: 50,
          offset: 0,
          filter: AdminJobStatusFilter.open,
        )).called(1);
  });

  test('propagates failures', () async {
    when(() => repo.listJobs(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(const ListAdminJobsParams(limit: 50, offset: 0));

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 6: Run test**

```bash
flutter test test/admin/features/admin_jobs/domain/usecases/list_admin_jobs_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/admin/features/admin_jobs/domain test/admin/features/admin_jobs
git commit -m "feat(admin): jobs list domain layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: Jobs — data layer

**Files:**
- Create: `lib/admin/features/admin_jobs/data/repositories/admin_jobs_repository_impl.dart`

- [ ] **Step 1: Write the impl**

```dart
// lib/admin/features/admin_jobs/data/repositories/admin_jobs_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../../domain/repositories/admin_jobs_repository.dart';

class AdminJobsRepositoryImpl implements AdminJobsRepository {
  AdminJobsRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  }) async {
    try {
      var builder = _client.from('jobs').select(
            'id, title, status, application_count, created_at, '
            'profiles!jobs_builder_id_fkey(display_name)',
          );

      final dbStatus = adminJobStatusFilterToDb(filter);
      if (dbStatus != null) {
        builder = builder.eq('status', dbStatus);
      }

      final rows = await builder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_toRow)
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  AdminJobRow _toRow(Map<String, dynamic> r) {
    final builder = r['profiles'] as Map<String, dynamic>?;
    return AdminJobRow(
      id: r['id'] as String,
      title: r['title'] as String,
      status: r['status'] as String,
      builderDisplayName:
          (builder?['display_name'] as String?)?.trim().isNotEmpty == true
              ? (builder!['display_name'] as String).trim()
              : '—',
      applicationCount: (r['application_count'] as int?) ?? 0,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    );
  }
}
```

- [ ] **Step 2: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_jobs
git add lib/admin/features/admin_jobs/data
git commit -m "feat(admin): jobs list data layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 12: Jobs — provider + page

**Files:**
- Create: `lib/admin/features/admin_jobs/presentation/providers/admin_jobs_provider.dart`
- Create: `lib/admin/features/admin_jobs/presentation/widgets/admin_job_list_row.dart`
- Create: `lib/admin/features/admin_jobs/presentation/pages/admin_jobs_page.dart`

- [ ] **Step 1: Provider**

Same shape as users provider; just swaps the use case and state class.

```dart
// lib/admin/features/admin_jobs/presentation/providers/admin_jobs_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_jobs_repository_impl.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../../domain/repositories/admin_jobs_repository.dart';
import '../../domain/usecases/list_admin_jobs.dart';

const int kAdminJobsPageSize = 50;

final adminJobsRepositoryProvider = Provider<AdminJobsRepository>(
  (ref) => AdminJobsRepositoryImpl(),
);

final listAdminJobsProvider = Provider<ListAdminJobs>(
  (ref) => ListAdminJobs(ref.watch(adminJobsRepositoryProvider)),
);

class AdminJobsState {
  const AdminJobsState({required this.filter});
  final AdminJobStatusFilter filter;
  AdminJobsState copyWith({AdminJobStatusFilter? filter}) =>
      AdminJobsState(filter: filter ?? this.filter);
}

final adminJobsProvider =
    NotifierProvider<AdminJobsController, AdminJobsState>(
  AdminJobsController.new,
);

class AdminJobsController extends Notifier<AdminJobsState> {
  late final PagingController<int, AdminJobRow> pagingController;

  @override
  AdminJobsState build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
    return const AdminJobsState(filter: AdminJobStatusFilter.all);
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminJobsProvider);
    final result = await useCase(ListAdminJobsParams(
      limit: kAdminJobsPageSize,
      offset: offset,
      filter: state.filter,
    ));
    result.fold(
      (failure) => pagingController.error = failure.message,
      (rows) {
        final isLast = rows.length < kAdminJobsPageSize;
        if (isLast) {
          pagingController.appendLastPage(rows);
        } else {
          pagingController.appendPage(rows, offset + rows.length);
        }
      },
    );
  }

  void setFilter(AdminJobStatusFilter f) {
    if (f == state.filter) return;
    state = state.copyWith(filter: f);
    pagingController.refresh();
  }

  Future<void> refresh() async => pagingController.refresh();
}
```

- [ ] **Step 2: Row widget**

```dart
// lib/admin/features/admin_jobs/presentation/widgets/admin_job_list_row.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../domain/entities/admin_job_row.dart';

class AdminJobListRow extends StatelessWidget {
  const AdminJobListRow({super.key, required this.row});
  final AdminJobRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                const Gap(2),
                Text(
                  '${row.builderDisplayName} · ${row.applicationCount} applicant${row.applicationCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          _StatusPill(status: row.status),
          const Gap(12),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color bg = switch (status) {
      'open' => c.action,
      'filled' => c.surfaceRaised,
      'closed' || 'cancelled' => c.surfaceRaised,
      _ => c.surfaceRaised,
    };
    final Color fg = status == 'open' ? c.background : c.text1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.openSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: fg,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Page**

```dart
// lib/admin/features/admin_jobs/presentation/pages/admin_jobs_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../providers/admin_jobs_provider.dart';
import '../widgets/admin_job_list_row.dart';

class AdminJobsPage extends ConsumerWidget {
  const AdminJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller =
        ref.watch(adminJobsProvider.notifier).pagingController;
    final stateValue = ref.watch(adminJobsProvider);

    return AdminScaffold(
      title: 'JOBS',
      activeRoute: AdminRoutes.jobs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(active: stateValue.filter),
          const Gap(16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(adminJobsProvider.notifier).refresh(),
              child: PagedListView<int, AdminJobRow>(
                pagingController: controller,
                builderDelegate: PagedChildBuilderDelegate<AdminJobRow>(
                  itemBuilder: (_, row, __) => AdminJobListRow(row: row),
                  firstPageProgressIndicatorBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  newPageProgressIndicatorBuilder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.text3,
                        ),
                      ),
                    ),
                  ),
                  firstPageErrorIndicatorBuilder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'COULDN\'T LOAD JOBS',
                          style: GoogleFonts.oswald(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          controller.error?.toString() ?? 'Try again.',
                          textAlign: TextAlign.center,
                          style:
                              GoogleFonts.openSans(fontSize: 12, color: c.text2),
                        ),
                        const Gap(16),
                        TextButton(
                          onPressed: () => controller.refresh(),
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No jobs match.',
                        style: GoogleFonts.openSans(
                          fontSize: 13,
                          color: c.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.active});
  final AdminJobStatusFilter active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      (AdminJobStatusFilter.all, 'ALL'),
      (AdminJobStatusFilter.draft, 'DRAFT'),
      (AdminJobStatusFilter.open, 'OPEN'),
      (AdminJobStatusFilter.filled, 'FILLED'),
      (AdminJobStatusFilter.closed, 'CLOSED'),
      (AdminJobStatusFilter.cancelled, 'CANCELLED'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (filter, label) in filters)
          _Chip(
            label: label,
            isActive: filter == active,
            onTap: () =>
                ref.read(adminJobsProvider.notifier).setFilter(filter),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: isActive ? c.action : c.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? c.background : c.text1,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_jobs
git add lib/admin/features/admin_jobs/presentation
git commit -m "feat(admin): jobs list provider + page

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 13: Jobs — wire route + sidebar SOON badge

**Files:**
- Modify: `lib/admin/app/router/admin_router.dart`
- Modify: `lib/admin/features/admin_shell/presentation/widgets/admin_sidebar.dart`
- Modify: `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart`

- [ ] **Step 1: Replace the `/jobs` route builder**

Add import in `admin_router.dart`:
```dart
import '../../features/admin_jobs/presentation/pages/admin_jobs_page.dart';
```
Replace the `/jobs` `GoRoute`:
```dart
GoRoute(
  path: AdminRoutes.jobs,
  builder: (context, state) => const AdminJobsPage(),
),
```

- [ ] **Step 2: Drop `comingSoon: true` on the JOBS nav item in `admin_sidebar.dart`**

- [ ] **Step 3: In `admin_dashboard_page.dart`, add `route: AdminRoutes.jobs` to the JOBS `_ComingSoonCard`**

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin
git add lib/admin/app/router/admin_router.dart lib/admin/features/admin_shell/presentation
git commit -m "feat(admin): wire jobs page into router + sidebar

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 14: Audit — domain layer

**Files:**
- Create: `lib/admin/features/admin_audit/domain/entities/admin_audit_event.dart`
- Create: `lib/admin/features/admin_audit/domain/repositories/admin_audit_repository.dart`
- Create: `lib/admin/features/admin_audit/domain/usecases/list_admin_audit_events.dart`
- Create: `test/admin/features/admin_audit/domain/usecases/list_admin_audit_events_test.dart`

- [ ] **Step 1: Entity**

```dart
// lib/admin/features/admin_audit/domain/entities/admin_audit_event.dart
import 'package:equatable/equatable.dart';

enum AdminAuditSource { verification, role }

class AdminAuditEvent extends Equatable {
  const AdminAuditEvent({
    required this.id,
    required this.occurredAt,
    required this.source,
    required this.eventType,
    this.actorId,
    this.targetUserId,
    this.payloadPreview,
  });

  final String id;
  final DateTime occurredAt;
  final AdminAuditSource source;
  final String eventType;
  final String? actorId;
  final String? targetUserId;
  final String? payloadPreview;

  @override
  List<Object?> get props => [
        id,
        occurredAt,
        source,
        eventType,
        actorId,
        targetUserId,
        payloadPreview,
      ];
}
```

- [ ] **Step 2: Repo contract**

```dart
// lib/admin/features/admin_audit/domain/repositories/admin_audit_repository.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_audit_event.dart';

abstract class AdminAuditRepository {
  Future<Either<Failure, List<AdminAuditEvent>>> listEvents({
    required int limit,
    required int offset,
  });
}
```

- [ ] **Step 3: Use case**

```dart
// lib/admin/features/admin_audit/domain/usecases/list_admin_audit_events.dart
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_audit_event.dart';
import '../repositories/admin_audit_repository.dart';

class ListAdminAuditEventsParams {
  const ListAdminAuditEventsParams({required this.limit, required this.offset});
  final int limit;
  final int offset;
}

class ListAdminAuditEvents {
  const ListAdminAuditEvents(this._repository);

  final AdminAuditRepository _repository;

  Future<Either<Failure, List<AdminAuditEvent>>> call(
    ListAdminAuditEventsParams params,
  ) =>
      _repository.listEvents(limit: params.limit, offset: params.offset);
}
```

- [ ] **Step 4: Test**

```dart
// test/admin/features/admin_audit/domain/usecases/list_admin_audit_events_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_audit/domain/entities/admin_audit_event.dart';
import 'package:jobdun/admin/features/admin_audit/domain/repositories/admin_audit_repository.dart';
import 'package:jobdun/admin/features/admin_audit/domain/usecases/list_admin_audit_events.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminAuditRepository {}

void main() {
  late ListAdminAuditEvents useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminAuditEvents(repo);
  });

  test('forwards params to repository', () async {
    final event = AdminAuditEvent(
      id: 'e1',
      occurredAt: DateTime(2026, 5, 1),
      source: AdminAuditSource.verification,
      eventType: 'document_submitted',
    );
    when(() => repo.listEvents(limit: 50, offset: 0))
        .thenAnswer((_) async => Right([event]));

    final result = await useCase(
      const ListAdminAuditEventsParams(limit: 50, offset: 0),
    );

    expect(result.isRight(), isTrue);
    verify(() => repo.listEvents(limit: 50, offset: 0)).called(1);
  });

  test('propagates failures', () async {
    when(() => repo.listEvents(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(
      const ListAdminAuditEventsParams(limit: 50, offset: 0),
    );

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 5: Test + commit**

```bash
flutter test test/admin/features/admin_audit/domain/usecases/list_admin_audit_events_test.dart
git add lib/admin/features/admin_audit/domain test/admin/features/admin_audit
git commit -m "feat(admin): audit list domain layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 15: Audit — data layer

**Files:**
- Create: `lib/admin/features/admin_audit/data/repositories/admin_audit_repository_impl.dart`

**Note on schema:** `verification_events` columns: `id, user_id, kind, status, reason, created_at`. `user_role_events` columns: `id, user_id, old_role, new_role, changed_by, changed_at, reason`. The impl normalises both into `AdminAuditEvent`.

If either column doesn't exist when this task runs, inspect the migration files (`20260520000002_role_audit_log.sql` and `20260525000001_verifications.sql`) and adjust the field names below to match — DO NOT guess.

- [ ] **Step 1: Inspect schema first**

```bash
grep -nE "create table.*verification_events|create table.*user_role_events" supabase/migrations/*.sql
```
Open both migration files and confirm column names match what's in the code below. Adjust if needed.

- [ ] **Step 2: Write the impl**

```dart
// lib/admin/features/admin_audit/data/repositories/admin_audit_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../../domain/repositories/admin_audit_repository.dart';

class AdminAuditRepositoryImpl implements AdminAuditRepository {
  AdminAuditRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminAuditEvent>>> listEvents({
    required int limit,
    required int offset,
  }) async {
    try {
      // We over-fetch: limit+offset from each source, then merge + sort.
      // For the small admin-event volumes this is fine; revisit if the
      // tables get large.
      final fetchUpper = limit + offset;

      final results = await Future.wait([
        _fetchVerification(fetchUpper),
        _fetchRole(fetchUpper),
      ]);
      final merged = [...results[0], ...results[1]]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      final start = offset.clamp(0, merged.length);
      final end = (offset + limit).clamp(0, merged.length);
      return Right(merged.sublist(start, end));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<List<AdminAuditEvent>> _fetchVerification(int limit) async {
    final rows = await _client
        .from('verification_events')
        .select('id, user_id, kind, status, reason, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final kind = r['kind'] as String?;
      final status = r['status'] as String?;
      final reason = r['reason'] as String?;
      return AdminAuditEvent(
        id: 'v:${r['id']}',
        occurredAt: DateTime.parse(r['created_at'] as String).toLocal(),
        source: AdminAuditSource.verification,
        eventType: '${kind ?? 'verif'}.${status ?? 'event'}',
        targetUserId: r['user_id'] as String?,
        payloadPreview: reason,
      );
    }).toList();
  }

  Future<List<AdminAuditEvent>> _fetchRole(int limit) async {
    final rows = await _client
        .from('user_role_events')
        .select(
          'id, user_id, old_role, new_role, changed_by, changed_at, reason',
        )
        .order('changed_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final oldRole = r['old_role'] as String?;
      final newRole = r['new_role'] as String?;
      final reason = r['reason'] as String?;
      return AdminAuditEvent(
        id: 'r:${r['id']}',
        occurredAt: DateTime.parse(r['changed_at'] as String).toLocal(),
        source: AdminAuditSource.role,
        eventType: 'role.${oldRole ?? '?'}→${newRole ?? '?'}',
        actorId: r['changed_by'] as String?,
        targetUserId: r['user_id'] as String?,
        payloadPreview: reason,
      );
    }).toList();
  }
}
```

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_audit
git add lib/admin/features/admin_audit/data
git commit -m "feat(admin): audit list data layer

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 16: Audit — provider + page

**Files:**
- Create: `lib/admin/features/admin_audit/presentation/providers/admin_audit_provider.dart`
- Create: `lib/admin/features/admin_audit/presentation/widgets/admin_audit_event_row.dart`
- Create: `lib/admin/features/admin_audit/presentation/pages/admin_audit_page.dart`

- [ ] **Step 1: Provider**

```dart
// lib/admin/features/admin_audit/presentation/providers/admin_audit_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_audit_repository_impl.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../../domain/repositories/admin_audit_repository.dart';
import '../../domain/usecases/list_admin_audit_events.dart';

const int kAdminAuditPageSize = 50;

final adminAuditRepositoryProvider = Provider<AdminAuditRepository>(
  (ref) => AdminAuditRepositoryImpl(),
);

final listAdminAuditEventsProvider = Provider<ListAdminAuditEvents>(
  (ref) => ListAdminAuditEvents(ref.watch(adminAuditRepositoryProvider)),
);

final adminAuditProvider =
    NotifierProvider<AdminAuditController, void>(AdminAuditController.new);

class AdminAuditController extends Notifier<void> {
  late final PagingController<int, AdminAuditEvent> pagingController;

  @override
  void build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminAuditEventsProvider);
    final result = await useCase(ListAdminAuditEventsParams(
      limit: kAdminAuditPageSize,
      offset: offset,
    ));
    result.fold(
      (failure) => pagingController.error = failure.message,
      (rows) {
        final isLast = rows.length < kAdminAuditPageSize;
        if (isLast) {
          pagingController.appendLastPage(rows);
        } else {
          pagingController.appendPage(rows, offset + rows.length);
        }
      },
    );
  }

  Future<void> refresh() async => pagingController.refresh();
}
```

- [ ] **Step 2: Row widget**

```dart
// lib/admin/features/admin_audit/presentation/widgets/admin_audit_event_row.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../domain/entities/admin_audit_event.dart';

class AdminAuditEventRow extends StatelessWidget {
  const AdminAuditEventRow({super.key, required this.event});
  final AdminAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = DateFormat('d MMM y · HH:mm');
    final actor = event.actorId == null
        ? '—'
        : '${event.actorId!.substring(0, 8)}…';
    final target = event.targetUserId == null
        ? '—'
        : '${event.targetUserId!.substring(0, 8)}…';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SourcePill(source: event.source),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType.toUpperCase(),
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.text1,
                  ),
                ),
                const Gap(2),
                Text(
                  'actor $actor · target $target',
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
                if (event.payloadPreview != null) ...[
                  const Gap(2),
                  Text(
                    event.payloadPreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.openSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          Text(
            fmt.format(event.occurredAt),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source});
  final AdminAuditSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (source) {
      AdminAuditSource.verification => ('VERIF', c.action),
      AdminAuditSource.role => ('ROLE', c.text2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.openSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Page**

```dart
// lib/admin/features/admin_audit/presentation/pages/admin_audit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../providers/admin_audit_provider.dart';
import '../widgets/admin_audit_event_row.dart';

class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller =
        ref.watch(adminAuditProvider.notifier).pagingController;

    return AdminScaffold(
      title: 'AUDIT LOG',
      activeRoute: AdminRoutes.audit,
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminAuditProvider.notifier).refresh(),
        child: PagedListView<int, AdminAuditEvent>(
          pagingController: controller,
          builderDelegate: PagedChildBuilderDelegate<AdminAuditEvent>(
            itemBuilder: (_, event, __) => AdminAuditEventRow(event: event),
            firstPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            newPageProgressIndicatorBuilder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.text3,
                  ),
                ),
              ),
            ),
            firstPageErrorIndicatorBuilder: (_) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'COULDN\'T LOAD AUDIT LOG',
                    style: GoogleFonts.oswald(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text1,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    controller.error?.toString() ?? 'Try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(fontSize: 12, color: c.text2),
                  ),
                  const Gap(16),
                  TextButton(
                    onPressed: () => controller.refresh(),
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
            noItemsFoundIndicatorBuilder: (_) => Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No audit events yet.',
                  style:
                      GoogleFonts.openSans(fontSize: 13, color: c.text2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin/features/admin_audit
git add lib/admin/features/admin_audit/presentation
git commit -m "feat(admin): audit list provider + page

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 17: Audit — wire route + sidebar SOON badge + delete placeholder page

**Files:**
- Modify: `lib/admin/app/router/admin_router.dart`
- Modify: `lib/admin/features/admin_shell/presentation/widgets/admin_sidebar.dart`
- Modify: `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart`
- Delete: `lib/admin/features/admin_shell/presentation/pages/admin_placeholder_page.dart`

- [ ] **Step 1: Replace the `/audit` route builder**

Add import in `admin_router.dart`:
```dart
import '../../features/admin_audit/presentation/pages/admin_audit_page.dart';
```
Replace the `/audit` `GoRoute`:
```dart
GoRoute(
  path: AdminRoutes.audit,
  builder: (context, state) => const AdminAuditPage(),
),
```

- [ ] **Step 2: Drop `comingSoon: true` on the AUDIT LOG nav item in `admin_sidebar.dart`**

- [ ] **Step 3: Add `route: AdminRoutes.audit` to the AUDIT LOG `_ComingSoonCard` in `admin_dashboard_page.dart`**

- [ ] **Step 4: Confirm no remaining importers of `AdminPlaceholderPage`**

```bash
grep -rn "AdminPlaceholderPage\|admin_placeholder_page" lib/
```
Expected: zero matches outside `admin_placeholder_page.dart` itself.

- [ ] **Step 5: Delete the placeholder page**

```bash
rm lib/admin/features/admin_shell/presentation/pages/admin_placeholder_page.dart
```

Also remove the `import '../pages/admin_placeholder_page.dart';` and `AppIcons` import line in `admin_router.dart` (the latter only if it was added solely for placeholder bullets — verify by searching the file).

- [ ] **Step 6: Analyze + commit**

```bash
flutter analyze --no-fatal-infos lib/admin
git add lib/admin/app/router/admin_router.dart lib/admin/features/admin_shell/presentation
git rm lib/admin/features/admin_shell/presentation/pages/admin_placeholder_page.dart
git commit -m "feat(admin): wire audit page + drop placeholder scaffolding

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 18: Validation gate + manual verification

- [ ] **Step 1: Run full validate.sh**

```bash
bash scripts/validate.sh
```
Expected: PASS. If file-size budget or design-system grep fails on any new file, split or fix in place before continuing.

- [ ] **Step 2: Run admin web app locally**

```bash
flutter run -d chrome -t lib/admin/main_admin.dart \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

- [ ] **Step 3: Manual checks (must all pass)**

Sign in as a promoted admin account (use Supabase Studio with service_role to promote one if needed), then verify:

- Dashboard tiles show real numbers — not `—`, not `…` permanently.
- `NumberFormat` is rendering commas (e.g. `1,234` not `1234`).
- Click TOTAL USERS card (or sidebar USERS) → users list loads. Scroll past 50 rows → next page loads.
- ALL / BUILDERS / TRADES / ADMINS filter chips change results without scroll position issues.
- Search box: type a substring, press Enter → results filter.
- Sidebar JOBS → jobs list loads. Filter chips work.
- Sidebar AUDIT LOG → events list loads (verification + role merged, newest first).
- Pull-to-refresh works on each list page.

- [ ] **Step 4: Mobile RLS regression check**

Sign in to the **mobile** app as a non-admin user. Confirm:
- They still see only their own profile.
- They still see only `status='open'` jobs in the feed (plus their own drafts).
- No new RLS-related errors in `flutter logs`.

- [ ] **Step 5: Final commit (if any cleanups)**

If `scripts/validate.sh` or manual checks surfaced small fixes (typos, oversize file splits), commit them as a single follow-up:

```bash
git add -A
git commit -m "chore(admin): post-verification cleanup

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Self-review summary (already applied)

- Spec coverage: every spec section maps to a task (RLS → Task 1; dashboard → Tasks 2-4; users → Tasks 5-9; jobs → Tasks 10-13; audit → Tasks 14-17; verification plan → Task 18).
- Placeholder scan: no TBDs, no "implement later", no "similar to Task N" hand-waves — each task has full code.
- Type consistency: `AdminUserRow`, `AdminJobRow`, `AdminAuditEvent` are referenced by exact name in their respective use cases, repos, providers, rows, and pages.
- Filter enums match: `AdminUserRoleFilter`, `AdminJobStatusFilter`, `AdminAuditSource` are each defined once and referenced from the matching feature only.
- `kAdminUsersPageSize`, `kAdminJobsPageSize`, `kAdminAuditPageSize` (50) are referenced both in the controller's `_fetchPage` and as the page-size constant for `appendLastPage` detection.
