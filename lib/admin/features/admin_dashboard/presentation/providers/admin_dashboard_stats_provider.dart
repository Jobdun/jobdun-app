import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin_auth/presentation/providers/admin_session_provider.dart';
import '../../data/repositories/admin_dashboard_stats_repository_impl.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/repositories/admin_dashboard_stats_repository.dart';
import '../../domain/usecases/get_admin_dashboard_stats.dart';

final adminDashboardStatsRepositoryProvider =
    Provider<AdminDashboardStatsRepository>(
      (ref) => AdminDashboardStatsRepositoryImpl(),
    );

final getAdminDashboardStatsProvider = Provider<GetAdminDashboardStats>(
  (ref) =>
      GetAdminDashboardStats(ref.watch(adminDashboardStatsRepositoryProvider)),
);

final adminDashboardStatsProvider =
    AsyncNotifierProvider<AdminDashboardStatsController, AdminDashboardStats>(
      AdminDashboardStatsController.new,
    );

class AdminDashboardStatsController extends AsyncNotifier<AdminDashboardStats> {
  @override
  Future<AdminDashboardStats> build() async {
    // Gate the first fetch on the admin session being restored. On a cold start
    // the dashboard mounts while Supabase is still rehydrating the session
    // (the router's redirect returns null while the session is `loading`), so
    // querying the RLS-protected count tables before `auth.uid()` exists came
    // back empty — the tiles showed "—" until the admin hit Refresh by hand.
    // Awaiting the session future both delays the first query until auth is
    // ready AND re-runs this build when the session resolves, so the dashboard
    // fills in automatically.
    await ref.watch(adminSessionProvider.future);
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
