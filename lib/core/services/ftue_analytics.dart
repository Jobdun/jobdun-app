import 'package:flutter/foundation.dart';

// FTUE funnel instrumentation. No analytics SDK is wired into the app yet —
// this is the single place to swap in PostHog (or Firebase, Segment, etc.)
// without touching the carousel widgets. For now every call logs to
// debugPrint in debug builds and is a no-op in release.
//
// Funnel (pair with auth funnel from previous sprint):
//   ftue.started → slide_viewed × n → (skipped | cta_tapped | login_link_tapped)
//   → completed → auth.register_submitted → auth.email_verified → auth.home_loaded
class FtueAnalytics {
  FtueAnalytics._();

  static void started({required String entry}) {
    _emit('ftue.started', {'entry': entry});
  }

  static void slideViewed({
    required int slideIndex,
    required int timeOnPreviousMs,
  }) {
    _emit('ftue.slide_viewed', {
      'slide_index': slideIndex,
      'time_on_previous_ms': timeOnPreviousMs,
    });
  }

  static void skipped({required int fromSlide}) {
    _emit('ftue.skipped', {'from_slide': fromSlide});
  }

  static void ctaTapped({required String role}) {
    _emit('ftue.cta_tapped', {'role': role});
  }

  static void loginLinkTapped({required int fromSlide}) {
    _emit('ftue.login_link_tapped', {'from_slide': fromSlide});
  }

  static void completed({required String exitPath, required int totalTimeMs}) {
    _emit('ftue.completed', {
      'exit_path': exitPath,
      'total_time_ms': totalTimeMs,
    });
  }

  // ── Wow-pass events (IP geo personalisation + hero photography) ──────────
  // Boss-facing metric: ftue.slide_two_rendered tells us what % of users get
  // the personalised wow (variant: 'personalised') vs the generic fallback
  // (variant: 'generic'). The geo_lookup_* trio is the operational diagnostic
  // — distinguishes "ipapi is slow" from "user is overseas".

  static void geoLookupStarted() {
    _emit('ftue.geo_lookup_started', const {});
  }

  static void geoLookupSucceeded({
    String? city,
    String? region,
    required String country,
    required int latencyMs,
  }) {
    _emit('ftue.geo_lookup_succeeded', {
      'city': city,
      'region': region,
      'country': country,
      'latency_ms': latencyMs,
    });
  }

  static void geoLookupFailed({
    required String reason, // 'timeout' | 'non_au' | 'network' | 'parse'
    required int latencyMs,
  }) {
    _emit('ftue.geo_lookup_failed', {
      'reason': reason,
      'latency_ms': latencyMs,
    });
  }

  static void slideTwoRendered({
    required String variant, // 'personalised' | 'generic'
    String? city,
  }) {
    _emit('ftue.slide_two_rendered', {'variant': variant, 'city': city});
  }

  static void imageLoadFailed({
    required int slideIndex,
    required String assetPath,
  }) {
    _emit('ftue.image_load_failed', {
      'slide_index': slideIndex,
      'asset_path': assetPath,
    });
  }

  static void _emit(String event, Map<String, Object?> props) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $props');
    }
    // TODO(analytics): forward to PostHog once the SDK is wired into main().
  }
}
