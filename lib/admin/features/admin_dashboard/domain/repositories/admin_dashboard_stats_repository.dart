import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_dashboard_stats.dart';

abstract class AdminDashboardStatsRepository {
  Future<Either<Failure, AdminDashboardStats>> getStats();
}
