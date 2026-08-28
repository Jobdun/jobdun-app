import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/design/widgets/jobdun_logo.dart';
import 'package:jobdun/features/auth/presentation/pages/splash_widgets/splash_shutter.dart';

// The Figma frame the splash geometry is authored against (JobDun-Screens,
// nodes 17:5059 / 14:5022 / 14:4068).
const Size _surface = Size(393, 852);

// Mark 40.0866 x 59 centred; the settled lockup is 249 wide, so the mark
// travels (249 - 40.0866) / 2 to make room for the wordmark.
const double _markH = 59;
const double _markW = 40.0866;
const double _travel = (249 - _markW) / 2;

Finder get _whiteMarks =>
    find.byWidgetPredicate((w) => w is JobdunLogo && w.color == Colors.white);
Finder get _groundMark => find.byWidgetPredicate(
  (w) =>
      w is JobdunLogo &&
      w.variant == LogoVariant.mark &&
      w.color != Colors.white,
);
Finder get _wordmark => find.byWidgetPredicate(
  (w) => w is JobdunLogo && w.variant == LogoVariant.wordmark,
);

Future<void> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
  VoidCallback? onSettled,
}) async {
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: _surface,
        devicePixelRatio: 1,
        disableAnimations: reducedMotion,
      ),
      child: ScreenUtilInit(
        designSize: _surface,
        useInheritedMediaQuery: true,
        builder: (_, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            extensions: const [JColors.dark],
          ),
          home: Scaffold(body: SplashShutter(onSettled: onSettled)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('SplashShutter geometry', () {
    testWidgets('opens with the mark dead centre, shutter closed', (
      tester,
    ) async {
      await _pump(tester);

      expect(_whiteMarks, findsNWidgets(2)); // one per retracting half
      expect(_groundMark, findsOneWidget);

      final centreX = _surface.width / 2 - _markW / 2;
      final centreY = _surface.height / 2 - _markH / 2;
      for (final m in tester.widgetList(_whiteMarks).toList().asMap().keys) {
        final tl = tester.getTopLeft(_whiteMarks.at(m));
        expect(tl.dx, closeTo(centreX, 0.5));
        expect(tl.dy, closeTo(centreY, 0.5), reason: 'half $m starts pinned');
      }
      expect(tester.getTopLeft(_groundMark).dx, closeTo(centreX, 0.5));
    });

    // The regression that matters: each half counter-translates by its own
    // travel, so the glyph stays pinned to the screen while the panel edge
    // sweeps across it. Counter-move by the wrong quantity (e.g. the mark's
    // own height instead of the panel's) and the white marks ride away with
    // the panels, destroying the two-tone moment.
    testWidgets('white marks stay pinned while the halves retract', (
      tester,
    ) async {
      await _pump(tester);
      final centreY = _surface.height / 2 - _markH / 2;

      // Step through the split beat (600ms -> 1160ms) in place.
      var elapsed = 0;
      for (final t in [700, 880, 1000, 1160]) {
        await tester.pump(Duration(milliseconds: t - elapsed));
        elapsed = t;

        for (var i = 0; i < 2; i++) {
          expect(
            tester.getTopLeft(_whiteMarks.at(i)).dy,
            closeTo(centreY, 0.5),
            reason: 'half $i drifted at ${t}ms',
          );
        }
      }
    });

    testWidgets('mark lands one half-lockup left of centre', (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();

      final start = _surface.width / 2 - _markW / 2;
      expect(
        tester.getTopLeft(_groundMark).dx,
        closeTo(start - _travel, 0.5),
        reason: 'settled mark should sit at Figma x=72',
      );
    });

    testWidgets('reduced motion settles immediately and reports done', (
      tester,
    ) async {
      var settled = false;
      await _pump(tester, reducedMotion: true, onSettled: () => settled = true);
      await tester.pump();

      final start = _surface.width / 2 - _markW / 2;
      expect(tester.getTopLeft(_groundMark).dx, closeTo(start - _travel, 0.5));
      expect(settled, isTrue);
      expect(_wordmark, findsOneWidget);
    });

    testWidgets('reports completion exactly once', (tester) async {
      var calls = 0;
      await _pump(tester, onSettled: () => calls++);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
    });
  });
}
