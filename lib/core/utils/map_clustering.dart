import 'dart:math' as math;

/// One plottable item: a coordinate plus the domain object it represents.
class MapPoint<T> {
  const MapPoint({required this.lat, required this.lng, required this.item});

  final double lat;
  final double lng;
  final T item;
}

/// A grid cell's worth of points. [isSingle] clusters render as normal pins;
/// multi-item clusters render as a count bubble that zooms in on tap.
class MapCluster<T> {
  const MapCluster({required this.lat, required this.lng, required this.items});

  /// Centroid of the member points.
  final double lat;
  final double lng;
  final List<T> items;

  bool get isSingle => items.length == 1;
  int get count => items.length;
}

/// Grid-based clustering (U-map #2): cells halve in size per zoom level, so
/// pins merge into count bubbles when zoomed out and resolve to singles as
/// the user zooms in. Pure Dart — unit-tested without any map engine.
///
/// [baseCellDegrees] is the cell size at zoom 0; the default tuned so a
/// typical suburb-level view (zoom ~12) clusters within roughly a few km and
/// street-level views (zoom ≥ 15) are effectively single pins.
List<MapCluster<T>> clusterByGrid<T>(
  List<MapPoint<T>> points, {
  required double zoom,
  double baseCellDegrees = 160.0,
}) {
  if (points.isEmpty) return const [];
  final cell = baseCellDegrees / math.pow(2, zoom);
  final buckets = <String, List<MapPoint<T>>>{};
  for (final point in points) {
    final key = '${(point.lat / cell).floor()}:${(point.lng / cell).floor()}';
    buckets.putIfAbsent(key, () => []).add(point);
  }
  return [
    for (final members in buckets.values)
      MapCluster(
        lat: members.map((m) => m.lat).reduce((a, b) => a + b) / members.length,
        lng: members.map((m) => m.lng).reduce((a, b) => a + b) / members.length,
        items: [for (final m in members) m.item],
      ),
  ];
}
