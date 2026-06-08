import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_map_data.dart';

Job _job({required String id, double? lat, double? lng}) => Job(
  id: id,
  builderId: 'b1',
  title: 'Job $id',
  description: 'desc',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  createdAt: DateTime.utc(2026, 6, 1),
  updatedAt: DateTime.utc(2026, 6, 1),
  latitude: lat,
  longitude: lng,
);

void main() {
  group('JobMapData.plottable', () {
    test('keeps only jobs with both coordinates', () {
      final jobs = [
        _job(id: 'a', lat: -33.8, lng: 151.2),
        _job(id: 'b'), // no coords
        _job(id: 'c', lat: -33.9, lng: 151.1),
      ];
      expect(JobMapData.plottable(jobs).map((j) => j.id), ['a', 'c']);
    });

    test('drops a job with only one coordinate', () {
      final jobs = [_job(id: 'a', lat: -33.8)];
      expect(JobMapData.plottable(jobs), isEmpty);
    });
  });

  group('JobMapData.summary', () {
    test('counts plotted vs total', () {
      final jobs = [
        _job(id: 'a', lat: -33.8, lng: 151.2),
        _job(id: 'b'),
        _job(id: 'c', lat: -33.9, lng: 151.1),
      ];
      final summary = JobMapData.summary(jobs);
      expect(summary.plotted, 2);
      expect(summary.total, 3);
    });

    test('all plotted when every job has coordinates', () {
      final jobs = [
        _job(id: 'a', lat: -33.8, lng: 151.2),
        _job(id: 'b', lat: -33.9, lng: 151.1),
      ];
      final summary = JobMapData.summary(jobs);
      expect(summary.plotted, 2);
      expect(summary.total, 2);
      expect(summary.allPlotted, isTrue);
    });

    test('empty list is zero/zero and not "some dropped"', () {
      final summary = JobMapData.summary(const []);
      expect(summary.plotted, 0);
      expect(summary.total, 0);
      expect(summary.someDropped, isFalse);
      expect(summary.nonePlotted, isFalse);
    });

    test('someDropped true only when total > plotted', () {
      final summary = JobMapData.summary([
        _job(id: 'a', lat: -33.8, lng: 151.2),
        _job(id: 'b'),
      ]);
      expect(summary.someDropped, isTrue);
      expect(summary.nonePlotted, isFalse);
    });

    test('nonePlotted true when jobs exist but none have coordinates', () {
      final summary = JobMapData.summary([_job(id: 'a'), _job(id: 'b')]);
      expect(summary.nonePlotted, isTrue);
      expect(summary.someDropped, isTrue);
    });
  });
}
