import 'package:shared_preferences/shared_preferences.dart';

// Persistence for in-flight phone OTP. Survives the "user killed the app
// before entering the OTP" case — we restore on next open with a "continue
// with this number?" choice instead of starting from scratch.
class PhoneAuthStorage {
  PhoneAuthStorage._();

  static const _kPhoneKey = 'phone_auth.pending_phone';
  static const _kCountryKey = 'phone_auth.pending_country';
  static const _kSentAtKey = 'phone_auth.sent_at_ms';

  // Codes are valid for 10 min on Supabase Auth — if the stored record is
  // older than that we treat it as stale and don't restore.
  static const Duration _ttl = Duration(minutes: 10);

  static Future<void> save({
    required String e164Phone,
    required String countryCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhoneKey, e164Phone);
    await prefs.setString(_kCountryKey, countryCode);
    await prefs.setInt(_kSentAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Returns null when nothing is stored or the record is older than _ttl.
  static Future<PendingPhone?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_kPhoneKey);
    final country = prefs.getString(_kCountryKey);
    final sentAt = prefs.getInt(_kSentAtKey);
    if (phone == null || country == null || sentAt == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - sentAt;
    if (age > _ttl.inMilliseconds) {
      await clear();
      return null;
    }
    return PendingPhone(e164: phone, countryCode: country, sentAtMs: sentAt);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhoneKey);
    await prefs.remove(_kCountryKey);
    await prefs.remove(_kSentAtKey);
  }
}

class PendingPhone {
  const PendingPhone({
    required this.e164,
    required this.countryCode,
    required this.sentAtMs,
  });

  final String e164;
  final String countryCode;
  final int sentAtMs;
}
