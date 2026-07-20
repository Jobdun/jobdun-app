/// Pure helpers reading SSO identity facts off Supabase auth metadata maps.
/// Free of Flutter/Supabase imports so they unit-test without a client.
class SsoIdentity {
  const SsoIdentity._();

  /// True when any linked identity provider supplies the user's name at
  /// auth time (Apple/Google). Those users must never be asked for their
  /// name again (App Review Guideline 4 / Sign in with Apple HIG).
  static bool hasNameProvider(Map<String, dynamic> appMetadata) {
    final raw = appMetadata['providers'];
    final providers = raw is List
        ? raw.whereType<String>().toList()
        : [
            if (appMetadata['provider'] is String)
              appMetadata['provider'] as String,
          ];
    return providers.any((p) => p == 'apple' || p == 'google');
  }

  /// Best-effort display name from user_metadata — every key shape the
  /// handle_new_user trigger recognises (see migration 20260527000006):
  /// full_name, plain-string name, given_name + family_name, and Apple's
  /// nested {"name": {"firstName", "lastName"}} first-signin object.
  static String? metadataDisplayName(Map<String, dynamic>? userMetadata) {
    final m = userMetadata ?? const <String, dynamic>{};
    String? clean(Object? v) {
      final s = (v is String) ? v.trim() : null;
      return (s == null || s.isEmpty) ? null : s;
    }

    final nested = m['name'];
    final composedGiven = [
      m['given_name'],
      m['family_name'],
    ].map(clean).whereType<String>().join(' ');
    final composedNested = nested is Map
        ? [
            nested['firstName'],
            nested['lastName'],
          ].map(clean).whereType<String>().join(' ')
        : '';
    return clean(m['full_name']) ??
        (nested is String ? clean(nested) : null) ??
        clean(composedGiven) ??
        clean(composedNested);
  }
}
