import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_auth/domain/entities/admin_session.dart';
import '../../features/admin_auth/presentation/pages/admin_login_page.dart';
import '../../features/admin_auth/presentation/providers/admin_session_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../features/admin_shell/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin_shell/presentation/pages/admin_placeholder_page.dart';
import '../../features/admin_jobs/presentation/pages/admin_jobs_page.dart';
import '../../features/admin_users/presentation/pages/admin_users_page.dart';
import '../../features/admin_verifications/presentation/pages/admin_verifications_page.dart';
import 'admin_routes.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  // ValueNotifier mirror so the router gets a stable Listenable and rebuilds
  // its redirect on every session change without recreating the GoRouter
  // instance (which would lose history).
  final refresh = ValueNotifier<AsyncValue<AdminSession?>>(
    ref.read(adminSessionProvider),
  );
  final sub = ref.listen<AsyncValue<AdminSession?>>(
    adminSessionProvider,
    (_, next) => refresh.value = next,
  );
  ref.onDispose(() {
    sub.close();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: AdminRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final value = refresh.value;
      if (value.isLoading) return null;
      final hasAdmin = value.maybeWhen(
        data: (session) => session != null,
        orElse: () => false,
      );
      final atLogin = state.matchedLocation == AdminRoutes.login;
      if (!hasAdmin && !atLogin) return AdminRoutes.login;
      if (hasAdmin && atLogin) return AdminRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: AdminRoutes.dashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: AdminRoutes.verifications,
        builder: (context, state) => const AdminVerificationsPage(),
      ),
      GoRoute(
        path: AdminRoutes.users,
        builder: (context, state) => const AdminUsersPage(),
      ),
      GoRoute(
        path: AdminRoutes.jobs,
        builder: (context, state) => const AdminJobsPage(),
      ),
      GoRoute(
        path: AdminRoutes.audit,
        builder: (context, state) => const AdminPlaceholderPage(
          title: 'AUDIT LOG',
          icon: AppIcons.shield,
          activeRoute: AdminRoutes.audit,
          copy:
              'Tamper-evident log of admin and system events: role changes, '
              'sign-in attempts, manual verification overrides, and policy '
              'actions. Backed by the `verification_events` table plus future '
              'admin_audit table.',
          bullets: [
            'Filter by actor, event type, and date range.',
            'Drill into raw payload for each event.',
            'Export to CSV for compliance review.',
            'Read-only — entries cannot be edited or deleted.',
          ],
        ),
      ),
    ],
  );
});
