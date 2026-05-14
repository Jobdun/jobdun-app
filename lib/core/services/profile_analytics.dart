import 'package:flutter/foundation.dart';

// Profile-completeness funnel + first-home toast instrumentation. Same
// pattern as FtueAnalytics — logs to debugPrint in debug, no-op in release.
// Swap _emit for the PostHog client once that SDK lands.
//
// Funnel:
//   home.first_toast_shown
//   profile.banner_shown → (profile.banner_dismissed | profile.banner_cta_tapped)
class ProfileAnalytics {
  ProfileAnalytics._();

  static void bannerShown({required int pct}) {
    _emit('profile.banner_shown', {'pct': pct});
  }

  static void bannerDismissed() {
    _emit('profile.banner_dismissed', const {});
  }

  static void bannerCtaTapped() {
    _emit('profile.banner_cta_tapped', const {});
  }

  static void firstToastShown({required String role}) {
    _emit('home.first_toast_shown', {'role': role});
  }

  static void _emit(String event, Map<String, Object?> props) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $props');
    }
    // TODO(analytics): forward to PostHog once the SDK is wired into main().
  }
}
