import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/core/utils/map_clustering.dart';

// U-map #2: grid clustering — nearby points merge into count bubbles at low
// zoom and resolve to singles as the user zooms in. Pure Dart, no map deps.
void main() {
  MapPoint<String> p(double lat, double lng, String id) =>
      MapPoint(lat: lat, lng: lng, item: id);

  test('two points in the same cell cluster together at low zoom', () {
    final clusters = clusterByGrid([
      p(-33.86, 151.20, 'a'),
      p(-33.87, 151.21, 'b'),
    ], zoom: 10);
    expect(clusters.length, 1);
    expect(clusters.single.items, ['a', 'b']);
    expect(clusters.single.isSingle, isFalse);
  });

  test('the same two points separate at high zoom', () {
    final clusters = clusterByGrid([
      p(-33.86, 151.20, 'a'),
      p(-33.87, 151.21, 'b'),
    ], zoom: 16);
    expect(clusters.length, 2);
    expect(clusters.every((c) => c.isSingle), isTrue);
  });

  test('far-apart points never cluster', () {
    final clusters = clusterByGrid([
      p(-33.86, 151.20, 'sydney'),
      p(-37.81, 144.96, 'melbourne'),
    ], zoom: 6);
    expect(clusters.length, 2);
  });

  test('cluster position is the centroid of its members', () {
    final clusters = clusterByGrid([
      p(-33.80, 151.20, 'a'),
      p(-33.90, 151.30, 'b'),
    ], zoom: 6);
    expect(clusters.length, 1);
    expect(clusters.single.lat, closeTo(-33.85, 0.0001));
    expect(clusters.single.lng, closeTo(151.25, 0.0001));
  });

  test('empty input yields empty output', () {
    expect(clusterByGrid(<MapPoint<String>>[], zoom: 12), isEmpty);
  });
}
