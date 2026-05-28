import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/repositories/admin_dashboard_stats_repository.dart';

class AdminDashboardStatsRepositoryImpl
    implements AdminDashboardStatsRepository {
  AdminDashboardStatsRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, AdminDashboardStats>> getStats() async {
    try {
      final results = await Future.wait([
        _countTotalUsers(),
        _countPendingVerifications(),
        _countOpenJobs(),
        _countRejectedLast7Days(),
      ]);
      return Right(AdminDashboardStats(
        totalUsers: results[0],
        pendingVerifications: results[1],
        openJobs: results[2],
        rejectedLast7Days: results[3],
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<int> _countTotalUsers() => _client
      .from('profiles')
      .count(CountOption.exact)
      .isFilter('deleted_at', null);

  Future<int> _countPendingVerifications() => _client
      .from('verification_documents')
      .count(CountOption.exact)
      .eq('status', 'pending')
      .isFilter('deleted_at', null);

  Future<int> _countOpenJobs() => _client
      .from('jobs')
      .count(CountOption.exact)
      .eq('status', 'open');

  Future<int> _countRejectedLast7Days() {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    return _client
        .from('verification_documents')
        .count(CountOption.exact)
        .eq('status', 'rejected')
        .gte('reviewed_at', cutoff);
  }
}
