import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/jobs/data/datasources/job_remote_datasource.dart';

void main() {
  group('JobRemoteDataSourceImpl.feedColumns', () {
    // Regression guard: the feed `.select()` once omitted latitude/longitude,
    // so the tradie "jobs near you" map could never plot a pin. These columns
    // MUST stay in the projection.
    final columns = JobRemoteDataSourceImpl.feedColumns
        .split(',')
        .map((c) => c.trim())
        .toSet();

    test('includes the geo columns the job map needs', () {
      expect(columns, containsAll(['latitude', 'longitude']));
    });

    test('includes the MapTiler place metadata', () {
      expect(columns, containsAll(['formatted_address', 'place_id']));
    });

    test('still carries the core feed fields', () {
      expect(
        columns,
        containsAll(['id', 'builder_id', 'title', 'status', 'published_at']),
      );
    });
  });
}
