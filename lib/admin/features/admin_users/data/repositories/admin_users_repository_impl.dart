import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/admin_users_repository.dart';

/// Fetches a paged list of users for the admin Users page.
///
/// `profiles` and `user_roles` both reference `auth.users.id` but have no
/// direct FK between them, so PostgREST cannot auto-resolve a `user_roles(...)`
/// embed. `trade_profiles.is_verified` is the source of truth for the
/// verified flag (mirrored by trigger from `verifications.licence.verified`)
/// — `profiles` does not carry that column. Both joins are therefore
/// resolved with separate `in_filter` lookups, matching the pattern used by
/// the existing admin_verifications repo.
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
      // 1. If a role filter is active, resolve the set of allowed user ids
      //    up-front so the profiles page is correctly bounded + paginated.
      List<String>? allowedIds;
      if (filter != AdminUserRoleFilter.all) {
        final roleMatches = await _client
            .from('user_roles')
            .select('user_id')
            .eq('role', _roleString(filter));
        allowedIds = (roleMatches as List)
            .cast<Map<String, dynamic>>()
            .map((r) => r['user_id'] as String)
            .toList();
        if (allowedIds.isEmpty) return const Right([]);
      }

      // 2. Fetch the profiles page. `profiles` has no `deleted_at` column —
      //    soft-delete lives on the role-specific subprofile tables, not
      //    here. Admins see all profile rows; status/role/verified info is
      //    enriched below.
      var profileQuery = _client
          .from('profiles')
          .select('id, display_name, avatar_url, created_at');
      if (allowedIds != null) {
        profileQuery = profileQuery.inFilter('id', allowedIds);
      }
      if (query != null && query.trim().isNotEmpty) {
        profileQuery = profileQuery.ilike('display_name', '%${query.trim()}%');
      }
      final profileRows = await profileQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final rows = (profileRows as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const Right([]);

      // 3. Enrich each row with role + is_verified via two batch lookups.
      final pageIds = rows.map((r) => r['id'] as String).toList();
      final roleByUser = await _fetchRoles(pageIds);
      final verifiedByUser = await _fetchVerifiedFlags(pageIds);

      final list = rows
          .map((r) => _toRow(r, roleByUser, verifiedByUser))
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Map<String, String>> _fetchRoles(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client
        .from('user_roles')
        .select('user_id, role')
        .inFilter('user_id', userIds);
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['user_id'] as String: r['role'] as String? ?? 'unknown',
    };
  }

  Future<Map<String, bool>> _fetchVerifiedFlags(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client
        .from('trade_profiles')
        .select('id, is_verified')
        .inFilter('id', userIds);
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['id'] as String: (r['is_verified'] as bool?) ?? false,
    };
  }

  String _roleString(AdminUserRoleFilter f) => switch (f) {
    AdminUserRoleFilter.all => 'all',
    AdminUserRoleFilter.builder => 'builder',
    AdminUserRoleFilter.trade => 'trade',
    AdminUserRoleFilter.admin => 'admin',
  };

  AdminUserRow _toRow(
    Map<String, dynamic> r,
    Map<String, String> roleByUser,
    Map<String, bool> verifiedByUser,
  ) {
    final id = r['id'] as String;
    final displayName =
        (r['display_name'] as String?)?.trim().isNotEmpty == true
        ? (r['display_name'] as String).trim()
        : '${id.substring(0, 8)}…';
    return AdminUserRow(
      id: id,
      displayName: displayName,
      role: roleByUser[id] ?? 'unknown',
      isVerified: verifiedByUser[id] ?? false,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      avatarUrl: r['avatar_url'] as String?,
    );
  }
}
