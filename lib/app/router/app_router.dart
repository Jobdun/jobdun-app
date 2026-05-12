import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/logo_compare_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/phone_auth_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/legal/domain/legal_document.dart';
import '../../features/legal/presentation/pages/legal_document_page.dart';
import '../../features/legal/presentation/pages/legal_index_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/home_shell_page.dart';
import '../../features/jobs/presentation/pages/job_create_page.dart';
import '../../features/jobs/presentation/pages/job_detail_page.dart';
import '../../features/jobs/presentation/pages/jobs_page.dart';
import '../../features/applications/presentation/pages/applications_page.dart';
import '../../features/messaging/presentation/pages/message_thread_page.dart';
import '../../features/messaging/presentation/pages/messages_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reviews/presentation/pages/reviews_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';

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

      // Legacy onboarding route — wall was removed in T1.3 (friction-reduction
      // sprint). Anyone landing here from a deep link / stale session goes
      // home, and the ProfileCompletenessBanner handles the nudge.
      if (location == '/onboarding') {
        return auth.isAuthenticated ? '/home' : '/login';
      }

      if (auth.pendingVerificationEmail != null) {
        return location == '/verify-email' ? null : '/verify-email';
      }

      if (!auth.isAuthenticated) {
        final publicRoutes = <String>{
          '/login',
          '/register',
          '/forgot-password',
          '/phone-auth',
          '/legal',
          '/legal/terms',
          '/legal/privacy',
          if (kDebugMode) '/logo-compare',
        };
        return publicRoutes.contains(location) ? null : '/login';
      }

      const authPages = {
        '/login',
        '/register',
        '/verify-email',
        '/forgot-password',
        '/phone-auth',
      };
      if (authPages.contains(location)) return '/home';

      return null;
    },
    routes: [
      // ── Pre-shell ──────────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/phone-auth', builder: (_, _) => const PhoneAuthPage()),
      if (kDebugMode)
        GoRoute(
          path: '/logo-compare',
          builder: (_, _) => const LogoComparePage(),
        ),

      // ── Shell (5 tabs) ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            HomeShellPage(navigationShell: shell),
        branches: [
          // Tab 0 — Home
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
                    builder: (_, _) => const JobCreatePage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final args = state.extra as JobDetailArgs?;
                      if (args == null) return const JobsPage();
                      return JobDetailPage(args: args);
                    },
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
                    builder: (context, state) {
                      final args = state.extra as ConversationArgs?;
                      if (args == null) return const MessagesPage();
                      return MessageThreadPage(args: args);
                    },
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
                    builder: (_, _) => const ProfileEditPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen (no bottom nav) ────────────────────────────────────────
      GoRoute(
        path: '/verification',
        builder: (_, _) => const VerificationPage(),
      ),
      GoRoute(path: '/reviews', builder: (_, _) => const ReviewsPage()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),

      // ── Legal (public — accessible before auth) ────────────────────────────
      GoRoute(
        path: '/legal',
        builder: (_, _) => const LegalIndexPage(),
        routes: [
          GoRoute(
            path: 'terms',
            builder: (_, _) =>
                const LegalDocumentPage(type: LegalDocumentType.termsOfService),
          ),
          GoRoute(
            path: 'privacy',
            builder: (_, _) =>
                const LegalDocumentPage(type: LegalDocumentType.privacyPolicy),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(notifier.dispose);
  return router;
});

class _RouterNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
