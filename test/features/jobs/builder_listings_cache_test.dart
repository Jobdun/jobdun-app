import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

class MockJobRepository extends Mock implements JobRepository {}

Job _job({String id = 'job-1'}) => Job(
  id: id,
  builderId: 'builder-1',
  title: 'Install switchboard',
  description: 'Commercial site in Sydney CBD',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  urgency: JobUrgency.standard,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  // Proves Phase 1 caching is actually wired into the real provider (not just
  // the cacheFor primitive): re-entering "Your listings" within the TTL serves
  // the kept-alive result instead of re-hitting the repository.
  test('builderListingsProvider serves from cache within the ttl', () async {
    var calls = 0;
    final repo = MockJobRepository();
    when(() => repo.getBuilderJobs(any())).thenAnswer((_) async {
      calls++;
      return right<Failure, List<Job>>(<Job>[_job()]);
    });

    final container = ProviderContainer(
      overrides: [
        currentUserIdSyncProvider.overrideWithValue('builder-1'),
        jobRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(builderListingsProvider, (_, _) {});
    await container.read(builderListingsProvider.future);
    expect(calls, 1);

    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // unlistened

    container.listen(builderListingsProvider, (_, _) {});
    await container.read(builderListingsProvider.future);
    expect(
      calls,
      1,
      reason: 'within ttl → kept-alive cache reused, no repository re-fetch',
    );
  });

  // Guardrail (docs/CACHING_ARCHITECTURE.md §7): a write must invalidate the
  // cache it affects. Proves listings is in the aggregate set so a create/delete
  // busts it instead of leaving the builder staring at a stale cached list.
  test(
    'invalidating the builder-job aggregate set re-fetches listings',
    () async {
      var calls = 0;
      final repo = MockJobRepository();
      when(() => repo.getBuilderJobs(any())).thenAnswer((_) async {
        calls++;
        return right<Failure, List<Job>>(<Job>[_job()]);
      });

      final container = ProviderContainer(
        overrides: [
          currentUserIdSyncProvider.overrideWithValue('builder-1'),
          jobRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(builderListingsProvider, (_, _) {});
      await container.read(builderListingsProvider.future);
      expect(calls, 1);

      // Simulate a create/delete: invalidate every builder-job aggregate.
      for (final provider in builderJobAggregateProviders) {
        container.invalidate(provider);
      }
      await container.read(builderListingsProvider.future);
      expect(
        calls,
        2,
        reason: 'aggregate set includes listings → cache busted on write',
      );

      sub.close();
    },
  );
}
