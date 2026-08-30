import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Credentials are loaded from the .env asset at runtime (dotenv.load in main).
// --dart-define-from-file=.env still works as a fallback for CI/CD pipelines.
class AppEnv {
  /// `dotenv.env` THROWS `NotInitializedError` until `dotenv.load()` has run.
  /// Production loads it during bootstrap, but a widget test that pumps a
  /// widget reading any key crashes on a stack trace that says nothing about
  /// the real cause — which is how the tradie map preview started failing once
  /// its basemap began asking whether a MapTiler key exists.
  ///
  /// Reading through here degrades to the compile-time `--dart-define` value
  /// (and then to empty), which is exactly what an absent key already means
  /// everywhere downstream: SSO hides, Sentry no-ops, the basemap falls back to
  /// OpenStreetMap.
  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } on Object {
      return null;
    }
  }

  const AppEnv._();

  static String get supabaseUrl {
    final raw =
        _env('SUPABASE_URL') ?? const String.fromEnvironment('SUPABASE_URL');
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  static String get supabaseAnonKey {
    final raw =
        _env('SUPABASE_ANON_KEY') ??
        _env('SUPABASE_PUBLISHABLE_KEY') ??
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
      (_env('GOOGLE_WEB_CLIENT_ID') ??
              const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'))
          .trim();

  static String get googleIosClientId =>
      (_env('GOOGLE_IOS_CLIENT_ID') ??
              const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'))
          .trim();

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;

  // MapTiler Geocoding — used by JPlaceField for AU-restricted suburb / address
  // autocomplete on profile-edit, job-create, and the jobs-search chip. Free
  // for 100k req/month; ~$0.50/1k after. Get the key from the MapTiler Cloud
  // dashboard (https://www.maptiler.com/cloud/) and restrict it to Geocoding
  // API + the Android package + iOS bundle ID.
  //
  // Absent / empty key is non-fatal: PlacesService surfaces a typed error and
  // JPlaceField falls back to its "Edit manually" legacy 3-field path.
  static String get maptilerApiKey =>
      (_env('MAPTILER_API_KEY') ??
              const String.fromEnvironment('MAPTILER_API_KEY'))
          .trim();

  static bool get hasMaptilerApiKey => maptilerApiKey.isNotEmpty;

  // Sentry crash reporting. Empty DSN = Sentry no-ops cleanly — dev builds
  // and CI runs without the key still launch normally.
  static String get sentryDsn =>
      (_env('SENTRY_DSN') ?? const String.fromEnvironment('SENTRY_DSN')).trim();

  /// Sentry environment tag, derived from the build mode.
  ///
  /// Deliberately does NOT read `.env`. That file is a single asset bundled
  /// into every build and it took precedence over `--dart-define`, so the
  /// `SENTRY_ENVIRONMENT=development` line in it tagged the shipped App Store,
  /// Play and web builds as `development` — every real user crash landed in
  /// the wrong Sentry environment and prod triage saw an empty project
  /// (platform audit, 2026-08-19).
  ///
  /// A `--dart-define` still wins, so a release-mode staging build can be
  /// tagged explicitly (`--dart-define=SENTRY_ENVIRONMENT=staging`).
  static String get sentryEnvironment {
    const override = String.fromEnvironment('SENTRY_ENVIRONMENT');
    if (override.trim().isNotEmpty) return override.trim();
    return kReleaseMode ? 'production' : 'development';
  }

  static bool get hasSentryDsn => sentryDsn.isNotEmpty;
}
