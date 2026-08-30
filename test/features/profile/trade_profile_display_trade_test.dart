import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

/// `displayTrade` is the single funnel every screen reads the tradie's trade
/// through — the profile Trade row, the Skills chip and the discovery tile.
/// The "Other" case is the one that had no path to a screen at all: the
/// picker and the edit sheet both write `trade_other`, but the getter only
/// ever looked at the `primary_trade` slug.
TradeProfile _trade({required String primaryTrade, String? tradeOther}) =>
    TradeProfile(
      id: 't1',
      fullName: 'QA Tradie',
      primaryTrade: primaryTrade,
      tradeOther: tradeOther,
    );

void main() {
  group('TradeProfile.displayTrade', () {
    test('title-cases a single-word slug', () {
      expect(_trade(primaryTrade: 'carpenter').displayTrade, 'Carpenter');
    });

    test('splits an underscored slug into words', () {
      expect(_trade(primaryTrade: 'floor_tiler').displayTrade, 'Floor Tiler');
    });

    test('shows the typed trade when the tradie picked Other', () {
      final p = _trade(primaryTrade: 'other', tradeOther: 'Scaffolder');
      expect(p.displayTrade, 'Scaffolder');
    });

    test('falls back to "Other" when nothing was typed', () {
      expect(_trade(primaryTrade: 'other').displayTrade, 'Other');
      expect(
        _trade(primaryTrade: 'other', tradeOther: '   ').displayTrade,
        'Other',
      );
    });

    test('ignores trade_other left behind on a non-Other trade', () {
      // The edit sheet nulls trade_other when moving off "other", but a
      // legacy row can still carry one — the slug wins.
      final p = _trade(primaryTrade: 'electrician', tradeOther: 'Scaffolder');
      expect(p.displayTrade, 'Electrician');
    });

    test('is blank for an unset trade, so callers can hide the chip', () {
      expect(_trade(primaryTrade: '').displayTrade, isEmpty);
    });
  });

  group('TradeProfile equality', () {
    const base = TradeProfile(
      id: 't1',
      fullName: 'QA Tradie',
      primaryTrade: 'carpenter',
      about: 'Decks and pergolas.',
      hourlyRateMin: 65,
      baseSuburb: 'Balcatta',
      isAvailable: true,
    );

    test('two identical profiles compare equal', () {
      expect(base, equals(base.copyOf()));
    });

    // props used to be [id, fullName, primaryTrade], so every one of these
    // edits produced an object Equatable called equal to the original — a
    // `select((s) => s.tradeProfile)` would have sat on the stale value and
    // the saved edit would never have reached the screen.
    test('an edited bio makes the profile unequal', () {
      expect(base.copyOf(about: 'Full fit-outs.'), isNot(equals(base)));
    });

    test('an edited rate makes the profile unequal', () {
      expect(base.copyOf(hourlyRateMin: 80), isNot(equals(base)));
    });

    test('an edited suburb makes the profile unequal', () {
      expect(base.copyOf(baseSuburb: 'Osborne Park'), isNot(equals(base)));
    });

    test('flipping availability makes the profile unequal', () {
      expect(base.copyOf(isAvailable: false), isNot(equals(base)));
    });
  });
}

extension on TradeProfile {
  /// Local rebuild helper — the entity has no copyWith, and adding one just
  /// for a test would be shipping API to serve the test suite.
  TradeProfile copyOf({
    String? about,
    double? hourlyRateMin,
    String? baseSuburb,
    bool? isAvailable,
  }) => TradeProfile(
    id: id,
    fullName: fullName,
    primaryTrade: primaryTrade,
    about: about ?? this.about,
    hourlyRateMin: hourlyRateMin ?? this.hourlyRateMin,
    baseSuburb: baseSuburb ?? this.baseSuburb,
    isAvailable: isAvailable ?? this.isAvailable,
  );
}
