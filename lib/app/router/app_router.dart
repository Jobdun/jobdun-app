import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/jobs/presentation/pages/jobs_page.dart';
import '../../features/messaging/presentation/pages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (location == '/splash') {
        return null;
      }

      if (!authState.isAuthenticated) {
        const publicRoutes = {'/login', '/register'};
        return publicRoutes.contains(location) ? null : '/login';
      }

      if (!authState.onboardingComplete) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      if (location == '/login' ||
          location == '/register' ||
          location == '/onboarding') {
        return '/home';
      }

      if (location == '/admin' && authState.role != UserRole.admin) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/jobs', builder: (context, state) => const JobsPage()),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationPage(),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
    ],
  );
});
