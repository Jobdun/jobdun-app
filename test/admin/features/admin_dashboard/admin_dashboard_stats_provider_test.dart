import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart';
import 'package:jobdun/admin/features/admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart';
import 'package:jobdun/core/errors/failures.dart';

import '../../support/admin_test_support.dart';

void main() {
  const stats = AdminDashboardStats(
    totalUsers: 12,
    pendingVerifications: 3,
    openJobs: 7,
    rejectedLast7Days: 1,
  );

  // Repository-failure propagation is covered at the use-case layer in
  // get_admin_dashboard_stats_test.dart. Here we guard the NEW behaviour: the
  // provider waits for the admin session, then fetches automatically — the fix
  // for "tiles only load after clicking Refresh".
  test(
    'loads stats automatically once the admin session resolves',
    () async {
      final container = ProviderContainer(
        overrides: [
          adminSessionProvider.overrideWith(
            () => FakeAdminSessionNotifier(kTestAdminSession),
          ),
          adminDashboardStatsRepositoryProvider.overrideWithValue(
            FakeDashboardStatsRepository(
              Right<Failure, AdminDashboardStats>(stats),
            ),
          ),
        ],
      );
      container.listen(adminDashboardStatsProvider, (_, _) {});
      addTearDown(container.dispose);

      final result = await container.read(adminDashboardStatsProvider.future);
      expect(result, stats);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
