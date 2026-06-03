import 'package:equatable/equatable.dart';

/// Inputs for a trade-directory search. `origin*` is the point distance is
/// measured from (builder base → place override → device geo).
class TradeSearchFilter extends Equatable {
  const TradeSearchFilter({
    this.originLat,
    this.originLng,
    this.radiusKm = 25,
    this.minRating,
    this.availableOnly = false,
    this.query,
  });

  final double? originLat;
  final double? originLng;
  final int radiusKm;
  final double? minRating;
  final bool availableOnly;
  final String? query;

  bool get hasOrigin => originLat != null && originLng != null;

  TradeSearchFilter copyWith({
    double? originLat,
    double? originLng,
    int? radiusKm,
    double? minRating,
    bool clearMinRating = false,
    bool? availableOnly,
    String? query,
    bool clearQuery = false,
  }) => TradeSearchFilter(
    originLat: originLat ?? this.originLat,
    originLng: originLng ?? this.originLng,
    radiusKm: radiusKm ?? this.radiusKm,
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    availableOnly: availableOnly ?? this.availableOnly,
    query: clearQuery ? null : (query ?? this.query),
  );

  @override
  List<Object?> get props =>
      [originLat, originLng, radiusKm, minRating, availableOnly, query];
}
