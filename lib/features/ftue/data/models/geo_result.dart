// Session-scoped IP-geo lookup result for the FTUE slide-2 personalisation.
// Held in Riverpod's autoDispose scope and dropped the moment the carousel
// unmounts — never persisted, never linked to a user_id (AU Privacy Act 1988:
// IP-derived city estimation is metadata, not PII).
class GeoResult {
  const GeoResult({
    this.city,
    this.region,
    required this.country,
    required this.suburbs,
  });

  /// Display city (e.g. "Sydney") — null when ipapi.co returned an AU
  /// response with no city (rare; sat behind a national-scale CDN).
  final String? city;

  /// State / territory (e.g. "New South Wales"). Currently unused by the
  /// slide copy but captured so the analytics event can carry it.
  final String? region;

  /// ISO-3166 alpha-2. Always 'AU' — the service short-circuits to null for
  /// any other country so this model only ever represents the personalised
  /// path.
  final String country;

  /// Pre-computed near-by suburb cluster for the chip row on slide 2.
  /// Hardcoded against `city` in `GeoService` — replace with a PostGIS
  /// distance query post-launch.
  final List<String> suburbs;

  /// Headline-cased label for "JOBS IN ___." Falls back to "NEAR YOU" when
  /// `city` is missing so the personalised template still reads cleanly.
  String get displayCity => city?.toUpperCase() ?? 'NEAR YOU';
}
