import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:jobdun/app/constants/app_constants.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/tappable_icon.dart';

void main() {
  Widget wrap(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('hit area is at least the platform minimum', (tester) async {
    await tester.pumpWidget(
      wrap(
        TappableIcon(
          icon: Iconsax.notification,
          semanticLabel: 'Notifications',
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(TappableIcon));
    expect(size.width, greaterThanOrEqualTo(AppTouchTarget.min));
    expect(size.height, greaterThanOrEqualTo(AppTouchTarget.min));
    // 44 is the smallest acceptable value on any platform.
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('stays at minimum even with a tiny glyph', (tester) async {
    await tester.pumpWidget(
      wrap(
        TappableIcon(
          icon: Iconsax.info_circle,
          semanticLabel: 'Info',
          glyphSize: AppIconSize.xs,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(TappableIcon));
    expect(size.width, greaterThanOrEqualTo(AppTouchTarget.min));
    expect(size.height, greaterThanOrEqualTo(AppTouchTarget.min));
  });

  testWidgets('tap invokes the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        TappableIcon(
          icon: Iconsax.close_square,
          semanticLabel: 'Close',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TappableIcon));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('exposes a labeled button to the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        TappableIcon(
          icon: Iconsax.arrow_left,
          semanticLabel: 'Back',
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(TappableIcon)),
      containsSemantics(
        label: 'Back',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('renders the requested glyph at the requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TappableIcon(
          icon: Iconsax.notification,
          semanticLabel: 'Notifications',
          glyphSize: AppIconSize.lg,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Iconsax.notification));
    expect(icon.size, AppIconSize.lg.r);
  });

  testWidgets('disabled (null onTap) has no tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const TappableIcon(
          icon: Iconsax.close_square,
          semanticLabel: 'Close',
          onTap: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(TappableIcon)),
      containsSemantics(
        label: 'Close',
        isButton: true,
        hasTapAction: false,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });
}
