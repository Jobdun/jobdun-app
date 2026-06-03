import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

void main() {
  test('TradeSearchFilter copyWith overrides only named fields', () {
    const f = TradeSearchFilter(originLat: -33.8, originLng: 151.2);
    final g = f.copyWith(radiusKm: 10, availableOnly: true);
    expect(g.radiusKm, 10);
    expect(g.availableOnly, isTrue);
    expect(g.originLat, -33.8); // unchanged
  });

  test('TradeSearchFilter clear flags null out fields', () {
    const f = TradeSearchFilter(minRating: 4, query: 'spark');
    final g = f.copyWith(clearMinRating: true, clearQuery: true);
    expect(g.minRating, isNull);
    expect(g.query, isNull);
  });

  test('TradeSearchResult equality is by trade id + distance', () {
    const t = TradeProfile(
      id: 't1',
      fullName: 'Bob',
      primaryTrade: 'electrician',
    );
    const a = TradeSearchResult(trade: t, distanceKm: 2.5);
    const b = TradeSearchResult(trade: t, distanceKm: 2.5);
    expect(a, equals(b));
  });
}
