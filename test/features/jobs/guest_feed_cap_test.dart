import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_interactions_repository.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

class MockJobRepository extends Mock implements JobRepository {}

class MockJobInteractionsRepository extends Mock
    implements JobInteractionsRepository {}

class _GuestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(); // isAuthenticated: false
}

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: true, isRoleLoaded: true);
}

// A deep pool (12) so a passing test proves the controller truncated the
// request — not that the fixture happened to only have a few rows.
List<Job> _pool(int count) => List.generate(
  count,
  (i) => Job(
    id: 'job-$i',
    builderId: 'builder-1',
    title: 'Job #$i',
    description: 'Real open listing #$i',
    tradeTypeRequired: 'Electrician',
    suburb: 'Sydney',
    state: 'NSW',
    postcode: '2000',
    status: JobStatus.open,
    urgency: JobUrgency.standard,
    createdAt: DateTime(2026, 7, i + 1),
    updatedAt: DateTime(2026, 7, i + 1),
  ),
);

void main() {
  late MockJobRepository mockRepo;

  setUpAll(() => registerFallbackValue(const JobFilter()));

  setUp(() {
    mockRepo = MockJobRepository();
    when(
      () => mockRepo.getJobs(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int?;
      final offset = invocation.namedArguments[#offset] as int? ?? 0;
      final pool = _pool(12);
      final page = pool.skip(offset).take(limit ?? pool.length).toList();
      return right(page);
    });
  });

  ProviderContainer buildContainer({required bool authed}) {
    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(mockRepo),
        jobInteractionsRepositoryProvider.overrideWithValue(
          MockJobInteractionsRepository(),
        ),
        authControllerProvider.overrideWith(
          authed ? _AuthedAuthController.new : _GuestAuthController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('guest feed caps at 10 jobs and never requests a second page', () async {
    final container = buildContainer(authed: false);
    final notifier = container.read(jobsControllerProvider.notifier);
    final paging = notifier.pagingController;

    paging.notifyPageRequestListeners(0);
    await pumpEventQueue();

    expect(paging.itemList?.length, 10);
    expect(paging.nextPageKey, isNull); // no further pages for a guest

    // A guest scrolling shouldn't even reach page 2, but if the widget
    // ever requests it, the controller must not serve more data.
    paging.notifyPageRequestListeners(1);
    await pumpEventQueue();
    expect(paging.itemList?.length, 10);

    final captured = verify(
      () => mockRepo.getJobs(
        filter: captureAny(named: 'filter'),
        limit: captureAny(named: 'limit'),
        offset: captureAny(named: 'offset'),
      ),
    ).captured;
    // First (and only) real fetch used limit 10.
    expect(captured[1], 10);
  });

  test('signed-in tradie keeps the normal 20-per-page feed', () async {
    final container = buildContainer(authed: true);
    final notifier = container.read(jobsControllerProvider.notifier);
    final paging = notifier.pagingController;

    paging.notifyPageRequestListeners(0);
    await pumpEventQueue();

    // Pool only has 12 rows, so the 20-wide request comes back short (and
    // is correctly treated as the last page) — the point under test is the
    // requested page size itself, asserted below.
    expect(paging.itemList?.length, 12);

    final captured = verify(
      () => mockRepo.getJobs(
        filter: captureAny(named: 'filter'),
        limit: captureAny(named: 'limit'),
        offset: captureAny(named: 'offset'),
      ),
    ).captured;
    expect(captured[1], 20); // unchanged — no guest cap applied
  });
}
