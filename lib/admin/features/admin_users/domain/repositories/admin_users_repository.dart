import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_filter.dart';
import '../entities/admin_user_row.dart';

abstract class AdminUsersRepository {
  Future<Either<Failure, List<AdminUserRow>>> listUsers({
    required int limit,
    required int offset,
    AdminUserRoleFilter filter = AdminUserRoleFilter.all,
    String? query,
  });
}
