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
    this.apprenticesOnly = false,
  });

  final double? originLat;
  final double? originLng;
  final int radiusKm;
  final double? minRating;
  final bool availableOnly;
  final String? query;

  /// TRADES vs APPRENTICES. Maps to `p_apprentice` on search_trades, which
  /// defaults to false and filters to `is_apprentice = false` — so the
  /// existing Discovery result set is unchanged unless this is flipped.
  /// The two modes are mutually exclusive by design: a mixed list would
  /// make a builder compare a first-year against a licensed contractor.
  final bool apprenticesOnly;

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
    bool? apprenticesOnly,
  }) => TradeSearchFilter(
    originLat: originLat ?? this.originLat,
    originLng: originLng ?? this.originLng,
    radiusKm: radiusKm ?? this.radiusKm,
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    availableOnly: availableOnly ?? this.availableOnly,
    query: clearQuery ? null : (query ?? this.query),
    apprenticesOnly: apprenticesOnly ?? this.apprenticesOnly,
  );

  @override
  List<Object?> get props => [
    originLat,
    originLng,
    radiusKm,
    minRating,
    availableOnly,
    query,
    apprenticesOnly,
  ];
}
