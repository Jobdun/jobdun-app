import 'package:flutter/foundation.dart';

// Login-screen funnel instrumentation. Mirrors FtueAnalytics / ProfileAnalytics
// — debugPrint in debug, no-op in release. Swap _emit for the PostHog client
// once that SDK lands.
//
// Funnel:
//   auth.login_screen_viewed
//     → (auth.login_submitted | auth.sso_tapped | auth.phone_tapped
//        | auth.create_account_link_tapped | auth.forgot_password_tapped)
//
// `create_account_link_tapped` validates the "missing signup path" fix —
// if this fires more than ~5% of login_screen_viewed, the missing-link was
// blocking friend-referral signups.
class AuthAnalytics {
  AuthAnalytics._();

  static void loginScreenViewed() {
    _emit('auth.login_screen_viewed', const {});
  }

  static void loginSubmitted() {
    _emit('auth.login_submitted', const {});
  }

  static void ssoTapped({required String provider}) {
    _emit('auth.sso_tapped', {'provider': provider});
  }

  static void phoneTapped() {
    _emit('auth.phone_tapped', const {});
  }

  static void createAccountLinkTapped() {
    _emit('auth.create_account_link_tapped', const {});
  }

  static void forgotPasswordTapped() {
    _emit('auth.forgot_password_tapped', const {});
  }

  // ── Onboarding completion sheet funnel ──────────────────────────────────
  // Fires once when the sheet opens on /home, then per step as the user
  // advances. Combined with signupAuthed + signupCompleted, gives a full
  // funnel per provider: tap → auth → sheet → role → name → avatar → done.

  static void signupStarted({required String provider}) {
    _emit('auth.signup_started', {'provider': provider});
  }

  static void signupAuthed({required String provider, int? msSinceStarted}) {
    _emit('auth.signup_authed', {
      'provider': provider,
      // ignore: use_null_aware_elements
      if (msSinceStarted != null) 'ms_since_started': msSinceStarted,
    });
  }

  static void completionSheetOpened({required int startingStep}) {
    _emit('auth.completion_sheet_opened', {'starting_step': startingStep});
  }

  static void completionStep({
    required String step, // 'role' | 'name' | 'avatar'
    required bool skipped,
    int? msOnStep,
  }) {
    _emit('auth.completion_step', {
      'step': step,
      'skipped': skipped,
      // ignore: use_null_aware_elements
      if (msOnStep != null) 'ms_on_step': msOnStep,
    });
  }

  static void signupCompleted({required String provider, int? totalMs}) {
    _emit('auth.signup_completed', {
      'provider': provider,
      // ignore: use_null_aware_elements
      if (totalMs != null) 'total_ms': totalMs,
    });
  }

  static void signupAbandoned({required String lastStep}) {
    _emit('auth.signup_abandoned', {'last_step': lastStep});
  }

  static void _emit(String event, Map<String, Object?> props) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $props');
    }
    // TODO(analytics): forward to PostHog once the SDK is wired into main().
  }
}
