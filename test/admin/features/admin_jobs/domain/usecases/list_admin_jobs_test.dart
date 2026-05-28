import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_filter.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_row.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/repositories/admin_jobs_repository.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/usecases/list_admin_jobs.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminJobsRepository {}

void main() {
  late ListAdminJobs useCase;
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(AdminJobStatusFilter.all);
  });

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminJobs(repo);
  });

  test('forwards params to repository', () async {
    final row = AdminJobRow(
      id: 'j1',
      title: 'Build a deck',
      status: 'open',
      builderDisplayName: 'Acme',
      applicationCount: 3,
      createdAt: DateTime(2026, 1, 1),
    );
    when(() => repo.listJobs(
          limit: 50,
          offset: 0,
          filter: AdminJobStatusFilter.open,
        )).thenAnswer((_) async => Right([row]));

    final result = await useCase(const ListAdminJobsParams(
      limit: 50,
      offset: 0,
      filter: AdminJobStatusFilter.open,
    ));

    expect(result.isRight(), isTrue);
    verify(() => repo.listJobs(
          limit: 50,
          offset: 0,
          filter: AdminJobStatusFilter.open,
        )).called(1);
  });

  test('propagates failures', () async {
    when(() => repo.listJobs(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(const ListAdminJobsParams(limit: 50, offset: 0));

    expect(result.isLeft(), isTrue);
  });
}
