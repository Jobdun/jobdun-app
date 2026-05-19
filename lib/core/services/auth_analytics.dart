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

  static void _emit(String event, Map<String, Object?> props) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $props');
    }
    // TODO(analytics): forward to PostHog once the SDK is wired into main().
  }
}
