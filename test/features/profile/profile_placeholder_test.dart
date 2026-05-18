import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/tappable_icon.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_placeholder_page.dart';

void main() {
  Widget wrap(Widget child) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(theme: AppTheme.dark(), home: child),
  );

  testWidgets('renders the given title and an honest coming-soon state', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ProfilePlaceholderPage(title: 'Portfolio')),
    );
    await tester.pumpAndSettle();

    // Title in app bar + in the body headline.
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Portfolio is coming soon'), findsOneWidget);
    // Back affordance is the shared TappableIcon (>=44/48 tap target).
    expect(find.byType(TappableIcon), findsOneWidget);
  });
}
