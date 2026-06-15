import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/app_theme.dart';
import 'router/website_router.dart';

/// Root widget for the Jobdun marketing site (`jobdun.com.au`).
///
/// - Single dark theme — brand surface, no toggle.
/// - `ScreenUtilInit` with the design width set to a wide desktop default
///   (1280) so the layout reads at the 360 / 768 / 1280 / 1440 breakpoints
///   the ui-ux-pro-max checklist audits. Phone rendering still respects
///   the OS text scaler (clamped 0.9–1.3 in the theme).
/// - `RouterConfig` driven by the website router. The whole site is one
///   route; anchor scrolling is handled inside `HomePage` so deep links
///   like `jobdun.com.au/#how` land on the right section.
class WebsiteApp extends ConsumerWidget {
  const WebsiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(1280, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Jobdun — workforce platform for Australian construction trades',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          // Force dark; the marketing site doesn't ship a light variant.
          darkTheme: AppTheme.dark(),
          theme: AppTheme.dark(),
          routerConfig: ref.watch(websiteRouterProvider),
        );
      },
    );
  }
}
