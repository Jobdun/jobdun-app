import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/cache/in_memory_cache_store.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/jobs/data/datasources/job_feed_cache_datasource.dart';
import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';
import 'package:jobdun/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';

class MockJobRemoteDataSource extends Mock implements JobRemoteDataSource {}

class MockJobFeedCacheDataSource extends Mock
    implements JobFeedCacheDataSource {}

JobModel _job({String id = 'feed-1'}) => JobModel(
  id: id,
  builderId: 'b1',
  title: 'Install switchboard',
  description: 'Commercial site',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  createdAt: DateTime.utc(2026, 6, 1, 8, 30),
  updatedAt: DateTime.utc(2026, 6, 2, 9),
  urgency: JobUrgency.urgent,
  applicationCount: 0,
  viewCount: 3,
  latitude: -33.87,
  longitude: 151.2,
);

void main() {
  test(
    'first page: server-cache hit returns its jobs and skips the DB',
    () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);

      when(
        () => feed.getFirstPage(limit: 20),
      ).thenAnswer((_) async => [_job(id: 'from-cache')]);

      final res = await repo.getJobs(limit: 20);

      expect(res.isRight(), isTrue);
      res.fold(
        (_) => fail('expected jobs'),
        (j) => expect(j.single.id, 'from-cache'),
      );
      verify(() => feed.getFirstPage(limit: 20)).called(1);
      verifyNever(
        () => ds.getJobs(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    },
  );

  test(
    'first page: server-cache failure falls back to a direct DB read',
    () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);

      when(
        () => feed.getFirstPage(limit: 20),
      ).thenThrow(const ServerException('fn down'));
      when(
        () => ds.getJobs(filter: null, limit: 20, offset: 0),
      ).thenAnswer((_) async => [_job(id: 'from-db')]);

      final res = await repo.getJobs(limit: 20, offset: 0);

      expect(res.isRight(), isTrue);
      res.fold(
        (_) => fail('expected jobs'),
        (j) => expect(j.single.id, 'from-db'),
      );
      verify(() => feed.getFirstPage(limit: 20)).called(1);
      verify(() => ds.getJobs(filter: null, limit: 20, offset: 0)).called(1);
    },
  );

  test('server-cache hit is written through to disk for offline', () async {
    final ds = MockJobRemoteDataSource();
    final feed = MockJobFeedCacheDataSource();
    final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);

    when(
      () => feed.getFirstPage(limit: 20),
    ).thenAnswer((_) async => [_job(id: 'warm')]);
    await repo.getJobs(limit: 20); // populates disk cache from the server hit

    // Now the function AND the datasource are down → disk must serve it.
    when(
      () => feed.getFirstPage(limit: 20),
    ).thenThrow(const ServerException('down'));
    when(
      () => ds.getJobs(filter: null, limit: 20, offset: 0),
    ).thenThrow(const ServerException('offline'));

    final offline = await repo.getJobs(limit: 20, offset: 0);

    expect(offline.isRight(), isTrue, reason: 'disk populated by earlier hit');
    offline.fold(
      (_) => fail('expected cached'),
      (j) => expect(j.single.id, 'warm'),
    );
  });

  test('deeper pages (offset > 0) never consult the server cache', () async {
    final ds = MockJobRemoteDataSource();
    final feed = MockJobFeedCacheDataSource();
    final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);

    when(
      () => ds.getJobs(filter: null, limit: 20, offset: 20),
    ).thenAnswer((_) async => [_job(id: 'p2')]);

    final res = await repo.getJobs(limit: 20, offset: 20);

    expect(res.isRight(), isTrue);
    verifyNever(() => feed.getFirstPage(limit: any(named: 'limit')));
    verify(() => ds.getJobs(filter: null, limit: 20, offset: 20)).called(1);
  });

  test('unbounded first page (limit null) bypasses the server cache', () async {
    final ds = MockJobRemoteDataSource();
    final feed = MockJobFeedCacheDataSource();
    final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);

    when(
      () => ds.getJobs(filter: null, limit: null, offset: null),
    ).thenAnswer((_) async => [_job(id: 'all')]);

    final res = await repo.getJobs();

    expect(res.isRight(), isTrue);
    verifyNever(() => feed.getFirstPage(limit: any(named: 'limit')));
    verify(() => ds.getJobs(filter: null, limit: null, offset: null)).called(1);
  });

  group('invalidation on write', () {
    setUpAll(() => registerFallbackValue(_job()));

    test('createJob success fires a best-effort feed invalidation', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(() => ds.createJob(any())).thenAnswer((_) async => _job(id: 'new'));
      when(() => feed.invalidate()).thenAnswer((_) async {});

      final res = await repo.createJob(_job(id: 'new'));

      expect(res.isRight(), isTrue);
      verify(() => feed.invalidate()).called(1);
    });

    test('updateJob success fires invalidation', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(() => ds.updateJob(any())).thenAnswer((_) async => _job());
      when(() => feed.invalidate()).thenAnswer((_) async {});

      await repo.updateJob(_job());

      verify(() => feed.invalidate()).called(1);
    });

    test('softDeleteJob success fires invalidation', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(() => ds.softDeleteJob(any())).thenAnswer((_) async {});
      when(() => feed.invalidate()).thenAnswer((_) async {});

      await repo.softDeleteJob('job-1');

      verify(() => feed.invalidate()).called(1);
    });

    test('updateJobStatus success fires invalidation', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(
        () => ds.updateJobStatus(any(), JobStatus.filled),
      ).thenAnswer((_) async {});
      when(() => feed.invalidate()).thenAnswer((_) async {});

      await repo.updateJobStatus('job-1', JobStatus.filled);

      verify(() => feed.invalidate()).called(1);
    });

    test('a failed write does NOT invalidate', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(() => ds.createJob(any())).thenThrow(const ServerException('boom'));

      final res = await repo.createJob(_job());

      expect(res.isLeft(), isTrue);
      verifyNever(() => feed.invalidate());
    });

    test('invalidation failure never fails the write', () async {
      final ds = MockJobRemoteDataSource();
      final feed = MockJobFeedCacheDataSource();
      final repo = JobRepositoryImpl(ds, InMemoryCacheStore(), feed);
      when(() => ds.createJob(any())).thenAnswer((_) async => _job(id: 'ok'));
      when(
        () => feed.invalidate(),
      ).thenAnswer((_) async => throw const ServerException('redis down'));

      final res = await repo.createJob(_job(id: 'ok'));

      expect(res.isRight(), isTrue, reason: 'write survives a bad invalidate');
      res.fold((_) => fail('expected job'), (j) => expect(j.id, 'ok'));
    });
  });
}
