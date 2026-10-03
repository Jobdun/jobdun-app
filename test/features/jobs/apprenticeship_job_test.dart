import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/usecases/validate_job.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_detail_args.dart';

JobModel row([Map<String, dynamic> extra = const {}]) => JobModel.fromJson({
  'id': 'job-1',
  'builder_id': 'builder-1',
  'title': 'Carpentry apprenticeship',
  'description': 'Learn framing with our team.',
  'trade_type_required': 'Carpenter',
  'suburb': 'Sydney',
  'state': 'NSW',
  'postcode': '2000',
  'status': 'open',
  'created_at': '2026-09-15T00:00:00Z',
  'updated_at': '2026-09-15T00:00:00Z',
  ...extra,
});

const apprenticeship = <String, dynamic>{
  'job_kind': 'apprenticeship',
  'open_to_apprentices': true,
  'pricing_unit': 'hourly',
  'pricing_type': 'builder_set',
  'budget_amount': 25.75,
  'requires_public_liability': false,
  'requires_verified': false,
};

void main() {
  test('legacy jobs stay trade jobs', () {
    expect(row().jobKind, JobKind.tradeJob);
    expect(row().isApprenticeship, isFalse);
  });
  test(
    'kind and cents survive entity, write, cache and detail projections',
    () {
      final job = row(apprenticeship);
      final model = JobModel.fromEntity(job);
      expect(model.toJson()['job_kind'], 'apprenticeship');
      final cached = JobModel.fromJson(model.toCacheMap());
      expect(cached.isApprenticeship, isTrue);
      expect(cached.displayBudget, '\$25.75/hr');
      expect(cached.compactBudget, '\$25.75/hr');
      expect(JobDetailArgs.fromJob(cached).isApprenticeship, isTrue);
      expect(JobDetailArgs.fromJob(cached).openToApprentices, isTrue);
    },
  );
  test('filled positions cannot accept another application', () {
    expect(
      JobDetailArgs.fromJob(
        row({...apprenticeship, 'status': 'filled'}),
      ).canApply,
      isFalse,
    );
    expect(JobDetailArgs.fromJob(row(apprenticeship)).canApply, isTrue);
  });
  test('kind and invitation changes affect job equality', () {
    expect(row(), isNot(row(apprenticeship)));
    expect(row(), isNot(row({'open_to_apprentices': true})));
  });
  test('apprenticeship validation rejects incompatible pay and flags', () {
    expect(validateJob(row(apprenticeship)), isNull);
    for (final invalid in [
      {'pricing_unit': 'per_job'},
      {'pricing_type': 'request_quote'},
      {'budget_amount': null},
      {'budget_amount': 0},
      {'budget_amount': -1},
      {'budget_amount': double.nan},
      {'budget_amount': double.infinity},
      {'open_to_apprentices': false},
    ]) {
      expect(
        validateJob(row({...apprenticeship, ...invalid})),
        isNotNull,
        reason: invalid.toString(),
      );
    }
    expect(validateJob(row()), isNull);
  });
  test('apprentice filters are non-empty and distinct cache queries', () {
    const all = JobFilter();
    const vacancies = JobFilter(jobKind: JobKind.apprenticeship);
    const invited = JobFilter(openToApprentices: true);
    expect(vacancies.isEmpty, isFalse);
    expect(invited.isEmpty, isFalse);
    expect(all, isNot(vacancies));
    expect(vacancies, isNot(invited));
  });
}
