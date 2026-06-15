import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/website_app.dart';

/// Jobdun marketing site — runs at jobdun.com.au.
///
/// Mirrors `lib/admin/main_admin.dart` (the admin web entrypoint). No
/// Supabase / Firebase / Sentry / Hive — the marketing site is a static
/// read-only surface and the .env asset only exists so the build-time
/// `dotenv.load` succeeds.
///
/// Build:   flutter build web -t lib/website/main_website.dart
/// Run:     flutter run -d chrome -t lib/website/main_website.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface any uncaught build errors to the browser console so they're
  // visible in DevTools, not just swallowed by the CanvasKit shell.
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv skipped: $e');
  }

  // Marketing site is dark-only — it's a brand surface, not a product
  // chrome. Edge-to-edge dark status bar so a phone user who adds the
  // site to their home screen doesn't see a white flash.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: WebsiteApp()));
}
