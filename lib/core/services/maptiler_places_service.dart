import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'places_service.dart';

/// MapTiler Cloud — Geocoding API implementation of [PlacesService].
///
/// Free for 100k req/month; ~\$0.50/1k after. AU-restricted at the request
/// layer (`country=au`). One request per autocomplete keystroke — no separate
/// `details()` round-trip, no session-token billing, no third-party SDK
/// dependency (just `package:http`).
///
/// Light LRU dedupe (~20 query strings) collapses repeat calls in the same
/// app session — saves quota without crossing the disk boundary.
class MapTilerPlacesService implements PlacesService {
  MapTilerPlacesService({
    required this.apiKey,
    required this.httpClient,
    this.timeout = const Duration(seconds: 5),
    this.maxResults = 5,
    this.cacheSize = 20,
  });

  /// Trim/empty key behaviour: every call throws [PlacesNotConfigured].
  final String apiKey;

  /// Injectable so tests can stub responses with mocktail. In production this
  /// is just an `http.Client()` owned by the provider.
  final http.Client httpClient;

  /// Per-request HTTP timeout. 5 s mirrors the dropdown's perceived-latency
  /// budget — slower than this and we'd rather show a fallback.
  final Duration timeout;

  /// Hard cap on suggestions returned. MapTiler defaults to 5; we surface 5
  /// rows in the dropdown so anything more is wasted bytes.
  final int maxResults;

  /// LRU cache capacity. 20 covers typical "user typed → backspaced → retyped"
  /// loops without holding interesting amounts of memory.
  final int cacheSize;

  static const _host = 'api.maptiler.com';

  final LinkedHashMap<String, List<JPlaceResult>> _cache = LinkedHashMap();

  @override
  Future<List<JPlaceResult>> autocomplete(
    String query, {
    LatLng? near,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <JPlaceResult>[];
    }
    if (apiKey.isEmpty) {
      throw const PlacesNotConfigured();
    }

    final cacheKey = _cacheKey(trimmed, near);
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached; // bump to most-recent
      return cached;
    }

    final uri = Uri.https(_host, '/geocoding/${Uri.encodeComponent(trimmed)}.json', {
      'country': 'au',
      'autocomplete': 'true',
      'limit': '$maxResults',
      'language': 'en',
      if (near != null) 'proximity': '${near.longitude},${near.latitude}',
      'key': apiKey,
    });

