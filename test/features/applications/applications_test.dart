import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/domain/repositories/application_repository.dart';
import 'package:jobdun/features/applications/domain/usecases/get_my_applications.dart';

class MockApplicationRepository extends Mock implements ApplicationRepository {}

JobApplication _app({
  String id = 'app-1',
  ApplicationStatus status = ApplicationStatus.pending,
}) => JobApplication(
  id: id,
  jobId: 'job-1',
  tradeId: 'trade-1',
  builderId: 'builder-1',
  status: status,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  late MockApplicationRepository mockRepo;
  late GetMyApplications getMyApplications;

  setUp(() {
    mockRepo = MockApplicationRepository();
    getMyApplications = GetMyApplications(mockRepo);
  });

  group('Fetch applications', () {
    test('returns list for a trade user', () async {
      final apps = [_app(id: 'app-1'), _app(id: 'app-2')];
      when(
        () => mockRepo.getMyApplications('trade-1'),
      ).thenAnswer((_) async => Right(apps));

      final result = await getMyApplications('trade-1');

      result.fold(
        (_) => fail('expected list'),
        (list) => expect(list.length, 2),
      );
    });

    test('returns empty list when no applications', () async {
      when(
        () => mockRepo.getMyApplications('trade-1'),
      ).thenAnswer((_) async => const Right([]));

      final result = await getMyApplications('trade-1');

      result.fold(
        (_) => fail('expected empty list'),
        (list) => expect(list, isEmpty),
      );
    });

    test('returns ServerFailure on error', () async {
      when(
        () => mockRepo.getMyApplications('trade-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('Query failed')));

      final result = await getMyApplications('trade-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });

  group('Status filter', () {
    test('pending applications can be isolated from a mixed list', () async {
      final mixed = [
        _app(id: 'app-1', status: ApplicationStatus.pending),
        _app(id: 'app-2', status: ApplicationStatus.shortlisted),
        _app(id: 'app-3', status: ApplicationStatus.hired),
      ];
      when(
        () => mockRepo.getMyApplications('trade-1'),
      ).thenAnswer((_) async => Right(mixed));

      final result = await getMyApplications('trade-1');

      result.fold((_) => fail('expected list'), (list) {
        final pending = list
            .where((a) => a.status == ApplicationStatus.pending)
            .toList();
        expect(pending.length, 1);
        expect(pending.first.id, 'app-1');
      });
    });

    test('shortlisted applications are correctly labelled', () {
      final app = _app(status: ApplicationStatus.shortlisted);
      expect(app.status.label, 'Shortlisted');
      expect(app.status.dbValue, 'shortlisted');
    });

    test('declinedByTrade maps to correct db value', () {
      final app = _app(status: ApplicationStatus.declinedByTrade);
      expect(app.status.dbValue, 'declined_by_trade');
      expect(
        ApplicationStatusX.fromDb('declined_by_trade'),
        ApplicationStatus.declinedByTrade,
      );
    });
  });
}
