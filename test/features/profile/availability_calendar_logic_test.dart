import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/presentation/pages/availability_calendar_logic.dart';

void main() {
  group('toggleUnavailableDay', () {
    test('adds a day not already marked, normalised to date-only', () {
      final result = toggleUnavailableDay(
        const [],
        DateTime(2026, 6, 15, 9, 30),
      );
      expect(result, [DateTime(2026, 6, 15)]);
    });

    test('removes a day already marked, ignoring time-of-day', () {
      final result = toggleUnavailableDay([
        DateTime(2026, 6, 15),
      ], DateTime(2026, 6, 15, 18));
      expect(result, isEmpty);
    });

    test('keeps other days and returns a sorted list', () {
      final result = toggleUnavailableDay([
        DateTime(2026, 6, 20),
        DateTime(2026, 6, 10),
      ], DateTime(2026, 6, 15));
      expect(result, [
        DateTime(2026, 6, 10),
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 20),
      ]);
    });
  });

  group('isDayUnavailable', () {
    test('matches a marked day ignoring time-of-day', () {
      expect(
        isDayUnavailable([DateTime(2026, 6, 15)], DateTime(2026, 6, 15, 23)),
        isTrue,
      );
    });

    test('is false for an unmarked day', () {
      expect(
        isDayUnavailable([DateTime(2026, 6, 15)], DateTime(2026, 6, 16)),
        isFalse,
      );
    });
  });
}
