import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:jobdun/app/router/app_router.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/pending_return_provider.dart';
import 'package:jobdun/features/applications/presentation/providers/applications_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/ftue/presentation/providers/ftue_gate_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_interactions_repository.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

/// App Review 5.1.1(v) routing contract: guests browse /browse and single
/// job details freely; account-based routes bounce to /login; after auth the
/// pending guest-gate destination is honoured exactly once.
final _testJob = Job(
  id: 'test-job-1',
  builderId: 'b1',
  title: '3-phase switchboard install',
  description: 'Licensed sparkie needed for a switchboard upgrade.',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  createdAt: DateTime(2026, 7, 18),
  updatedAt: DateTime(2026, 7, 18),
);

class _FakeJobRepository implements JobRepository {
  @override
  Future<Either<Failure, List<Job>>> getJobs({
    JobFilter? filter,
    int? limit,
    int? offset,
  }) async => right(const []);

  @override
  Future<Either<Failure, List<Job>>> getBuilderJobs(String builderId) async =>
      right(const []);

  @override
  Future<Either<Failure, Job>> getJobById(String id) async => right(_testJob);

  @override
  Future<Either<Failure, Job>> createJob(Job job) async =>
      left(ServerFailure('unsupported in test'));

  @override
  Future<Either<Failure, Job>> updateJob(Job job) async =>
      left(ServerFailure('unsupported in test'));

  @override
  Future<Either<Failure, void>> softDeleteJob(String id) async => right(null);

  @override
  Future<Either<Failure, void>> updateJobStatus(
    String id,
    JobStatus status,
  ) async => right(null);

  @override
  Stream<List<Job>> watchBuilderJobs(String builderId) => const Stream.empty();
}

class _FakeInteractionsRepository implements JobInteractionsRepository {
  @override
  Future<Either<Failure, void>> saveJob(String userId, String jobId) async =>
      right(null);

  @override
  Future<Either<Failure, void>> unsaveJob(String userId, String jobId) async =>
      right(null);

  @override
  Future<Either<Failure, void>> hideJob(String userId, String jobId) async =>
      right(null);

  @override
  Future<Either<Failure, Set<String>>> getSavedJobIds(String userId) async =>
      right(const {});

  @override
  Future<Either<Failure, Set<String>>> getHiddenJobIds(String userId) async =>
      right(const {});

  @override
  Future<Either<Failure, List<Job>>> getSavedJobs(String userId) async =>
      right(const []);
}

class _FakeFtueGate extends FtueGate {
  @override
  FtueGateState build() =>
      const FtueGateState(isLoaded: true, hasCompleted: true);
}

class _FakeApplicationsController extends ApplicationsController {
  @override
  ApplicationsState build() => const ApplicationsState();

  @override
  Future<void> loadMyApplications(String userId) async {
    // no-op in tests — the detail page calls this for signed-in users only.
  }
}

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: true, isRoleLoaded: true);
}

// The tab shell (mounted beneath /jobs/:id) watches the profile for its nav
// avatar — keep it off Supabase in tests.
class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState();

  @override
  Future<void> loadProfile() async {
    // no-op in tests.
  }
}

void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool authed = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(_FakeJobRepository()),
        jobInteractionsRepositoryProvider.overrideWithValue(
          _FakeInteractionsRepository(),
        ),
        ftueGateProvider.overrideWith(_FakeFtueGate.new),
        applicationsControllerProvider.overrideWith(
          _FakeApplicationsController.new,
        ),
        profileControllerProvider.overrideWith(_FakeProfileController.new),
        myVerificationsProvider.overrideWithValue(
          const AsyncData(<Verification>[]),
        ),
        if (authed)
          authControllerProvider.overrideWith(_AuthedAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.dark(),
              debugShowCheckedModeBanner: false,
              routerConfig: ref.watch(appRouterProvider),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  String pathOf(ProviderContainer container) => container
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  testWidgets('guest can browse jobs and open a job detail', (tester) async {
    final container = await pumpApp(tester);
    final router = container.read(appRouterProvider);

    router.go('/browse');
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(pathOf(container), '/browse');
    // PageHeader uppercases titles at render.
    expect(find.text('OPEN NEAR YOU'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget); // guest header CTA
    expect(find.text('SAVED'), findsNothing); // account-based chip hidden

    router.go('/jobs/test-job-1');
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(pathOf(container), '/jobs/test-job-1');
    // Loader fetched via the (fake) repo and rendered the real detail page.
    expect(find.text('3-PHASE SWITCHBOARD INSTALL'), findsOneWidget);
    expect(find.text('QUOTE THIS JOB'), findsOneWidget);
  });

  testWidgets('account-based routes still bounce guests to /login', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final router = container.read(appRouterProvider);

    for (final blocked in ['/applications', '/jobs/create', '/messages']) {
      router.go(blocked);
      await tester.pumpAndSettle();
      drainKnownOverflow(tester);
      expect(pathOf(container), '/login', reason: '$blocked must be gated');
    }
  });

  testWidgets('authenticated /login redirect honours pendingReturn once', (
    tester,
  ) async {
    final container = await pumpApp(tester, authed: true);
    final router = container.read(appRouterProvider);
    container.read(pendingReturnProvider.notifier).set('/jobs/test-job-1');

    router.go('/login');
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(pathOf(container), '/jobs/test-job-1');
    // Consumed exactly once — a later auth-page bounce falls back to /home.
    expect(container.read(pendingReturnProvider), isNull);
  });
}
