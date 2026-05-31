import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/app_theme.dart';
import 'router/admin_router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);

    // Desktop design size — ScreenUtil scales .w / .h / .sp / .r against
    // a 1440x900 reference so the core JButton / JTextField primitives
    // (which assume ScreenUtil is initialized) behave sanely in a browser.
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        title: 'Jobdun Admin',
        theme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        // Clamp Dynamic Type (0.9–1.3) so the shared fixed-height primitives
        // behave at extreme OS font sizes — same band as the mobile app root.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
          child: child!,
        ),
      ),
    );
  }
}
