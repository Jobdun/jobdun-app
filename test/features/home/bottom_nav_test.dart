import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:jobdun/app/constants/app_constants.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/home/presentation/pages/home_shell_page.dart';
import 'package:jobdun/features/home/presentation/widgets/tab_spec.dart';

void main() {
  Widget wrap(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(bottomNavigationBar: child),
      ),
    );
  }

  group('TabSpec.forRole', () {
    test('returns 5 trade slots in router-branch order', () {
      final tabs = TabSpec.forRole(UserRole.trade);
      expect(tabs.length, 5);
      expect(tabs.map((t) => t.label), [
        'Home',
        'Jobs',
        'Applied',
        'Messages',
        'Profile',
      ]);
    });

    test('screen-reader labels are decoupled from visible labels', () {
      final tabs = TabSpec.forRole(UserRole.trade);
      expect(tabs[1].label, 'Jobs');
      expect(tabs[1].semanticLabel, 'Find work');
      expect(tabs[2].label, 'Applied');
      expect(tabs[2].semanticLabel, 'My applications');
    });

    test('builder reuses the trade slots (no regression pre-rollout)', () {
      expect(
        TabSpec.forRole(UserRole.builder).map((t) => t.label),
        TabSpec.forRole(UserRole.trade).map((t) => t.label),
      );
    });
  });

  group('BottomNav', () {
    BottomNav build({int index = 0, ValueChanged<int>? onTap}) => BottomNav(
      currentIndex: index,
      tabs: TabSpec.forRole(UserRole.trade),
      onTap: onTap ?? (_) {},
    );

    testWidgets('renders all 5 visible labels', (tester) async {
      await tester.pumpWidget(wrap(build()));
      await tester.pumpAndSettle();

      for (final l in ['Home', 'Jobs', 'Applied', 'Messages', 'Profile']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('active slot = Bold glyph, inactive = outline glyph', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(build(index: 0)));
      await tester.pumpAndSettle();

      // index 0 active → Bold home; index 1 inactive → outline briefcase.
      expect(find.byIcon(Iconsax.home_25), findsOneWidget);
      expect(find.byIcon(Iconsax.home_2), findsNothing);
      expect(find.byIcon(Iconsax.briefcase), findsOneWidget);
      expect(find.byIcon(Iconsax.briefcase5), findsNothing);
    });

    testWidgets('active label uses action color + bold weight', (tester) async {
      await tester.pumpWidget(wrap(build(index: 0)));
      await tester.pumpAndSettle();

      final c = JColors.dark;
      TextStyle styleOf(String text) =>
          DefaultTextStyle.of(tester.element(find.text(text))).style;

      expect(styleOf('Home').color, c.action);
      expect(styleOf('Home').fontWeight, FontWeight.w700);
      expect(styleOf('Jobs').color, c.text3);
      expect(styleOf('Jobs').fontWeight, FontWeight.w600);
    });

    testWidgets('tapping a slot reports its index', (tester) async {
      int? tapped;
      await tester.pumpWidget(wrap(build(onTap: (i) => tapped = i)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Messages'));
      expect(tapped, 3);
    });

    testWidgets('every tab meets the 48dp tap-target guideline', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(build()));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(
        tester.getSize(find.byType(BottomNav)).height,
        greaterThanOrEqualTo(AppTouchTarget.min),
      );
    });

    testWidgets('iPhone SE width (320) does not overflow or truncate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 690);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(build()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final l in ['Home', 'Jobs', 'Applied', 'Messages', 'Profile']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('SR label is decoupled from the visible chip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(build()));
      await tester.pumpAndSettle();

      // Visible chip says "Jobs"; screen reader announces "Find work".
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.bySemanticsLabel('Find work'), findsOneWidget);
      handle.dispose();
    });
  });
}
