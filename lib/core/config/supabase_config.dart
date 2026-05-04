import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static bool _initialized = false;

  static bool get isConfigured => AppEnv.isSupabaseConfigured;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
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
