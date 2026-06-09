// Pure helpers for the schedule calendar (#15). Kept out of the page so the
// day-filter / marker logic is unit-tested without pumping a frame.

import '../../domain/entities/booking.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Bookings scheduled on [day] (date-only compare).
List<Booking> bookingsOn(List<Booking> all, DateTime day) =>
    all.where((b) => _sameDay(b.scheduledDate, day)).toList();

/// True when [day] has at least one non-cancelled booking — drives the calendar
/// marker dot.
bool isDayBooked(List<Booking> all, DateTime day) => all.any(
  (b) => _sameDay(b.scheduledDate, day) && b.status != BookingStatus.cancelled,
);
