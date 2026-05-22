import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jobdun/core/services/maptiler_places_service.dart';
import 'package:jobdun/core/services/places_service.dart';
import 'package:latlong2/latlong.dart';

/// Canonical successful MapTiler Geocoding response for "parra". One feature
/// inside an AU postcode + region. The fixture matches the shape we parse in
/// [MapTilerPlacesService._featureToResult] — including the `[lng, lat]`
/// coordinate ordering and the `region.` / `postal_code.` context entries.
String _featureCollection({
  String text = 'Parramatta',
  String placeName = 'Parramatta, New South Wales 2150, Australia',
  String regionFull = 'New South Wales',
  String postcode = '2150',
  double lat = -33.8136,
  double lng = 151.0034,
  String id = 'place.parramatta.au',
}) {
  return jsonEncode({
    'features': [
      {
        'id': id,
        'text': text,
        'place_name': placeName,
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'context': [
          {'id': 'postal_code.au.$postcode', 'text': postcode},
          {'id': 'region.au.nsw', 'text': regionFull},
          {'id': 'country.au', 'text': 'Australia'},
        ],
      },
    ],
  });
}

MapTilerPlacesService _service(
  MockClient client, {
  String apiKey = 'test-key',
}) => MapTilerPlacesService(
  apiKey: apiKey,
  httpClient: client,
  timeout: const Duration(seconds: 2),
);

void main() {
  group('MapTilerPlacesService.autocomplete', () {
    test(
      'parses a Parramatta result with normalised state + postcode',
      () async {
        late Uri capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(_featureCollection(), 200);
        });

        final results = await _service(client).autocomplete('parra');

        expect(capturedUri.host, 'api.maptiler.com');
        expect(capturedUri.path, '/geocoding/parra.json');
        expect(capturedUri.queryParameters['country'], 'au');
        expect(capturedUri.queryParameters['autocomplete'], 'true');
        expect(capturedUri.queryParameters['key'], 'test-key');

        expect(results, hasLength(1));
        final r = results.first;
        expect(r.suburb, 'Parramatta');
        expect(r.state, 'NSW'); // normalised from "New South Wales"
        expect(r.postcode, '2150');
        expect(r.latitude, closeTo(-33.8136, 1e-6));
        expect(r.longitude, closeTo(151.0034, 1e-6));
        expect(r.formattedAddress, contains('Parramatta'));
        expect(r.secondaryText, 'NSW 2150, Australia');
      },
    );

    test('passes proximity when `near` is provided', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(_featureCollection(), 200);
      });

      await _service(client).autocomplete(
        'parra',
        near: const LatLng(-33.87, 151.21), // ~Sydney CBD
      );

      expect(
        capturedUri.queryParameters['proximity'],
        // longitude,latitude order per MapTiler spec
        '151.21,-33.87',
      );
    });

    test(
      'returns empty list for empty/whitespace query without HTTP call',
      () async {
        var hits = 0;
        final client = MockClient((_) async {
          hits++;
          return http.Response('{}', 200);
        });

        final results = await _service(client).autocomplete('   ');

        expect(results, isEmpty);
        expect(hits, 0);
      },
    );

    test('throws PlacesNotConfigured when API key is empty', () async {
      final client = MockClient((_) async => http.Response('{}', 200));

      await expectLater(
        _service(client, apiKey: '').autocomplete('parra'),
        throwsA(isA<PlacesNotConfigured>()),
      );
    });

    test('throws PlacesNetworkError on 500', () async {
      final client = MockClient(
        (_) async => http.Response('boom', 500, reasonPhrase: 'Server Error'),
      );

      await expectLater(
        _service(client).autocomplete('parra'),
        throwsA(isA<PlacesNetworkError>()),
      );
    });

    test('throws PlacesRequestRejected on 401', () async {
      final client = MockClient(
        (_) async =>
            http.Response('unauthorised', 401, reasonPhrase: 'Unauthorized'),
      );

      await expectLater(
        _service(client).autocomplete('parra'),
        throwsA(
          isA<PlacesRequestRejected>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('throws PlacesMalformedResponse when body is not JSON', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));

      await expectLater(
        _service(client).autocomplete('parra'),
        throwsA(isA<PlacesMalformedResponse>()),
      );
    });

    test('throws PlacesNetworkError on transport timeout', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return http.Response(_featureCollection(), 200);
      });

      await expectLater(
        _service(client).autocomplete('parra'),
        throwsA(isA<PlacesNetworkError>()),
      );
    });

    test('caches identical query — second call hits no network', () async {
      var hits = 0;
      final client = MockClient((_) async {
        hits++;
        return http.Response(_featureCollection(), 200);
      });
      final svc = _service(client);

      await svc.autocomplete('parra');
      await svc.autocomplete('parra');

      expect(hits, 1);
    });
  });

  group('MapTilerPlacesService.reverseGeocode', () {
    test('returns the first feature for a position', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(_featureCollection(), 200);
      });

      final result = await _service(
        client,
      ).reverseGeocode(const LatLng(-33.8136, 151.0034));

      expect(result, isNotNull);
      expect(capturedUri.path, '/geocoding/151.0034,-33.8136.json');
      expect(result!.suburb, 'Parramatta');
    });

    test('returns null when MapTiler responds with no features', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'features': []}), 200),
      );

      final result = await _service(
        client,
      ).reverseGeocode(const LatLng(-33.87, 151.21));

      expect(result, isNull);
    });

    test('throws PlacesNotConfigured when API key is empty', () async {
      final client = MockClient((_) async => http.Response('{}', 200));

      await expectLater(
        _service(client, apiKey: '').reverseGeocode(const LatLng(0, 0)),
        throwsA(isA<PlacesNotConfigured>()),
      );
    });
  });
}
