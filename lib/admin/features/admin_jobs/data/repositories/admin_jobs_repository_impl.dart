import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../../domain/repositories/admin_jobs_repository.dart';

class AdminJobsRepositoryImpl implements AdminJobsRepository {
  AdminJobsRepositoryImpl({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  }) async {
    try {
      var builder = _client
          .from('jobs')
          .select(
            'id, title, status, application_count, created_at, '
            'profiles!jobs_builder_id_fkey(display_name)',
          );

      final dbStatus = adminJobStatusFilterToDb(filter);
      if (dbStatus != null) {
        builder = builder.eq('status', dbStatus);
      }

      final rows = await builder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_toRow)
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setJobStatus({
    required String jobId,
    required String status,
  }) async {
    try {
      await _client.rpc(
        'admin_set_job_status',
        params: {'p_job_id': jobId, 'p_status': status},
      );
      return const Right(unit);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  AdminJobRow _toRow(Map<String, dynamic> r) {
    final builder = r['profiles'] as Map<String, dynamic>?;
    return AdminJobRow(
      id: r['id'] as String,
      title: r['title'] as String,
      status: r['status'] as String,
      builderDisplayName:
          (builder?['display_name'] as String?)?.trim().isNotEmpty == true
          ? (builder!['display_name'] as String).trim()
          : '—',
      applicationCount: (r['application_count'] as int?) ?? 0,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    );
  }
}
