import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/app/widgets/admin_list_skeleton.dart';
import 'package:jobdun/app/theme/app_theme.dart';

void main() {
  // Regression: the first-page indicator of every admin PagedListView is
  // dropped into a `SliverFillRemaining(hasScrollBody: false)`, which sizes its
  // child via `getMaxIntrinsicHeight`. The skeleton used a `ListView` (a
  // viewport, no intrinsic height) and threw during layout, so the list only
  // rendered after a manual refresh. It now uses a `Column`, which measures.
  testWidgets('lays out inside SliverFillRemaining without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AdminListSkeleton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminListSkeleton), findsOneWidget);
  });
}
