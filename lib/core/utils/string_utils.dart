abstract final class StringUtils {
  /// Derives a display name from an email address.
  static String nameFromEmail(String email) {
    final local = email.split('@').first;
    final parts = local.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
    final first = parts.isNotEmpty ? parts.first : local;
    if (first.isEmpty) return 'User';
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }

  /// Returns 1–2 uppercase initials from a display name.
  static String initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Formats a [DateTime] as "Today", "Tomorrow", or "12 May".
  static String fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${d.day} ${_months[d.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
