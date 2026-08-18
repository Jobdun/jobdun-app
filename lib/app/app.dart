import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/services/push_notifications.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class JobdunApp extends ConsumerWidget {
  const JobdunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    // Push taps navigate through the live router. Cold-start routes are
    // buffered in PushNotifications and only flushed once auth is restored,
    // so the router's redirect doesn't eat the destination.
    PushNotifications.attachNavigator(router.push);
    ref.listen(authControllerProvider.select((s) => s.isAuthenticated), (
      _,
      authed,
    ) {
      if (authed) PushNotifications.flushPendingRoute();
    });

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: 'Jobdun',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        // Honor the OS text-size setting but clamp it so fixed-height controls
        // (buttons, nav, badges) don't break at extreme Dynamic Type. 0.9–1.3
        // is the band vetted on the home preview.
        //
        // The GestureDetector is the app-wide keyboard escape: Flutter's
        // built-in tap-outside dismissal is a no-op on iOS/Android touch, so
        // without this any screen whose fields lack a return key (multiline,
        // iOS number/phone pads) traps the keyboard open (live bug S3,
        // 2026-08-18 audit). Translucent hit-testing means taps that land on
        // real controls still win; only taps that fall through to dead space
        // unfocus.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
            child: child!,
          ),
        ),
      ),
    );
  }
}
