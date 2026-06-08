import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../../data/repositories/admin_user_detail_repository_impl.dart';
import '../../domain/entities/admin_user_detail.dart';
import '../../domain/repositories/admin_user_detail_repository.dart';
import '../../domain/usecases/get_admin_user_detail.dart';

final adminUserDetailRepositoryProvider = Provider<AdminUserDetailRepository>(
  (ref) => AdminUserDetailRepositoryImpl(),
);

final getAdminUserDetailProvider = Provider<GetAdminUserDetail>(
  (ref) => GetAdminUserDetail(ref.watch(adminUserDetailRepositoryProvider)),
);

final adminUserDetailProvider = FutureProvider.family<AdminUserDetail, String>((
  ref,
  userId,
) async {
  final useCase = ref.watch(getAdminUserDetailProvider);
  final result = await useCase(userId);
  return result.fold((f) => throw Exception(f.message), (d) => d);
});

/// #21a moderation actions. Calls the audited `admin_set_user_status` RPC, then
/// invalidates the detail so the card reflects the new state.
final adminModerationProvider = Provider(AdminModeration.new);

class AdminModeration {
  AdminModeration(this._ref);
  final Ref _ref;

  Future<Either<Failure, Unit>> setUserStatus({
    required String userId,
    required String status,
    String? reason,
  }) async {
    final res = await _ref
        .read(adminUserDetailRepositoryProvider)
        .setUserStatus(userId: userId, status: status, reason: reason);
    if (res.isRight()) _ref.invalidate(adminUserDetailProvider(userId));
    return res;
  }
}
