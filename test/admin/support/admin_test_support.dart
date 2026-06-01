import 'package:fpdart/fpdart.dart';
import 'package:jobdun/admin/features/admin_auth/domain/entities/admin_session.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/repositories/admin_dashboard_stats_repository.dart';
import 'package:jobdun/core/errors/failures.dart';

/// A fixed authenticated admin reused across admin tests. Use with
/// `adminSessionProvider.overrideWith(() => FakeAdminSessionNotifier(...))`.
const kTestAdminSession = AdminSession(
  userId: 'admin-1',
  email: 'admin@jobdun.com.au',
);

/// The real session notifier talks to Supabase in `build()`. This swaps it for
/// one that resolves to [session] — a logged-in admin, or `null` for the
/// signed-out / login-screen case.
class FakeAdminSessionNotifier extends AdminSessionNotifier {
  FakeAdminSessionNotifier(this._session);
  final AdminSession? _session;

  @override
  Future<AdminSession?> build() async => _session;
}

/// In-memory dashboard stats repo — returns a fixed [Either], no Supabase.
class FakeDashboardStatsRepository implements AdminDashboardStatsRepository {
  FakeDashboardStatsRepository(this.result);
  final Either<Failure, AdminDashboardStats> result;

  @override
  Future<Either<Failure, AdminDashboardStats>> getStats() async => result;
}
