class AppEnv {
  const AppEnv._();

  static const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _rawSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _rawSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String get supabaseUrl => _rawSupabaseUrl.trim().replaceAll(
    RegExp(r'/$'),
    '',
  );

  static String get supabaseAnonKey {
    final anonKey = _rawSupabaseAnonKey.trim();
    if (anonKey.isNotEmpty) {
      return anonKey;
    }

    return _rawSupabasePublishableKey.trim();
  }

  static bool get hasSupabaseUrl => supabaseUrl.isNotEmpty;
  static bool get hasSupabaseAnonKey => supabaseAnonKey.isNotEmpty;
  static bool get isSupabaseConfigured =>
      hasSupabaseUrl && hasSupabaseAnonKey;

  static String get missingKeysSummary {
    final missing = <String>[];
    if (!hasSupabaseUrl) {
      missing.add('SUPABASE_URL');
    }
    if (!hasSupabaseAnonKey) {
      missing.add('SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY');
    }
    return missing.join(', ');
  }
}
