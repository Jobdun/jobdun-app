import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_auth/domain/entities/admin_session.dart';
import '../../features/admin_auth/presentation/pages/admin_login_page.dart';
import '../../features/admin_auth/presentation/providers/admin_session_provider.dart';
import '../../features/admin_audit/presentation/pages/admin_audit_page.dart';
import '../../features/admin_broadcast/presentation/pages/admin_broadcast_page.dart';
import '../../features/admin_shell/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin_jobs/domain/entities/admin_job_row.dart';
import '../../features/admin_jobs/presentation/pages/admin_job_detail_page.dart';
import '../../features/admin_jobs/presentation/pages/admin_jobs_page.dart';
import '../../features/admin_payments/presentation/pages/admin_payments_page.dart';
import '../../features/admin_user_detail/presentation/pages/admin_user_detail_page.dart';
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
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminLoginPage()),
      ),
      GoRoute(
        path: AdminRoutes.dashboard,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminDashboardPage()),
      ),
      GoRoute(
        path: AdminRoutes.verifications,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminVerificationsPage()),
      ),
      GoRoute(
        path: AdminRoutes.users,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminUsersPage()),
      ),
      GoRoute(
        path: '/users/:id',
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          AdminUserDetailPage(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AdminRoutes.jobs,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminJobsPage()),
      ),
      GoRoute(
        path: '/jobs/:id',
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          AdminJobDetailPage(
            jobId: state.pathParameters['id']!,
            row: state.extra as AdminJobRow?,
          ),
        ),
      ),
      GoRoute(
        path: AdminRoutes.audit,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminAuditPage()),
      ),
      GoRoute(
        path: AdminRoutes.broadcast,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminBroadcastPage()),
      ),
      GoRoute(
        path: AdminRoutes.payments,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const AdminPaymentsPage()),
      ),
    ],
  );
});

/// Admin page transition: a fast, flat cross-fade on every route change.
///
/// With plain `builder:` routes the transition falls back to Flutter's platform
/// default — on macOS/iOS web that's `CupertinoPageTransitionsBuilder`, a full
/// horizontal *slide* on every navigation, which on a desktop admin tool reads
/// as a constant lateral lurch. A 150ms ease-out opacity fade signals "the page
/// changed" without moving the layout (matches the design system's 150–200ms
/// motion budget) and collapses to an instant cut under reduced-motion. New
/// routes should use this helper, not a bare `builder:`.
Page<void> _fadePage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
