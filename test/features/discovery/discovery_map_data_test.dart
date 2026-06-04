import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/presentation/pages/discovery_map_data.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

TradeSearchResult _result({
  required String id,
  double? lat,
  double? lng,
  String name = 'Jo Tradie',
  bool verified = false,
  double distanceKm = 1.0,
}) => TradeSearchResult(
  trade: TradeProfile(
    id: id,
    fullName: name,
    primaryTrade: 'carpenter',
    baseLatitude: lat,
    baseLongitude: lng,
    isVerified: verified,
  ),
  distanceKm: distanceKm,
);

void main() {
  group('DiscoveryMapData.pins', () {
    test('drops results without coordinates', () {
      final pins = DiscoveryMapData.pins([
        _result(id: 'a', lat: -33.8, lng: 151.2),
        _result(id: 'b'), // no coords
        _result(id: 'c', lat: -33.9, lng: 151.1),
      ]);
      expect(pins.map((p) => p.id), ['a', 'c']);
    });

    test('drops a result with only one coordinate', () {
      final pins = DiscoveryMapData.pins([_result(id: 'a', lat: -33.8)]);
      expect(pins, isEmpty);
    });

    test('maps trade fields onto the pin', () {
      final pins = DiscoveryMapData.pins([
        _result(
          id: 'a',
          lat: -33.87,
          lng: 151.21,
          name: 'Mia Sparks',
          verified: true,
          distanceKm: 4.2,
        ),
      ]);
      final pin = pins.single;
      expect(pin.id, 'a');
      expect(pin.name, 'Mia Sparks');
      expect(pin.isVerified, isTrue);
      expect(pin.distanceKm, 4.2);
      expect(pin.point, const LatLng(-33.87, 151.21));
    });
  });

  group('DiscoveryMapData.center', () {
    test('uses the filter origin when set', () {
      const filter = TradeSearchFilter(originLat: -27.47, originLng: 153.02);
      expect(DiscoveryMapData.center(filter), const LatLng(-27.47, 153.02));
    });

    test('falls back to Sydney when origin is absent', () {
      const filter = TradeSearchFilter();
      expect(DiscoveryMapData.center(filter), DiscoveryMapData.sydney);
    });
  });
}
