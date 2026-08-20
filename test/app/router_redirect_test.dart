import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/router/router_redirect.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/ftue/presentation/providers/ftue_gate_provider.dart';

/// Guards the routing decision table that used to be an inline closure inside
/// `app_router.dart`. It gates every screen in the app, so the branch ordering
/// is worth pinning: the password-recovery case in particular is only correct
/// because it is checked *before* the generic "authenticated" branches.
void main() {
  const loadedFtue = FtueGateState(isLoaded: true, hasCompleted: true);

  String? redirect(
    AuthState auth,
    String location, {
    FtueGateState ftue = loadedFtue,
    String? pending,
  }) => resolveRedirect(
    auth: auth,
    ftue: ftue,
    location: location,
    consumePendingReturn: () => pending,
  );

  group('password recovery gate', () {
    // A recovery link hands back a REAL session. Without the dedicated gate
    // the user reads as normally signed-in and lands on /home with their old
    // password still live — the reset silently never happens.
    const recovering = AuthState(
      isAuthenticated: true,
      isPasswordRecovery: true,
    );

    test('pins a recovering user to /reset-password from anywhere', () {
      expect(redirect(recovering, '/home'), '/reset-password');
      expect(redirect(recovering, '/jobs'), '/reset-password');
      expect(redirect(recovering, '/profile'), '/reset-password');
    });

    test('lets them stay once they are on /reset-password', () {
      expect(redirect(recovering, '/reset-password'), isNull);
    });

    test('outranks the pending-verification gate', () {
      // Both flags set: recovery must win, or an unverified user following a
      // reset link gets stranded on /verify-email and can never set a password.
      const both = AuthState(
        isAuthenticated: true,
        isPasswordRecovery: true,
        pendingVerificationEmail: 'sam@example.com',
      );
      expect(redirect(both, '/home'), '/reset-password');
    });

    test('releases the user once the flag clears', () {
      const done = AuthState(isAuthenticated: true);
      expect(redirect(done, '/home'), isNull);
    });
  });

  group('auth callback is reachable before the session exists', () {
    // On web the reset/verify link lands here BEFORE gotrue exchanges the
    // code, so the user still reads as unauthenticated at this instant.
    // Bouncing them to /login would abort the exchange.
    test('/auth/callback is public', () {
      expect(redirect(const AuthState(), '/auth/callback'), isNull);
    });

    test('a genuinely private route still bounces to /login', () {
      expect(redirect(const AuthState(), '/profile'), '/login');
    });
  });

  group('regressions from the extraction', () {
    test('splash is always left alone', () {
      expect(redirect(const AuthState(), '/splash'), isNull);
    });

    test('unloaded FTUE holds unauthenticated users on splash', () {
      const loading = FtueGateState(isLoaded: false, hasCompleted: false);
      expect(redirect(const AuthState(), '/login', ftue: loading), '/splash');
    });

    test('authenticated users never see the FTUE', () {
      expect(
        redirect(const AuthState(isAuthenticated: true), '/ftue'),
        '/home',
      );
    });

    test('an authed user on an auth page returns to their pending target', () {
      expect(
        redirect(
          const AuthState(isAuthenticated: true),
          '/login',
          pending: '/jobs/42',
        ),
        '/jobs/42',
      );
    });

    test('...and lands home when there is no pending target', () {
      expect(
        redirect(const AuthState(isAuthenticated: true), '/login'),
        '/home',
      );
    });
  });
}
