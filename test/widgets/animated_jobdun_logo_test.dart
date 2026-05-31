import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/animated_jobdun_logo.dart';

void main() {
  Widget wrap(Widget child, ThemeData theme) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  // Theme *builders* (tear-offs), not built themes — building a theme calls
  // GoogleFonts, which needs the test binding, so it must happen inside a test,
  // not at collection time.
  final themes = <String, ThemeData Function()>{
    'dark': AppTheme.dark,
    'light': AppTheme.light,
  };

  // Pumps each variant through its full one-shot in BOTH themes. Two runtime
  // paths matter most:
  //   - draw: building its painter triggers `parseSvgPathData` on the embedded
  //     hammer-J path + a PathMetrics trace (guards a malformed path string),
  //     and in light mode it also paints the orange badge behind a white J.
  //   - forge/strike: in light mode they wrap the badge variant of JobdunLogo.
  // A throw in either theme is caught here.
  for (final variant in JLogoAnim.values) {
    for (final entry in themes.entries) {
      testWidgets(
        'AnimatedJobdunLogo.$variant animates without throwing (${entry.key})',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              AnimatedJobdunLogo(variant: variant, height: 120),
              entry.value(),
            ),
          );
          await tester.pump(); // first frame — controller starts
          await tester.pump(const Duration(milliseconds: 500)); // mid-animation
          await tester.pumpAndSettle(); // run the one-shot to completion

          expect(tester.takeException(), isNull);
          expect(find.byType(AnimatedJobdunLogo), findsOneWidget);
        },
      );
    }
  }
}
