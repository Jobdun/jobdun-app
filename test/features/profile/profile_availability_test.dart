import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_availability_banner.dart';

TradeProfile _trade({required bool isAvailable, DateTime? availableFrom}) =>
    TradeProfile(
      id: 'u1',
      fullName: 'Jane Doe',
      primaryTrade: 'electrician',
      isAvailable: isAvailable,
      availableFrom: availableFrom,
    );

void main() {
  final now = DateTime(2026, 6, 8);

  group('availabilityDisplay', () {
    test('isAvailable true -> available now', () {
      final v = availabilityDisplay(_trade(isAvailable: true), now: now);
      expect(v.status, AvailabilityStatus.availableNow);
      expect(v.label, 'Available now');
    });

    test('unavailable with a future date -> available from that date', () {
      final from = DateTime(2026, 6, 20);
      final v = availabilityDisplay(
        _trade(isAvailable: false, availableFrom: from),
        now: now,
      );
      expect(v.status, AvailabilityStatus.availableFrom);
      expect(v.label, 'Available from ${DateFormat('d MMM').format(from)}');
    });

    test('unavailable with a past free-from date -> available now', () {
      // Mirrors search semantics: isAvailable || availableFrom <= today.
      final v = availabilityDisplay(
        _trade(isAvailable: false, availableFrom: DateTime(2026, 6, 1)),
        now: now,
      );
      expect(v.status, AvailabilityStatus.availableNow);
      expect(v.label, 'Available now');
    });

    test('unavailable with no date -> not available right now', () {
      final v = availabilityDisplay(_trade(isAvailable: false), now: now);
      expect(v.status, AvailabilityStatus.unavailable);
      expect(v.label, 'Not available right now');
    });

    test('null profile -> unknown', () {
      final v = availabilityDisplay(null, now: now);
      expect(v.status, AvailabilityStatus.unknown);
    });
  });
}
