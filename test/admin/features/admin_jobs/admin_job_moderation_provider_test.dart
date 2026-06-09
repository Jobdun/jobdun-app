import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_filter.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_row.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart';
import 'package:jobdun/admin/features/admin_jobs/presentation/providers/admin_jobs_provider.dart';
import 'package:jobdun/core/errors/failures.dart';

/// In-memory jobs repo — records the moderation call, never touches Supabase.
class _FakeJobsRepo implements AdminJobsRepository {
  _FakeJobsRepo(this.setResult);
  final Either<Failure, Unit> setResult;
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
    return setResult;
  }

  @override
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  }) async => const Right([]);
}

void main() {
  test(
    'setJobStatus forwards jobId + status to the repo and returns success',
    () async {
      final repo = _FakeJobsRepo(const Right(unit));
      final container = ProviderContainer(
        overrides: [adminJobsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final res = await container
          .read(adminJobModerationProvider)
          .setJobStatus(jobId: 'j1', status: 'closed');

      expect(res.isRight(), isTrue);
      expect(repo.setCalls, 1);
      expect(repo.lastJobId, 'j1');
      expect(repo.lastStatus, 'closed');
    },
  );

  test('setJobStatus propagates a repo failure', () async {
    final repo = _FakeJobsRepo(const Left(ServerFailure('not_admin')));
    final container = ProviderContainer(
      overrides: [adminJobsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final res = await container
        .read(adminJobModerationProvider)
        .setJobStatus(jobId: 'j1', status: 'closed');

    expect(res.isLeft(), isTrue);
    expect(repo.setCalls, 1);
  });
}