    final body = await _get(uri);
    final results = _parseFeatures(body);
    _writeCache(cacheKey, results);
    return results;
  }

  @override
  Future<JPlaceResult?> reverseGeocode(LatLng position) async {
    if (apiKey.isEmpty) {
      throw const PlacesNotConfigured();
    }

    final path =
        '/geocoding/${position.longitude},${position.latitude}.json';
    final uri = Uri.https(_host, path, {
      'country': 'au',
      'types': 'address,locality,municipality',
      'limit': '1',
      'language': 'en',
      'key': apiKey,
    });

    final body = await _get(uri);
    final results = _parseFeatures(body);
    return results.isEmpty ? null : results.first;
  }

  // ── HTTP plumbing ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await httpClient.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const PlacesNetworkError('Request timed out.');
    } catch (error) {
      throw PlacesNetworkError('HTTP transport error: $error');
    }

    if (response.statusCode >= 500) {
      throw PlacesNetworkError(
        'MapTiler ${response.statusCode}: ${response.reasonPhrase ?? "server error"}.',
      );
    }
    if (response.statusCode >= 400) {
      throw PlacesRequestRejected(
        'MapTiler rejected the request: ${response.reasonPhrase ?? response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const PlacesMalformedResponse('Response body is not an object.');
      }
      return decoded;
    } on FormatException catch (error) {
      throw PlacesMalformedResponse('Invalid JSON: ${error.message}');
    }
  }

  // ── Parsing ─────────────────────────────────────────────────────────────

  List<JPlaceResult> _parseFeatures(Map<String, dynamic> body) {
    final features = body['features'];
    if (features is! List) {
      throw const PlacesMalformedResponse('Missing "features" array.');
    }

    final out = <JPlaceResult>[];
    for (final raw in features) {
      if (raw is! Map<String, dynamic>) continue;
      final parsed = _featureToResult(raw);
      if (parsed != null) out.add(parsed);
      if (out.length >= maxResults) break;
    }
    return out;
  }

  JPlaceResult? _featureToResult(Map<String, dynamic> f) {
    // Geometry → lat/lng. MapTiler returns [lng, lat] (GeoJSON order).
    final geom = f['geometry'];
    if (geom is! Map<String, dynamic>) return null;
    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lng = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lng == null || lat == null) return null;

    final placeId = (f['id'] as String?)?.trim();
    final placeName = (f['place_name'] as String?)?.trim();
    final mainText = (f['text'] as String?)?.trim();
    if (placeId == null || placeId.isEmpty) return null;
    if (placeName == null || placeName.isEmpty) return null;
    if (mainText == null || mainText.isEmpty) return null;

    // Context → AU-specific components. MapTiler's `context` is a list of
    // {id, text, ...} entries; the `id` prefix tells us the layer
    // (postcode., region., country.).
    final ctx = f['context'];
    final context = (ctx is List)
        ? ctx.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];

    final postcode = _findContext(context, prefix: 'postal_code') ??
        _findContext(context, prefix: 'postcode') ??
        '';
    final region = _findContext(context, prefix: 'region') ?? '';
    if (postcode.isEmpty && !_looksLikeSuburbName(mainText)) {
      // Reject results that aren't a recognisable AU place — guards against
      // POI hits ("Bunnings Parramatta") creeping into the suburb list.
      return null;
    }

    final state = _normaliseAuState(region);
    final suburb = _titleCase(mainText);

    return JPlaceResult(
      placeId: placeId,
      formattedAddress: placeName,
      suburb: suburb,
      state: state,
      postcode: postcode,
      latitude: lat,
      longitude: lng,
      mainText: suburb,
      secondaryText: _secondaryLine(state: state, postcode: postcode),
    );
  }

  String? _findContext(
    List<Map<String, dynamic>> context, {
    required String prefix,
  }) {
    for (final entry in context) {
      final id = entry['id'];
      if (id is! String) continue;
      if (!id.startsWith('$prefix.')) continue;
      final text = entry['text'];
      if (text is String && text.isNotEmpty) return text.trim();
    }
    return null;
  }

  // MapTiler returns AU states in full ("New South Wales"). Map them to the
  // 2–3 letter abbreviations our DB expects.
  String _normaliseAuState(String region) {
    final key = region.trim().toUpperCase();
    if (key.isEmpty) return '';
    return _stateAbbr[key] ?? region.trim();
  }

  static const Map<String, String> _stateAbbr = {
    'NEW SOUTH WALES': 'NSW',
    'VICTORIA': 'VIC',
    'QUEENSLAND': 'QLD',
    'WESTERN AUSTRALIA': 'WA',
    'SOUTH AUSTRALIA': 'SA',
    'TASMANIA': 'TAS',
    'AUSTRALIAN CAPITAL TERRITORY': 'ACT',
    'NORTHERN TERRITORY': 'NT',
    // Allow already-abbreviated input to pass through.
    'NSW': 'NSW',
    'VIC': 'VIC',
    'QLD': 'QLD',
    'WA': 'WA',
    'SA': 'SA',
    'TAS': 'TAS',
    'ACT': 'ACT',
    'NT': 'NT',
  };

  String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  bool _looksLikeSuburbName(String s) =>
      s.length >= 2 && RegExp(r'^[A-Za-z][A-Za-z .\-]*$').hasMatch(s);

  String _secondaryLine({required String state, required String postcode}) {
    final left = [state, postcode].where((s) => s.isNotEmpty).join(' ');
    return left.isEmpty ? 'Australia' : '$left, Australia';
  }

  // ── LRU helpers ─────────────────────────────────────────────────────────

  String _cacheKey(String query, LatLng? near) {
    final loc = near == null
        ? ''
        : '${near.latitude.toStringAsFixed(2)},${near.longitude.toStringAsFixed(2)}';
    return '${query.toLowerCase()}|$loc';
  }

  void _writeCache(String key, List<JPlaceResult> value) {
    _cache.remove(key);
    _cache[key] = value;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}
