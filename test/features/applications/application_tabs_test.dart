import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/presentation/pages/application_tabs.dart';

JobApplication _app(ApplicationStatus status) => JobApplication(
  id: 'a-${status.dbValue}',
  jobId: 'job-1',
  tradeId: 'trade-1',
  builderId: 'builder-1',
  status: status,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

void main() {
  final mixed = [
    _app(ApplicationStatus.pending),
    _app(ApplicationStatus.pending),
    _app(ApplicationStatus.shortlisted),
    _app(ApplicationStatus.hired),
    _app(ApplicationStatus.rejected),
  ];

  group('ApplicationTabs.forRole', () {
    test('builder roster includes Rejected', () {
      expect(
        ApplicationTabs.forRole(isBuilder: true),
        contains(AppTab.rejected),
      );
    });

    test('trade roster excludes Rejected', () {
      expect(
        ApplicationTabs.forRole(isBuilder: false),
        isNot(contains(AppTab.rejected)),
      );
    });

    test('both rosters start with All', () {
      expect(ApplicationTabs.forRole(isBuilder: true).first, AppTab.all);
      expect(ApplicationTabs.forRole(isBuilder: false).first, AppTab.all);
    });
  });

  group('ApplicationTabs.count', () {
    test('All counts the whole list', () {
      expect(ApplicationTabs.count(mixed, AppTab.all), 5);
    });

    test('Pending counts only pending', () {
      expect(ApplicationTabs.count(mixed, AppTab.pending), 2);
    });

    test('Hired counts only hired', () {
      expect(ApplicationTabs.count(mixed, AppTab.hired), 1);
    });

    test('empty list counts zero for every tab', () {
      for (final tab in AppTab.values) {
        expect(ApplicationTabs.count(const [], tab), 0);
      }
    });
  });

  group('ApplicationTabs.filter', () {
    test('All returns every row unchanged', () {
      expect(ApplicationTabs.filter(mixed, AppTab.all), hasLength(5));
    });

    test('Shortlisted returns only shortlisted rows', () {
      final result = ApplicationTabs.filter(mixed, AppTab.shortlisted);
      expect(result, hasLength(1));
      expect(result.single.status, ApplicationStatus.shortlisted);
    });
  });

  group('AppTab.label', () {
    test('maps each tab to its display label', () {
      expect(AppTab.all.label, 'All');
      expect(AppTab.pending.label, 'Pending');
      expect(AppTab.shortlisted.label, 'Shortlisted');
      expect(AppTab.hired.label, 'Hired');
      expect(AppTab.rejected.label, 'Rejected');
    });
  });
}
