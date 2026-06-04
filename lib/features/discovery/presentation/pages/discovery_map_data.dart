import 'package:latlong2/latlong.dart';

import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';

/// One tradie plotted on the discovery map — the minimum a marker + its tap
/// card need, pre-resolved off the search results so the widget layer stays
/// thin and the projection is unit-testable.
class TradiePin {
  const TradiePin({
    required this.id,
    required this.name,
    required this.point,
    required this.distanceKm,
    required this.primaryTrade,
    required this.isVerified,
  });

  final String id;
  final String name;
  final LatLng point;
  final double distanceKm;
  final String primaryTrade;
  final bool isVerified;
}

/// Pure projection helpers for the discovery map. No Flutter — testable in
/// isolation (see test/features/discovery/discovery_map_data_test.dart).
class DiscoveryMapData {
  const DiscoveryMapData._();

  /// Sydney CBD — last-resort centre when no search origin is set.
  static const LatLng sydney = LatLng(-33.8688, 151.2093);

  // Carto "voyager" raster basemap — free, key-less, colourful so the orange
  // pins pop. Shared by the bento preview and the full-screen map. Attribution
  // is mandatory (rendered via RichAttributionWidget on the full map).
  static const String cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  /// Plottable pins — only results whose trade has BOTH coordinates.
  static List<TradiePin> pins(List<TradeSearchResult> results) => [
    for (final r in results)
      if (r.trade.baseLatitude != null && r.trade.baseLongitude != null)
        TradiePin(
          id: r.trade.id,
          name: r.trade.fullName,
          point: LatLng(r.trade.baseLatitude!, r.trade.baseLongitude!),
          distanceKm: r.distanceKm,
          primaryTrade: r.trade.primaryTrade,
          isVerified: r.trade.isVerified,
        ),
  ];

  /// Map centre: the search origin if set, else [fallback].
  static LatLng center(TradeSearchFilter filter, {LatLng fallback = sydney}) =>
      filter.hasOrigin
      ? LatLng(filter.originLat!, filter.originLng!)
      : fallback;
}
