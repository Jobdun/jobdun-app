import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/domain/repositories/application_repository.dart';
import 'package:jobdun/features/applications/domain/usecases/apply_to_job.dart';

class MockApplicationRepository extends Mock implements ApplicationRepository {}

JobApplication _makeApplication({
  String id = 'app-1',
  ApplicationStatus status = ApplicationStatus.pending,
}) => JobApplication(
  id: id,
  jobId: 'job-1',
  tradeId: 'trade-1',
  builderId: 'builder-1',
  status: status,
  createdAt: DateTime(2026, 5, 11),
  updatedAt: DateTime(2026, 5, 11),
);

void main() {
  late ApplyToJob applyToJob;
  late MockApplicationRepository mockRepo;

  setUp(() {
    mockRepo = MockApplicationRepository();
    applyToJob = ApplyToJob(mockRepo);
  });

  const tJobId = 'job-1';
  const tBuilderId = 'builder-1';

  group('ApplyToJob use case', () {
    test('returns JobApplication with pending status on success', () async {
      final application = _makeApplication();
      when(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: any(named: 'coverNote'),
          quoteAmount: any(named: 'quoteAmount'),
        ),
      ).thenAnswer((_) async => Right(application));

      final result = await applyToJob(jobId: tJobId, builderId: tBuilderId);

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected application'), (app) {
        expect(app.status, ApplicationStatus.pending);
        expect(app.jobId, tJobId);
      });
    });

    test('passes cover note and quote to repository', () async {
      final application = _makeApplication();
      when(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: 'Available immediately',
          quoteAmount: 85.0,
        ),
      ).thenAnswer((_) async => Right(application));

      await applyToJob(
        jobId: tJobId,
        builderId: tBuilderId,
        coverNote: 'Available immediately',
        quoteAmount: 85.0,
      );

      verify(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: 'Available immediately',
          quoteAmount: 85.0,
        ),
      ).called(1);
    });

    test('returns PermissionFailure when already applied', () async {
      const failure = PermissionFailure('Already applied to this job.');
      when(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: any(named: 'coverNote'),
          quoteAmount: any(named: 'quoteAmount'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await applyToJob(jobId: tJobId, builderId: tBuilderId);

      result.fold(
        (f) => expect(f, isA<PermissionFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns ServerFailure on database error', () async {
      const failure = ServerFailure('Insert failed');
      when(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: any(named: 'coverNote'),
          quoteAmount: any(named: 'quoteAmount'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await applyToJob(jobId: tJobId, builderId: tBuilderId);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns NetworkFailure when offline', () async {
      const failure = NetworkFailure();
      when(
        () => mockRepo.applyToJob(
          jobId: tJobId,
          builderId: tBuilderId,
          coverNote: any(named: 'coverNote'),
          quoteAmount: any(named: 'quoteAmount'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await applyToJob(jobId: tJobId, builderId: tBuilderId);

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
