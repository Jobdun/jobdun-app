import 'package:flutter/foundation.dart';

// Trade Home instrumentation. Same pattern as ProfileAnalytics / FtueAnalytics —
// logs to debugPrint in debug, no-op in release. Swap _emit for the PostHog
// client once that SDK lands.
//
// Events:
//   home.card_tapped {job_id}
//   home.refresh
class HomeAnalytics {
  HomeAnalytics._();

  static void cardTapped({required String jobId}) {
    _emit('home.card_tapped', {'job_id': jobId});
  }

  static void refresh() {
    _emit('home.refresh', const {});
  }

  static void _emit(String event, Map<String, Object?> props) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $props');
    }
    // TODO(analytics): forward to PostHog once the SDK is wired into main().
  }
}
