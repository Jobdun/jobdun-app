import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/domain/repositories/application_repository.dart';
import 'package:jobdun/features/applications/domain/usecases/apply_to_job.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/domain/usecases/get_jobs.dart';

class MockJobRepository extends Mock implements JobRepository {}

class MockApplicationRepository extends Mock implements ApplicationRepository {}

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

JobApplication _application() => JobApplication(
  id: 'app-1',
  jobId: 'job-1',
  tradeId: 'trade-1',
  builderId: 'builder-1',
  status: ApplicationStatus.pending,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  late MockJobRepository mockJobRepo;
  late MockApplicationRepository mockAppRepo;
  late GetJobs getJobs;
  late ApplyToJob applyToJob;

  setUpAll(() => registerFallbackValue(const JobFilter()));

  setUp(() {
    mockJobRepo = MockJobRepository();
    mockAppRepo = MockApplicationRepository();
    getJobs = GetJobs(mockJobRepo);
    applyToJob = ApplyToJob(mockAppRepo);
  });

  group('Fetch jobs', () {
    test('returns list of jobs', () async {
      final jobs = [_job(id: 'job-1'), _job(id: 'job-2')];
      when(
        () => mockJobRepo.getJobs(filter: null, limit: null, offset: null),
      ).thenAnswer((_) async => Right(jobs));

      final result = await getJobs();

      result.fold(
        (_) => fail('expected jobs'),
        (list) => expect(list.length, 2),
      );
    });

    test('returns empty list when no jobs', () async {
      when(
        () => mockJobRepo.getJobs(filter: null, limit: null, offset: null),
      ).thenAnswer((_) async => const Right([]));

      final result = await getJobs();

      result.fold(
        (_) => fail('expected empty list'),
        (list) => expect(list, isEmpty),
      );
    });

    test('returns ServerFailure on database error', () async {
      when(
        () => mockJobRepo.getJobs(filter: null, limit: null, offset: null),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await getJobs();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });

  group('Apply to job', () {
    test('success — returns JobApplication', () async {
      when(
        () => mockAppRepo.applyToJob(
          jobId: 'job-1',
          builderId: 'trade-1',
          coverNote: any(named: 'coverNote'),
          proposedRate: any(named: 'proposedRate'),
          proposedRateType: any(named: 'proposedRateType'),
        ),
      ).thenAnswer((_) async => Right(_application()));

      final result = await applyToJob(jobId: 'job-1', builderId: 'trade-1');

      result.fold((_) => fail('expected application'), (app) {
        expect(app.jobId, 'job-1');
        expect(app.status, ApplicationStatus.pending);
      });
    });

    test('already applied — returns ServerFailure', () async {
      const failure = ServerFailure('Already applied to this job');
      when(
        () => mockAppRepo.applyToJob(
          jobId: 'job-1',
          builderId: 'trade-1',
          coverNote: any(named: 'coverNote'),
          proposedRate: any(named: 'proposedRate'),
          proposedRateType: any(named: 'proposedRateType'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await applyToJob(jobId: 'job-1', builderId: 'trade-1');

      result.fold((f) {
        expect(f, isA<ServerFailure>());
        expect((f as ServerFailure).message, contains('Already applied'));
      }, (_) => fail('expected failure'));
    });
  });
}
