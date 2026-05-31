import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/core/design/widgets/animated_empty_glyph.dart';

void main() {
  Widget wrap(Widget child) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  // This is a *looping* animation (repeat), so we never pumpAndSettle (it would
  // time out) — we pump a few frames and assert it builds + animates clean.
  for (final motion in EmptyGlyphMotion.values) {
    testWidgets('AnimatedEmptyGlyph.$motion loops without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(AnimatedEmptyGlyph(icon: AppIcons.search, motion: motion)),
      );
      await tester.pump(); // start
      await tester.pump(const Duration(milliseconds: 600)); // mid-loop

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedEmptyGlyph), findsOneWidget);
      expect(find.byIcon(AppIcons.search), findsOneWidget);
    });
  }
}
