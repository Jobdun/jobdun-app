import 'package:flutter/foundation.dart' show kDebugMode;

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/ftue/presentation/providers/ftue_gate_provider.dart';
import 'guest_browse_policy.dart';

/// The whole "where does this user actually belong?" decision, extracted from
/// `app_router.dart` when adding the password-recovery gate pushed that file
/// past the 500-LOC ceiling.
///
/// Pulled out as a pure function rather than split by route group on purpose:
/// every branch here is order-dependent (a recovery session is *authenticated*,
/// so it has to be caught before the generic authed checks), and that ordering
/// is far easier to see — and to test — when the rules sit together with no
/// GoRouter or Riverpod machinery in between.
///
/// [consumePendingReturn] is a callback, not a value, because consuming the
/// pending destination is a side effect that must fire **only** on the branch
/// that actually uses it.
String? resolveRedirect({
  required AuthState auth,
  required FtueGateState ftue,
  required String location,
  required String? Function() consumePendingReturn,
}) {
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

  // A password-reset link produces a real session, so every check below
  // would read this user as normally signed-in and send them to /home
  // with their password unchanged. Pin them to /reset-password until they
  // set one or cancel (which signs out and clears the flag).
  if (auth.isPasswordRecovery) {
    return location == '/reset-password' ? null : '/reset-password';
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
      // Web password-reset and email-verification links land here *before*
      // the session exchange completes, so at this instant the user still
      // reads as unauthenticated. Without this entry they get bounced to
      // /login mid-flight and the recovery never latches.
      '/auth/callback',
      if (kDebugMode) '/dev/reset-ftue',
    };
    return publicRoutes.contains(location) || isGuestBrowsableLocation(location)
        ? null
        : '/login';
  }

  const authPages = {
    '/login',
    '/register',
    '/verify-email',
    '/forgot-password',
    '/phone-auth',
  };
  if (authPages.contains(location)) {
    // A guest who authenticated from a gate (APPLY on a job) goes back
    // to where they were; everyone else lands home.
    return consumePendingReturn() ?? '/home';
  }

  return null;
}
