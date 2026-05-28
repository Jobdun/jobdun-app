import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_dashboard_stats.dart';
import '../repositories/admin_dashboard_stats_repository.dart';

class GetAdminDashboardStats {
  const GetAdminDashboardStats(this._repository);

  final AdminDashboardStatsRepository _repository;

  Future<Either<Failure, AdminDashboardStats>> call() => _repository.getStats();
}
