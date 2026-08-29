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
/// **Light-only.** Light is Jobdun's canonical theme — the Figma foundation is
/// authored on a light ground and new installs start there. Goldens follow the
/// canonical theme; dark is guarded by `colors_contrast_test.dart` rather than
/// by a second set of pixels.
///
/// **Fonts.** Production `AppTheme.light()` wires every text style through
/// `google_fonts`, which fetches Archivo / Inter over the network on
/// first paint. CI sandboxes have no network access and the fetch throws
/// asynchronously, killing the test. We build a parallel `_goldenTheme()`
/// here that mirrors the production colour wiring and `JColors` extension
/// but uses Flutter's default `TextTheme` — the goldens then gate everything
/// the design system actually owns (colour, paddings, borders, radii,
/// motion) without depending on a remote font CDN.
const Size kGoldenSurface = Size(393, 852);

ThemeData _goldenTheme() {
  const c = JColors.light;
  // Every role is DERIVED from the tokens — never a literal. A hardcoded hex
  // here silently outlives the next palette change and the goldens quietly
  // stop mirroring production (which is exactly what happened to `primary`
  // across the #F97316 → #FC5101 migration).
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.light(
      primary: c.action,
      onPrimary: c.onAction,
      secondary: c.surfaceRaised,
      onSecondary: c.text1,
      surface: c.surface,
      onSurface: c.text1,
      error: c.urgent,
      onError: const Color(0xFFFFFFFF),
    ),
    extensions: const [c],
    // Mirrors production's InputDecorationTheme *structurally* — fill,
    // borders, radius, padding. The text styles are left off because
    // production builds them with google_fonts, which fetches over the
    // network and throws in a sandboxed test.
    //
    // Without this the goldens rendered Flutter's default underline field and
    // silently guarded nothing: `filled` defaults to false, so JTextField's
    // per-state fill was never painted. Anything that can regress the field's
    // chrome has to be visible here.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.action, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.urgent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.urgent, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: c.border.withValues(alpha: 0.4)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: c.text3,
      suffixIconColor: c.text3,
    ),
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
