import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/scheduling/domain/entities/booking.dart';
import 'package:jobdun/features/scheduling/presentation/pages/schedule_logic.dart';

Booking _b({
  required String id,
  required DateTime date,
  BookingStatus status = BookingStatus.scheduled,
}) => Booking(
  id: id,
  jobId: 'j1',
  builderId: 'b1',
  tradeId: 't1',
  scheduledDate: date,
  status: status,
  createdAt: DateTime(2026),
);

void main() {
  final list = [
    _b(id: '1', date: DateTime(2026, 6, 15)),
    _b(id: '2', date: DateTime(2026, 6, 15)),
    _b(id: '3', date: DateTime(2026, 6, 20)),
    _b(id: '4', date: DateTime(2026, 6, 25), status: BookingStatus.cancelled),
  ];

  test('bookingsOn returns only that day, time-of-day ignored', () {
    final result = bookingsOn(list, DateTime(2026, 6, 15, 14));
    expect(result.map((b) => b.id), ['1', '2']);
  });

  test('isDayBooked is true for a day with an active booking', () {
    expect(isDayBooked(list, DateTime(2026, 6, 20)), isTrue);
  });

  test('isDayBooked is false for a day with only a cancelled booking', () {
    expect(isDayBooked(list, DateTime(2026, 6, 25)), isFalse);
  });

  test('isDayBooked is false for an empty day', () {
    expect(isDayBooked(list, DateTime(2026, 6, 16)), isFalse);
  });
}
