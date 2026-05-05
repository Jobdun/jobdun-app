import 'package:flutter_dotenv/flutter_dotenv.dart';

// Credentials are loaded from the .env asset at runtime (dotenv.load in main).
// --dart-define-from-file=.env still works as a fallback for CI/CD pipelines.
class AppEnv {
  const AppEnv._();

  static String get supabaseUrl {
    final raw = dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL');
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  static String get supabaseAnonKey {
    final raw = dotenv.env['SUPABASE_ANON_KEY'] ??
        dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY');
    return raw.trim();
  }

  static bool get hasSupabaseUrl => supabaseUrl.isNotEmpty;
  static bool get hasSupabaseAnonKey => supabaseAnonKey.isNotEmpty;
  static bool get isSupabaseConfigured => hasSupabaseUrl && hasSupabaseAnonKey;

  static String get missingKeysSummary {
    final missing = <String>[];
    if (!hasSupabaseUrl) missing.add('SUPABASE_URL');
    if (!hasSupabaseAnonKey) missing.add('SUPABASE_ANON_KEY');
    return missing.join(', ');
  }

  // Google Sign-In — both values required for the native flow.
  // Get them from console.cloud.google.com → APIs & Credentials → OAuth 2.0 Client IDs.
  static String get googleWebClientId =>
      (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
              const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'))
          .trim();

  static String get googleIosClientId =>
      (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ??
              const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'))
          .trim();

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
