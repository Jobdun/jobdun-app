import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/domain/usecases/get_jobs.dart';

class MockJobRepository extends Mock implements JobRepository {}

Job _makeJob({String id = 'job-1', String trade = 'Electrician'}) => Job(
  id: id,
  builderId: 'builder-1',
  title: 'Install switchboard',
  description: 'Commercial site in Sydney CBD',
  tradeTypeRequired: trade,
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  urgency: JobUrgency.standard,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  late GetJobs getJobs;
  late MockJobRepository mockRepo;

  setUpAll(() => registerFallbackValue(const JobFilter()));

  setUp(() {
    mockRepo = MockJobRepository();
    getJobs = GetJobs(mockRepo);
  });

  group('GetJobs use case', () {
    test('returns list of jobs with no filter', () async {
      final jobs = [_makeJob(id: 'job-1'), _makeJob(id: 'job-2')];
      when(
        () => mockRepo.getJobs(filter: null),
      ).thenAnswer((_) async => Right(jobs));

      final result = await getJobs();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected jobs'),
        (list) => expect(list.length, 2),
      );
      verify(() => mockRepo.getJobs(filter: null)).called(1);
    });

    test('returns filtered jobs when tradeType is provided', () async {
      final filter = const JobFilter(tradeType: 'Plumber');
      final jobs = [_makeJob(id: 'job-3', trade: 'Plumber')];
      when(
        () => mockRepo.getJobs(filter: filter),
      ).thenAnswer((_) async => Right(jobs));

      final result = await getJobs(filter: filter);

      result.fold((_) => fail('Expected jobs'), (list) {
        expect(list.length, 1);
        expect(list.first.tradeTypeRequired, 'Plumber');
      });
    });

    test('returns empty list when no matching jobs', () async {
      when(
        () => mockRepo.getJobs(filter: null),
      ).thenAnswer((_) async => const Right([]));

      final result = await getJobs();

      result.fold(
        (_) => fail('Expected empty list'),
        (list) => expect(list, isEmpty),
      );
    });

    test('returns ServerFailure on database error', () async {
      const failure = ServerFailure('Query failed');
      when(
        () => mockRepo.getJobs(filter: null),
      ).thenAnswer((_) async => const Left(failure));

      final result = await getJobs();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns NetworkFailure when offline', () async {
      const failure = NetworkFailure();
      when(
        () => mockRepo.getJobs(filter: null),
      ).thenAnswer((_) async => const Left(failure));

      final result = await getJobs();

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
