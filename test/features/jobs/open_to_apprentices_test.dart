import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';

Map<String, dynamic> _row([Map<String, dynamic> extra = const {}]) => {
  'id': 'j1',
  'builder_id': 'b1',
  'title': 'Framing',
  'description': 'Two weeks of framing.',
  'trade_type_required': 'carpenter',
  'suburb': 'Blacktown',
  'state': 'NSW',
  'postcode': '2148',
  'status': 'open',
  'created_at': '2026-08-31T00:00:00.000Z',
  'updated_at': '2026-08-31T00:00:00.000Z',
  ...extra,
};

void main() {
  group('Job.openToApprentices', () {
    test('defaults to false when the column is absent', () {
      expect(JobModel.fromJson(_row()).openToApprentices, isFalse);
    });

    test('parses true', () {
      expect(
        JobModel.fromJson(
          _row({'open_to_apprentices': true}),
        ).openToApprentices,
        isTrue,
      );
    });

    test('survives a toJson round-trip', () {
      final job = JobModel.fromJson(_row({'open_to_apprentices': true}));
      expect(job.toJson()['open_to_apprentices'], true);
      expect(JobModel.fromJson(_row(job.toJson())).openToApprentices, isTrue);
    });
  });

  group('feed projection', () {
    // Regression guard for the exact bug class already recorded in the jobs
    // field gotchas: job_remote_datasource hand-writes its column list, so a
    // new column that is added to the table but NOT to the projection makes
    // fromJson silently read a missing key and default every job to false.
    final columns = JobRemoteDataSourceImpl.feedColumns
        .split(',')
        .map((c) => c.trim())
        .toSet();

    test('carries open_to_apprentices', () {
      expect(columns, contains('open_to_apprentices'));
    });

    test('did not lose the columns it already had', () {
      expect(
        columns,
        containsAll([
          'requires_verified',
          'requires_white_card',
          'application_count',
          'view_count',
        ]),
      );
    });
  });
}
