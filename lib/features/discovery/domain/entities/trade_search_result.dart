import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/trade_profile.dart';

/// One search hit: the trade plus the per-query distance from the origin.
/// Distance is contextual, so it lives here rather than on TradeProfile.
class TradeSearchResult extends Equatable {
  const TradeSearchResult({required this.trade, required this.distanceKm});

  final TradeProfile trade;
  final double distanceKm;

  @override
  List<Object?> get props => [trade.id, distanceKm];
}
