import 'package:flutter/material.dart';

import '../../../../core/design/widgets/tradie_card.dart';
import '../../../profile/domain/entities/apprenticeship_stage.dart';
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
    // An apprentice's line carries the stage, because "Carpenter" alone
    // would read as a qualified chippy in a list a builder is scanning fast.
    final stage = t.apprenticeshipStage;
    final tradeLine = t.isApprentice && stage != null
        ? '${t.displayTrade} · ${stage.label}'
        : t.displayTrade;

    return TradieCard(
      name: t.fullName,
      trade: tradeLine,
      suburb: t.baseSuburb ?? t.baseState ?? '',
      // 2026-08-18 audit: pass null through for unrated tradies — `?? 0`
      // rendered brand-new tradies as "0.0 /5".
      rating: t.ratingCount == 0 ? null : t.averageRating,
      // An apprentice has no completed jobs yet, and a hard 0 in a scan
      // list reads as a rejection. Show tickets instead — with the noun
      // changed, so the number is never labelled as something it isn't.
      jobCount: t.isApprentice ? t.ticketCount : t.jobsCompleted,
      countNoun: t.isApprentice ? 'ticket' : 'job',
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
