import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/theme_provider.dart';
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
  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(() => ThemeNotifier(initial: initialTheme)),
      ],
      child: const JobdunApp(),
    ),
  );
}
