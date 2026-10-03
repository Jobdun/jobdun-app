import 'dart:async';
import 'package:jobdun/core/errors/failures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_interactions_repository.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

class _Repo extends Mock implements JobRepository {}

class _Interactions extends Mock implements JobInteractionsRepository {}

class _Auth extends AuthController {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: true, isRoleLoaded: true);
}

void main() {
  setUpAll(() => registerFallbackValue(const JobFilter()));
  test(
    'vacancy filter survives search, trade clear and builder scope',
    () async {
      final repo = _Repo();
      final calls = <JobFilter?>[];
      when(
        () => repo.getJobs(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((call) async {
        calls.add(call.namedArguments[#filter] as JobFilter?);
        return const Right([]);
      });
      final container = ProviderContainer(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          jobInteractionsRepositoryProvider.overrideWithValue(_Interactions()),
          authControllerProvider.overrideWith(_Auth.new),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(jobsControllerProvider.notifier);
      await controller.filterOpportunities(jobKind: JobKind.apprenticeship);
      await controller.search('Sydney');
      await controller.applyFilter('Carpenter');
      await controller.applyFilter(null);
      expect(calls.last?.jobKind, JobKind.apprenticeship);
      expect(calls.last?.searchQuery, 'Sydney');
      expect(calls.last?.tradeType, isNull);
      controller.setBuilderScope('builder-1');
      await controller.refresh();
      expect(calls.last?.jobKind, JobKind.apprenticeship);
      expect(calls.last?.builderId, 'builder-1');
      await controller.filterOpportunities(openToApprentices: true);
      expect(calls.last?.jobKind, isNull);
      expect(calls.last?.openToApprentices, true);
      expect(calls.last?.searchQuery, 'Sydney');
      controller.clearFilter();
      await pumpEventQueue();
      expect(calls.last?.openToApprentices, isNull);
    },
  );
  test('refresh rejects an old page before replacement fetch starts', () async {
    final repo = _Repo();
    final pending = Completer<Either<Failure, List<Job>>>();
    final replacement = Completer<Either<Failure, List<Job>>>();
    var requests = 0;
    when(
      () => repo.getJobs(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => requests++ == 0 ? pending.future : replacement.future);
    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        jobInteractionsRepositoryProvider.overrideWithValue(_Interactions()),
        authControllerProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(jobsControllerProvider.notifier);
    final paging = controller.pagingController;
    paging.notifyPageRequestListeners(0);
    await controller.filterOpportunities(jobKind: JobKind.apprenticeship);
    pending.complete(const Right([]));
    await pumpEventQueue();
    // Old-query completion must not end the replacement query's loading state.
    expect(paging.itemList, isNull);
    expect(requests, 2);
    replacement.complete(const Right([]));
    await pumpEventQueue();
    expect(paging.itemList, isEmpty);
  });
}
