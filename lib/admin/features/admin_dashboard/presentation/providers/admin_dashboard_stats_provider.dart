import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_dashboard_stats_repository_impl.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/repositories/admin_dashboard_stats_repository.dart';
import '../../domain/usecases/get_admin_dashboard_stats.dart';

final adminDashboardStatsRepositoryProvider =
    Provider<AdminDashboardStatsRepository>(
  (ref) => AdminDashboardStatsRepositoryImpl(),
);

final getAdminDashboardStatsProvider = Provider<GetAdminDashboardStats>(
  (ref) => GetAdminDashboardStats(
    ref.watch(adminDashboardStatsRepositoryProvider),
  ),
);

final adminDashboardStatsProvider =
    AsyncNotifierProvider<AdminDashboardStatsController, AdminDashboardStats>(
  AdminDashboardStatsController.new,
);

class AdminDashboardStatsController extends AsyncNotifier<AdminDashboardStats> {
  @override
  Future<AdminDashboardStats> build() async {
    final useCase = ref.read(getAdminDashboardStatsProvider);
    final result = await useCase();
    return result.fold((f) => throw Exception(f.message), (s) => s);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(getAdminDashboardStatsProvider);
      final result = await useCase();
      return result.fold((f) => throw Exception(f.message), (s) => s);
    });
  }
}
