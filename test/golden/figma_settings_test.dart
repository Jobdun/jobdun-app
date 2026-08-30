import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/features/profile/presentation/pages/settings_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

// Fixed [ProfileState] so the page renders without Supabase. Non-trade, which
// is what the mock draws — the trade-only rows stay out of the golden.
class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState();
}

/// Whole-screen golden for the Figma **Setting** frame (`JobDun-Screens` node
/// 134:8995).
///
/// Unlike the component goldens in `figma_homepage_test.dart`, this pumps the
/// real [SettingsPage] so the card rhythm, the row spacing and the Log out /
/// Delete pairing are all gated together — the delete button's placement is
/// the thing most worth catching a regression on.
void main() {
  testWidgets('Settings screen (light)', (tester) async {
    const surface = Size(393, 852);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(_FakeProfileController.new),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: surface, devicePixelRatio: 1.0),
          child: ScreenUtilInit(
            designSize: surface,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: JColors.light.background,
                extensions: const [JColors.light],
              ),
              home: const SettingsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/figma_settings.png'),
    );
  });
}
