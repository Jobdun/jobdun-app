import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_filter.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_row.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart';
import 'package:jobdun/admin/features/admin_jobs/presentation/pages/admin_job_detail_page.dart';
import 'package:jobdun/admin/features/admin_jobs/presentation/providers/admin_jobs_provider.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/errors/failures.dart';

import '../../support/admin_test_support.dart';

/// In-memory jobs repo — records the moderation call, returns no list rows.
class _FakeJobsRepo implements AdminJobsRepository {
  int setCalls = 0;
  String? lastJobId;
  String? lastStatus;

  @override
  Future<Either<Failure, Unit>> setJobStatus({
    required String jobId,
    required String status,
  }) async {
    setCalls++;
    lastJobId = jobId;
    lastStatus = status;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  }) async => const Right([]);
}

Widget _wrap(Widget page, {_FakeJobsRepo? repo}) => ProviderScope(
  overrides: [
    adminSessionProvider.overrideWith(
      () => FakeAdminSessionNotifier(kTestAdminSession),
    ),
    adminJobsRepositoryProvider.overrideWithValue(repo ?? _FakeJobsRepo()),
  ],
  child: ScreenUtilInit(
    designSize: const Size(1440, 900),
    builder: (_, _) => MaterialApp(theme: AppTheme.dark(), home: page),
  ),
);

AdminJobRow _row({String status = 'open'}) => AdminJobRow(
  id: 'j1',
  title: 'Site cleanup crew',
  status: status,
  builderDisplayName: 'Acme Builders',
  applicationCount: 4,
  createdAt: DateTime(2026, 5, 20),
);

void main() {
  setUp(() {});

  testWidgets('an open job offers wired CLOSE + CANCEL (no placeholders)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(AdminJobDetailPage(jobId: 'j1', row: _row())),
    );
    await tester.pump();

    expect(find.text('Site cleanup crew'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    // Old Phase-2 placeholders are gone.
    expect(find.text('HIDE'), findsNothing);
    expect(find.text('REMOVE'), findsNothing);

    // CLOSE is a real, enabled action.
    final closeBtn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('CLOSE'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(closeBtn.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping CLOSE calls admin_set_job_status with "closed"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeJobsRepo();
    await tester.pumpWidget(
      _wrap(
        AdminJobDetailPage(jobId: 'j1', row: _row()),
        repo: repo,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('CLOSE'));
    await tester.pump(); // process tap + start async
    await tester.pump(const Duration(milliseconds: 50)); // resolve + rebuild

    expect(repo.setCalls, 1);
    expect(repo.lastJobId, 'j1');
    expect(repo.lastStatus, 'closed');
    expect(find.text('Job set to CLOSED.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a closed job offers REOPEN', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        AdminJobDetailPage(
          jobId: 'j1',
          row: _row(status: 'closed'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('REOPEN'), findsOneWidget);
    expect(find.text('CLOSE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null row (deep link) shows the empty state, not a crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const AdminJobDetailPage(jobId: 'j1')));
    await tester.pump();

    expect(find.text('OPEN A JOB FROM THE LIST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
