import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/theme_provider.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
