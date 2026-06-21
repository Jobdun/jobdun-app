import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/website_app.dart';

/// Jobdun marketing site. Runs at jobdun.com.au.
///
/// Mirrors `lib/admin/main_admin.dart` (the admin web entrypoint). No
/// Supabase / Firebase / Sentry / Hive. The marketing site is a static
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

  // System overlay is left to the active theme. The site now ships both a
  // light and a dark variant (see WebsiteApp + themeModeProvider), so forcing
  // a dark status bar here would fight a light-mode visitor. On web the
  // browser chrome follows the <meta name="theme-color"> in web/index.html.

  runApp(const ProviderScope(child: WebsiteApp()));
}
