import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';

/// Golden-test surface helper.
///
/// **Why this exists.** Golden tests need a deterministic surface size so
/// pixel diffs aren't just resolution drift. We anchor to 393×852 — iPhone 14
/// — and initialise `ScreenUtil` with the same size so `.w / .h / .sp / .r`
/// resolve to a stable baseline.
///
/// **Dark-only.** Jobdun's light theme is gated (`app_colors.dart:88`); the
/// app ships dark. Goldens follow.
///
/// **Fonts.** Production `AppTheme.dark()` wires every text style through
/// `google_fonts`, which fetches Oswald / Open Sans over the network on
/// first paint. CI sandboxes have no network access and the fetch throws
/// asynchronously, killing the test. We build a parallel `_goldenTheme()`
/// here that mirrors the production colour wiring and `JColors` extension
/// but uses Flutter's default `TextTheme` — the goldens then gate everything
/// the design system actually owns (colour, paddings, borders, radii,
/// motion) without depending on a remote font CDN.
const Size kGoldenSurface = Size(393, 852);

ThemeData _goldenTheme() {
  const c = JColors.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: c.background,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF97316),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF334155),
      onSecondary: Color(0xFFF1F5F9),
      surface: Color(0xFF1E293B),
      onSurface: Color(0xFFF1F5F9),
      error: Color(0xFFEF4444),
      onError: Color(0xFFFFFFFF),
    ),
    extensions: const [c],
  );
}

Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(16),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(kGoldenSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kGoldenSurface, devicePixelRatio: 1.0),
      child: ScreenUtilInit(
        designSize: kGoldenSurface,
        useInheritedMediaQuery: true,
        builder: (_, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _goldenTheme(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: padding,
                child: Align(alignment: Alignment.topCenter, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  if (settle) {
    // Two frames is enough for static layout. pumpAndSettle would hang on any
    // indefinite animation (CircularProgressIndicator etc.).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } else {
    await tester.pump();
  }
}
