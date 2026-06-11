import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static bool _initialized = false;

  // Custom URL scheme registered in iOS Info.plist + Android Manifest.
  // Used as `emailRedirectTo` on signUp / resend so the verification email
  // bounces tappers back into the app instead of a localhost web page.
  // Hosted Supabase project must allowlist this exact URL.
  static const String authRedirectUrl = 'au.com.jobdun.app://login-callback/';

  static bool get isConfigured => AppEnv.isSupabaseConfigured;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
      // PKCE is the only flow that lets supabase_flutter exchange the inbound
      // deep-link code for a session on mobile. app_links is pulled in
      // transitively, so no extra pubspec dep.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not initialized. Run the app with '
        '--dart-define-from-file=.env after filling .env.',
      );
    }

    return Supabase.instance.client;
  }
}
