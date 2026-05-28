import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/repositories/admin_dashboard_stats_repository.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/usecases/get_admin_dashboard_stats.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminDashboardStatsRepository {}

void main() {
  late GetAdminDashboardStats useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = GetAdminDashboardStats(repo);
  });

  test('delegates to repository.getStats and returns the result', () async {
    const stats = AdminDashboardStats(
      totalUsers: 42,
      pendingVerifications: 5,
      openJobs: 11,
      rejectedLast7Days: 2,
    );
    when(() => repo.getStats()).thenAnswer((_) async => const Right(stats));

    final result = await useCase();

    expect(result, const Right<Failure, AdminDashboardStats>(stats));
    verify(() => repo.getStats()).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repo.getStats(),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase();

    expect(result.isLeft(), isTrue);
  });
}
