import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/cache/in_memory_cache_store.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';
import 'package:jobdun/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';

class MockJobRemoteDataSource extends Mock implements JobRemoteDataSource {}

JobModel _jobModel({String id = 'job-1'}) => JobModel(
  id: id,
  builderId: 'b1',
  title: 'Install switchboard',
  description: 'Commercial site',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.filled,
  createdAt: DateTime.utc(2026, 5, 1, 8, 30),
  updatedAt: DateTime.utc(2026, 5, 2, 9),
  urgency: JobUrgency.urgent,
  applicationCount: 4,
  viewCount: 25,
  latitude: -33.87,
  longitude: 151.2,
);

void main() {
  test('toCacheMap round-trips through fromJson (incl. id, dates, counts)', () {
    final model = _jobModel(id: 'job-9');
    final round = JobModel.fromJson(model.toCacheMap());

    expect(round.id, 'job-9');
    expect(round.status, JobStatus.filled);
    expect(round.urgency, JobUrgency.urgent);
    expect(round.applicationCount, 4);
    expect(round.viewCount, 25);
    expect(round.latitude, -33.87);
    expect(round.createdAt, model.createdAt);
    expect(round.updatedAt, model.updatedAt);
  });

  test(
    'getBuilderJobs caches on success and serves last-known on failure',
    () async {
      final ds = MockJobRemoteDataSource();
      final cache = InMemoryCacheStore();
      final repo = JobRepositoryImpl(ds, cache);

      // Online: returns jobs and writes them through to the cache.
      when(
        () => ds.getBuilderJobs('b1'),
      ).thenAnswer((_) async => [_jobModel()]);
      final online = await repo.getBuilderJobs('b1');
      expect(online.isRight(), isTrue);
      online.fold(
        (_) => fail('expected jobs'),
        (jobs) => expect(jobs.single.id, 'job-1'),
      );

      // Offline: datasource throws → serve the cached copy instead of failing.
      when(
        () => ds.getBuilderJobs('b1'),
      ).thenThrow(const ServerException('offline'));
      final offline = await repo.getBuilderJobs('b1');
      expect(offline.isRight(), isTrue, reason: 'last-known served from cache');
      offline.fold(
        (_) => fail('expected cached jobs'),
        (jobs) => expect(jobs.single.id, 'job-1'),
      );
    },
  );

  test(
    'getBuilderJobs returns Left when offline with no cached copy',
    () async {
      final ds = MockJobRemoteDataSource();
      when(
        () => ds.getBuilderJobs(any()),
      ).thenThrow(const ServerException('offline'));
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore());

      final result = await repo.getBuilderJobs('cold-builder');
      expect(result.isLeft(), isTrue);
    },
  );

  test('getJobs caches the default first page and serves it offline', () async {
    final ds = MockJobRemoteDataSource();
    final repo = JobRepositoryImpl(ds, InMemoryCacheStore());

    when(
      () => ds.getJobs(filter: null, limit: null, offset: null),
    ).thenAnswer((_) async => [_jobModel(id: 'feed-1')]);
    final online = await repo.getJobs();
    expect(online.isRight(), isTrue);

    when(
      () => ds.getJobs(filter: null, limit: null, offset: null),
    ).thenThrow(const ServerException('offline'));
    final offline = await repo.getJobs();
    expect(offline.isRight(), isTrue, reason: 'served cached first page');
    offline.fold(
      (_) => fail('expected cached feed'),
      (jobs) => expect(jobs.single.id, 'feed-1'),
    );
  });

  test('getJobs does NOT serve cache for a filtered query', () async {
    final ds = MockJobRemoteDataSource();
    final repo = JobRepositoryImpl(ds, InMemoryCacheStore());
    const filter = JobFilter(searchQuery: 'plumber');

    when(
      () => ds.getJobs(filter: filter, limit: null, offset: null),
    ).thenThrow(const ServerException('offline'));
    final result = await repo.getJobs(filter: filter);
    expect(
      result.isLeft(),
      isTrue,
      reason: 'only the default first page caches',
    );
  });
}
