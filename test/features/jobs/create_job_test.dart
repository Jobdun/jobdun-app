import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/domain/usecases/create_job.dart';

class MockJobRepository extends Mock implements JobRepository {}

Job _job({
  String id = '',
  double? budgetMin = 85,
  BudgetType? budgetType = BudgetType.hourly,
  JobUrgency urgency = JobUrgency.urgent,
  double? latitude = -33.8,
  String? placeId = 'place.parramatta',
}) => Job(
  id: id,
  builderId: 'builder-1',
  title: 'Install 3-phase switchboard',
  description: 'Commercial site in Parramatta',
  tradeTypeRequired: 'Electrician',
  suburb: 'Parramatta',
  state: 'NSW',
  postcode: '2150',
  status: JobStatus.open,
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
  budgetMin: budgetMin,
  budgetType: budgetType,
  urgency: urgency,
  latitude: latitude,
  longitude: latitude == null ? null : 151.0,
  formattedAddress: placeId == null ? null : 'Parramatta, NSW 2150',
  placeId: placeId,
);

void main() {
  // The create path the job-create page now drives:
  //   form values -> domain Job -> repo (JobModel.fromEntity) -> toJson -> insert.
  group('JobModel.fromEntity', () {
    test('copies every domain field onto the model', () {
      final model = JobModel.fromEntity(_job());
      expect(model.builderId, 'builder-1');
      expect(model.tradeTypeRequired, 'Electrician');
      expect(model.suburb, 'Parramatta');
      expect(model.postcode, '2150');
      expect(model.budgetMin, 85);
      expect(model.budgetType, BudgetType.hourly);
      expect(model.urgency, JobUrgency.urgent);
      expect(model.placeId, 'place.parramatta');
    });

    test('toJson omits server-managed columns', () {
      final json = JobModel.fromEntity(_job()).toJson();
      for (final key in const [
        'id',
        'created_at',
        'updated_at',
        'application_count',
        'view_count',
      ]) {
        expect(json.containsKey(key), isFalse, reason: '$key must be omitted');
      }
    });

    test('toJson maps enums to db values + carries the mapped form fields', () {
      final json = JobModel.fromEntity(_job()).toJson();
      expect(json['builder_id'], 'builder-1');
      expect(json['trade_type_required'], 'Electrician');
      expect(json['status'], 'open');
      expect(json['urgency'], 'urgent');
      expect(json['budget_type'], 'hourly');
      expect(json['budget_min'], 85);
      expect(json['suburb'], 'Parramatta');
      expect(json['state'], 'NSW');
      expect(json['postcode'], '2150');
      expect(json['latitude'], -33.8);
      expect(json['place_id'], 'place.parramatta');
    });

    test('toJson omits null lat/lng/place fields (legacy 3-field branch)', () {
      final json = JobModel.fromEntity(
        _job(latitude: null, placeId: null),
      ).toJson();
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json.containsKey('place_id'), isFalse);
      expect(json.containsKey('formatted_address'), isFalse);
      // Mandatory columns are still present.
      expect(json['suburb'], 'Parramatta');
      expect(json['postcode'], '2150');
    });
  });

  group('CreateJob use case', () {
    late MockJobRepository repo;
    setUpAll(() => registerFallbackValue(_job()));
    setUp(() => repo = MockJobRepository());

    test('delegates to the repo and returns the created job', () async {
      final created = _job(id: 'job-1');
      when(() => repo.createJob(any())).thenAnswer((_) async => Right(created));

      final result = await CreateJob(repo).call(_job());

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected job'), (j) => expect(j.id, 'job-1'));
      verify(() => repo.createJob(any())).called(1);
    });

    test('propagates a ServerFailure', () async {
      when(
        () => repo.createJob(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('insert denied')));

      final result = await CreateJob(repo).call(_job());

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });
}
