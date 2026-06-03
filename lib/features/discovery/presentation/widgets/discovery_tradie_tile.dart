import 'package:flutter/material.dart';

import '../../../../core/design/widgets/tradie_card.dart';
import '../../domain/entities/trade_search_result.dart';

/// Adapts a [TradeSearchResult] to the shared [TradieCard] (distance, rating,
/// availability badge). "Available now" folds in a passed `available_from`.
class DiscoveryTradieTile extends StatelessWidget {
  const DiscoveryTradieTile({super.key, required this.result, this.onTap});

  final TradeSearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = result.trade;
    final availableNow =
        t.isAvailable ||
        (t.availableFrom != null && !t.availableFrom!.isAfter(DateTime.now()));
    return TradieCard(
      name: t.fullName,
      trade: t.displayTrade,
      suburb: t.baseSuburb ?? t.baseState ?? '',
      rating: t.averageRating ?? 0,
      jobCount: t.jobsCompleted,
      isVerified: t.isVerified,
      isAvailable: availableNow,
      distanceKm: result.distanceKm,
      initials: _initials(t.fullName),
      onTap: onTap,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
