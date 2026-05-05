import 'package:intl/intl.dart';

// Pure utility — no Flutter imports.
abstract final class AppDateUtils {
  static String formatShort(DateTime date) => DateFormat('d MMM yyyy').format(date);

  static String formatFull(DateTime date) =>
      DateFormat('EEEE, d MMMM yyyy').format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatShort(date);
  }

  static bool isExpired(DateTime? date) {
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  static bool isExpiringSoon(DateTime? date, {int days = 30}) {
    if (date == null) return false;
    final threshold = DateTime.now().add(Duration(days: days));
    return date.isBefore(threshold) && !isExpired(date);
  }
}
