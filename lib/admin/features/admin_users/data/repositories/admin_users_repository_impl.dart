import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/admin_users_repository.dart';

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  AdminUsersRepositoryImpl({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminUserRow>>> listUsers({
    required int limit,
    required int offset,
    AdminUserRoleFilter filter = AdminUserRoleFilter.all,
    String? query,
  }) async {
    try {
      var builder = _client
          .from('profiles')
          .select(
            'id, display_name, avatar_url, is_verified, created_at, '
            'user_roles(role)',
          )
          .isFilter('deleted_at', null);

      if (filter != AdminUserRoleFilter.all) {
        builder = builder.eq('user_roles.role', _roleString(filter));
      }
      if (query != null && query.trim().isNotEmpty) {
        builder = builder.ilike('display_name', '%${query.trim()}%');
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

  String _roleString(AdminUserRoleFilter f) => switch (f) {
    AdminUserRoleFilter.all => 'all',
    AdminUserRoleFilter.builder => 'builder',
    AdminUserRoleFilter.trade => 'trade',
    AdminUserRoleFilter.admin => 'admin',
  };

  AdminUserRow _toRow(Map<String, dynamic> r) {
    final roles = r['user_roles'];
    String role = 'unknown';
    if (roles is List && roles.isNotEmpty) {
      role =
          (roles.first as Map<String, dynamic>)['role'] as String? ?? 'unknown';
    } else if (roles is Map<String, dynamic>) {
      role = roles['role'] as String? ?? 'unknown';
    }
    return AdminUserRow(
      id: r['id'] as String,
      displayName: (r['display_name'] as String?)?.trim().isNotEmpty == true
          ? (r['display_name'] as String).trim()
          : '${(r['id'] as String).substring(0, 8)}…',
      role: role,
      isVerified: (r['is_verified'] as bool?) ?? false,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      avatarUrl: r['avatar_url'] as String?,
    );
  }
}
