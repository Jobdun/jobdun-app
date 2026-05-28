import 'package:flutter_riverpod/flutter_riverpod.dart';

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
