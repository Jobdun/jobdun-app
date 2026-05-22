import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/theme_provider.dart';
import 'core/config/env.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge chrome that matches the dark brand background. Per-screen
  // AppBarTheme.systemOverlayStyle still overrides where an AppBar is mounted
  // (e.g. messaging thread, settings). This baseline catches the many
  // screens that draw a custom header without an AppBar.
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: JColors.dark.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();
  final initialTheme = await loadSavedTheme();

  // Replace Flutter's default red-on-yellow error widget with a dark-themed
  // fallback in release builds. Debug builds keep the default so developers
  // see the stack trace immediately. Sentry still captures the underlying
  // FlutterError.onError event in both modes via SentryFlutter.init below.
  ErrorWidget.builder = _buildErrorWidget;

  // SentryFlutter.init wraps runApp() in runZonedGuarded and hooks
  // FlutterError.onError + PlatformDispatcher.instance.onError so every
  // unhandled exception (sync, async, build-phase) flows to Sentry.
  // Inert when SENTRY_DSN is empty — `appRunner` is invoked either way, so
  // the app launches normally whether or not the DSN is wired.
  await SentryFlutter.init(_configureSentry, appRunner: () {
    runApp(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith(() => ThemeNotifier(initial: initialTheme)),
        ],
        child: const JobdunApp(),
      ),
    );
  });
}

void _configureSentry(SentryFlutterOptions options) {
  options
    ..dsn = AppEnv.sentryDsn
    ..environment = AppEnv.sentryEnvironment
    ..tracesSampleRate = kReleaseMode ? 0.1 : 0.0
    ..attachStacktrace = true
    ..debug = false;
}

// Custom ErrorWidget.builder. Kept outside the State of any widget so it
// references no BuildContext — it's a top-level renderer called by Flutter
// when a build() throws.
Widget _buildErrorWidget(FlutterErrorDetails details) {
  if (kDebugMode) {
    return ErrorWidget(details.exception);
  }
  return ColoredBox(
    color: JColors.dark.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: JColors.dark.urgent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              "Something went wrong on this screen.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: JColors.dark.text1,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We've been notified. Try going back or restarting the app.",
              textAlign: TextAlign.center,
              style: TextStyle(color: JColors.dark.text2, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
}
