import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/home_shell_page.dart';
import '../../features/jobs/presentation/pages/jobs_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/messaging/presentation/pages/messages_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reviews/presentation/pages/reviews_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';

// Single GoRouter instance. Auth state changes notify via refreshListenable;
// the router re-evaluates its redirect without rebuilding the instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();

  ref.listen<AuthState>(authControllerProvider, (_, _) => notifier.refresh());

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (location == '/splash') return null;

      // Step 1 — email verification pending after registration.
      if (auth.pendingVerificationEmail != null) {
        return location == '/verify-email' ? null : '/verify-email';
      }

      // Step 2 — unauthenticated.
      if (!auth.isAuthenticated) {
        const publicRoutes = {'/login', '/register', '/forgot-password'};
        return publicRoutes.contains(location) ? null : '/login';
      }

      // Step 3 — authenticated but onboarding not done.
      if (!auth.onboardingComplete) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Step 4 — fully authenticated: bounce away from auth pages.
      const authPages = {
        '/login',
        '/register',
        '/onboarding',
        '/verify-email',
        '/forgot-password',
      };
      if (authPages.contains(location)) return '/home';

      return null;
    },
    routes: [
      // ── Pre-shell (no bottom nav) ──────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/verify-email', builder: (_, _) => const VerifyEmailPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),

      // ── Shell (bottom nav — 5 tabs) ────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            HomeShellPage(navigationShell: shell),
        branches: [
          // Tab 0 — Home / Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomePage()),
            ],
          ),

          // Tab 1 — Jobs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/jobs',
                builder: (_, _) => const JobsPage(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (_, _) => const JobsPage(), // TODO: JobCreatePage
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, _) => const JobsPage(), // TODO: JobDetailPage
                  ),
                ],
              ),
            ],
          ),

          // Tab 2 — Applications
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/applications',
                builder: (_, _) => const ApplicationsPage(),
              ),
            ],
          ),

          // Tab 3 — Messages
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, _) => const MessagesPage(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (_, _) => const MessagesPage(), // TODO: MessageThreadPage
                  ),
                ],
              ),
            ],
          ),

          // Tab 4 — Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, _) => const ProfilePage(), // TODO: ProfileEditPage
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: '/verification',
        builder: (_, _) => const VerificationPage(),
      ),
      GoRoute(path: '/reviews', builder: (_, _) => const ReviewsPage()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
    ],
  );

  ref.onDispose(notifier.dispose);
  return router;
});

class _RouterNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
