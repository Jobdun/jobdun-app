import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_detail.dart';

abstract class AdminUserDetailRepository {
  Future<Either<Failure, AdminUserDetail>> getUserDetail(String userId);

  /// #21a moderation: set a user active/suspended/banned via the audited
  /// admin_set_user_status RPC.
  Future<Either<Failure, Unit>> setUserStatus({
    required String userId,
    required String status,
    String? reason,
  });
}
