// Pure date helpers for the trade availability calendar (#13). Kept out of the
// page so the toggle/lookup logic is unit-tested without pumping a frame
// (mirrors `availabilityDisplay` in `profile_availability_banner.dart`).

/// Strips the time-of-day so two calendar taps on the same day compare equal.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// True when [day] is in the trade's marked-unavailable set (date-only compare).
bool isDayUnavailable(List<DateTime> unavailable, DateTime day) =>
    unavailable.any((d) => _sameDay(d, day));

/// Returns a new, date-normalised, sorted list with [day] toggled in/out of the
/// unavailable set. Adding a day appends it; tapping a marked day removes it.
List<DateTime> toggleUnavailableDay(List<DateTime> current, DateTime day) {
  final target = dateOnly(day);
  if (current.any((d) => _sameDay(d, target))) {
    return current.where((d) => !_sameDay(d, target)).toList();
  }
  return [...current.map(dateOnly), target]..sort();
}
