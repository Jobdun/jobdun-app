import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';

void main() {
  group('TradeSearchFilter.apprenticesOnly', () {
    test('defaults to false so Discovery keeps showing qualified trades', () {
      expect(const TradeSearchFilter().apprenticesOnly, isFalse);
    });

    test('copyWith flips it in BOTH directions', () {
      // The trap: `apprenticesOnly ?? this.apprenticesOnly` must still be able
      // to set false. It can, because ?? only falls through on null — but a
      // refactor to a truthiness check would silently make the toggle one-way.
      const base = TradeSearchFilter();
      final on = base.copyWith(apprenticesOnly: true);
      expect(on.apprenticesOnly, isTrue);
      expect(on.copyWith(apprenticesOnly: false).apprenticesOnly, isFalse);
    });

    test('omitting it in copyWith preserves the current value', () {
      const on = TradeSearchFilter(apprenticesOnly: true);
      expect(on.copyWith(radiusKm: 50).apprenticesOnly, isTrue);
    });

    test('it participates in equality so a mode switch refetches', () {
      expect(
        const TradeSearchFilter() ==
            const TradeSearchFilter(apprenticesOnly: true),
        isFalse,
      );
    });

    test('switching modes leaves the other filters alone', () {
      const base = TradeSearchFilter(radiusKm: 40, availableOnly: true);
      final switched = base.copyWith(apprenticesOnly: true);
      expect(switched.radiusKm, 40);
      expect(switched.availableOnly, isTrue);
    });
  });
}
