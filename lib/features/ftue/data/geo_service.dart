import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models/geo_result.dart';

/// Reason codes for the ftue.geo_lookup_failed analytics event. Surfacing
/// these to the caller (instead of just returning null) lets the funnel
/// distinguish "user is overseas — show generic" from "ipapi is degraded —
/// investigate". Both still render the generic slide.
enum GeoFailureReason { timeout, nonAu, network, parse }

/// Result envelope so the provider can fire one analytics event per outcome
/// without re-doing the call.
class GeoLookupOutcome {
  const GeoLookupOutcome._({
    this.result,
    this.failure,
    required this.latencyMs,
  });

  factory GeoLookupOutcome.success(GeoResult r, int latencyMs) =>
      GeoLookupOutcome._(result: r, latencyMs: latencyMs);

  factory GeoLookupOutcome.failure(GeoFailureReason f, int latencyMs) =>
      GeoLookupOutcome._(failure: f, latencyMs: latencyMs);

  final GeoResult? result;
  final GeoFailureReason? failure;
  final int latencyMs;

  bool get succeeded => result != null;
}

/// IP-based city estimator for the FTUE wow-pass. Hits ipapi.co's free tier
/// (no API key required at low volume), caps the wait at 3s, and short-
/// circuits any non-AU response to a generic fallback so we never claim "JOBS
/// IN MANCHESTER" to a UK traveller poking the app.
///
/// Network failures, parse errors, and timeouts all return a failure outcome
/// — the FTUE carousel must never block on this call.
class GeoService {
  GeoService({HttpClient? client, Duration? timeout})
    : _client = client ?? HttpClient(),
      _timeout = timeout ?? const Duration(seconds: 3);

  static final Uri _endpoint = Uri.parse('https://ipapi.co/json/');

  final HttpClient _client;
  final Duration _timeout;

  Future<GeoLookupOutcome> lookup() async {
    final stopwatch = Stopwatch()..start();
    try {
      final request = await _client.getUrl(_endpoint).timeout(_timeout);
      final response = await request.close().timeout(_timeout);

      if (response.statusCode != 200) {
        return GeoLookupOutcome.failure(
          GeoFailureReason.network,
          stopwatch.elapsedMilliseconds,
        );
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return GeoLookupOutcome.failure(
          GeoFailureReason.parse,
          stopwatch.elapsedMilliseconds,
        );
      }

      final country = json['country_code'] as String?;
      if (country != 'AU') {
        return GeoLookupOutcome.failure(
          GeoFailureReason.nonAu,
          stopwatch.elapsedMilliseconds,
        );
      }

      final city = json['city'] as String?;
      return GeoLookupOutcome.success(
        GeoResult(
          city: city,
          region: json['region'] as String?,
          country: country!,
          suburbs: nearbySuburbsFor(city),
        ),
        stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      return GeoLookupOutcome.failure(
        GeoFailureReason.timeout,
        stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      // SocketException, HttpException, anything else network-flavoured.
      return GeoLookupOutcome.failure(
        GeoFailureReason.network,
        stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Hardcoded near-by suburb cluster for v1. Exposed (not private) so the
  /// provider can render the same default chip set when the lookup fails —
  /// users still see real-looking AU suburb names instead of placeholders.
  static List<String> nearbySuburbsFor(String? city) {
    const fallback = ['Parramatta', 'Liverpool', 'Penrith'];
    if (city == null) return fallback;
    const clusters = <String, List<String>>{
      'Sydney': ['Parramatta', 'Penrith', 'Liverpool'],
      'Melbourne': ['Dandenong', 'Frankston', 'Werribee'],
      'Brisbane': ['Logan', 'Ipswich', 'Redcliffe'],
      'Perth': ['Joondalup', 'Rockingham', 'Midland'],
      'Adelaide': ['Salisbury', 'Marion', 'Tea Tree Gully'],
      'Canberra': ['Belconnen', 'Tuggeranong', 'Woden'],
      'Newcastle': ['Maitland', 'Lake Macquarie', 'Cardiff'],
      'Wollongong': ['Shellharbour', 'Kiama', 'Dapto'],
      'Geelong': ['Lara', 'Ocean Grove', 'Drysdale'],
    };
    return clusters[city] ?? fallback;
  }
}
