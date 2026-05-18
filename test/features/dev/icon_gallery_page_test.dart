import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/features/dev/presentation/pages/icon_gallery_page.dart';

Widget _host() => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: ThemeData(extensions: const [JColors.dark]),
    home: const IconGalleryPage(),
  ),
);

void main() {
  testWidgets('renders every AppIcons catalogue glyph', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    for (final entry in AppIcons.catalogue) {
      final tile = find.byKey(ValueKey('gallery-${entry.group}-${entry.name}'));
      await tester.scrollUntilVisible(tile, 120, scrollable: list);
      expect(
        tile,
        findsOneWidget,
        reason: 'missing tile for AppIcons.${entry.name}',
      );
    }
  });

  testWidgets('shows a header for each icon group', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    final groups = {for (final e in AppIcons.catalogue) e.group};
    for (final g in groups) {
      final header = find.text(g.toUpperCase());
      await tester.scrollUntilVisible(header, 120, scrollable: list);
      expect(header, findsOneWidget);
    }
  });
}
