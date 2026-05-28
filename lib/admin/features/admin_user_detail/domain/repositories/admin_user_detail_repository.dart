import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_detail.dart';

abstract class AdminUserDetailRepository {
  Future<Either<Failure, AdminUserDetail>> getUserDetail(String userId);
}
