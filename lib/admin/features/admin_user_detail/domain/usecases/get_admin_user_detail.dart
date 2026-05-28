import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_detail.dart';
import '../repositories/admin_user_detail_repository.dart';

class GetAdminUserDetail {
  const GetAdminUserDetail(this._repository);

  final AdminUserDetailRepository _repository;

  Future<Either<Failure, AdminUserDetail>> call(String userId) =>
      _repository.getUserDetail(userId);
}
