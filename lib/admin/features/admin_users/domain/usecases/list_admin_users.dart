import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_filter.dart';
import '../entities/admin_user_row.dart';
import '../repositories/admin_users_repository.dart';

class ListAdminUsersParams {
  const ListAdminUsersParams({
    required this.limit,
    required this.offset,
    this.filter = AdminUserRoleFilter.all,
    this.query,
  });

  final int limit;
  final int offset;
  final AdminUserRoleFilter filter;
  final String? query;
}

class ListAdminUsers {
  const ListAdminUsers(this._repository);

  final AdminUsersRepository _repository;

  Future<Either<Failure, List<AdminUserRow>>> call(
    ListAdminUsersParams params,
  ) {
    return _repository.listUsers(
      limit: params.limit,
      offset: params.offset,
      filter: params.filter,
      query: params.query,
    );
  }
}
