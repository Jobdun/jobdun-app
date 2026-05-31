import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/animated_jobdun_logo.dart';

void main() {
  Widget wrap(Widget child) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  // Pumps each variant through its full one-shot. The `draw` case matters most:
  // building its painter triggers `parseSvgPathData` on the embedded hammer-J
  // path + a PathMetrics trace — the runtime path that isn't reachable from the
  // static JobdunLogo — so this guards a malformed path string or a painter
  // regression.
  for (final variant in JLogoAnim.values) {
    testWidgets('AnimatedJobdunLogo.$variant animates without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(AnimatedJobdunLogo(variant: variant, height: 120)),
      );
      await tester.pump(); // first frame — controller starts
      await tester.pump(const Duration(milliseconds: 500)); // mid-animation
      await tester.pumpAndSettle(); // run the one-shot to completion

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedJobdunLogo), findsOneWidget);
    });
  }
}
