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
import '../../features/ftue/presentation/pages/dev_ftue_reset_page.dart';
import '../../features/ftue/presentation/pages/ftue_page.dart';
import '../../features/ftue/presentation/providers/ftue_gate_provider.dart';
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

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    // Safety net for upgraded users: anyone who completes auth has, by
    // definition, made it past the marketing surface — flip the gate so the
    // carousel never reappears retroactively.
    if (next.isAuthenticated) {
      ref.read(ftueGateProvider.notifier).markCompleted();
    }
    notifier.refresh();
  });
  ref.listen<FtueGateState>(ftueGateProvider, (_, _) => notifier.refresh());

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final ftue = ref.read(ftueGateProvider);
      final location = state.matchedLocation;

      if (location == '/splash') return null;

      // While the FTUE flag is still being read from SharedPreferences keep
      // unauthenticated users on splash — otherwise we'd flash /login before
      // a first-launch user ever sees the carousel.
      if (!ftue.isLoaded && !auth.isAuthenticated) return '/splash';

      // Splash hands off to '/' so the router (not splash) decides where the
      // user lands. Same auth-aware fork as the onboarding redirect below.
      if (location == '/') {
        if (auth.isAuthenticated) return '/home';
        return ftue.hasCompleted ? '/login' : '/ftue';
      }

      // Legacy onboarding route — wall was removed in T1.3 (friction-reduction
      // sprint). Anyone landing here from a deep link / stale session goes
      // home, and the ProfileCompletenessBanner handles the nudge.
      if (location == '/onboarding') {
        return auth.isAuthenticated ? '/home' : '/login';
      }

      if (auth.pendingVerificationEmail != null) {
        return location == '/verify-email' ? null : '/verify-email';
      }

      // Authenticated users never see the FTUE — including direct deep links.
      if (auth.isAuthenticated && location == '/ftue') return '/home';

      if (!auth.isAuthenticated) {
        final publicRoutes = <String>{
          '/ftue',
          '/login',
          '/register',
          '/forgot-password',
          '/phone-auth',
          '/legal',
          '/legal/terms',
          '/legal/privacy',
          if (kDebugMode) '/logo-compare',
          if (kDebugMode) '/dev/reset-ftue',
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
      GoRoute(
        path: '/ftue',
        builder: (context, state) {
          // ?from=login signals the user already has an account path open
          // (came from "Create account →" on /login). Show a back-arrow on
          // slide 1 and hide the redundant "I already have an account" link
          // on slide 3.
          final fromLogin = state.uri.queryParameters['from'] == 'login';
          return FtuePage(fromLogin: fromLogin);
        },
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          // ?role=builder|trade pre-picks step 1 so users who entered via
          // the "I'M HIRING" / "I'M LOOKING FOR WORK" CTAs on /login skip
          // straight to the form. Unknown values fall through to picker.
          final raw = state.uri.queryParameters['role'];
          final initialRole = switch (raw) {
            'builder' => UserRole.builder,
            'trade' => UserRole.trade,
            _ => null,
          };
          return RegisterPage(initialRole: initialRole);
        },
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/phone-auth', builder: (_, _) => const PhoneAuthPage()),
      // Authed users land here from /profile/edit when their phone slot in
      // the completeness banner is still missing. Same widget as /phone-auth
      // but uses updateUser+phoneChange semantics so the existing session
      // stays put.
      GoRoute(
        path: '/profile/verify-phone',
        builder: (_, _) =>
            const PhoneAuthPage(mode: PhoneAuthMode.addToAccount),
      ),
      if (kDebugMode) ...[
        GoRoute(
          path: '/logo-compare',
          builder: (_, _) => const LogoComparePage(),
        ),
        GoRoute(
          path: '/dev/reset-ftue',
          builder: (_, _) => const DevFtueResetPage(),
        ),
      ],

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
