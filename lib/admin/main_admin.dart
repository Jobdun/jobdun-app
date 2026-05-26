import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import 'app/admin_app.dart';

/// Admin web entrypoint. Runs with:
///   flutter run -d chrome -t lib/admin/main_admin.dart
///
/// Reads the same .env asset as the mobile entrypoint — admin and mobile
/// share the Supabase project. The role gate inside [AdminSessionService]
/// ensures only `user_roles.role = 'admin'` accounts can stay signed in.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: AdminApp()));
}
