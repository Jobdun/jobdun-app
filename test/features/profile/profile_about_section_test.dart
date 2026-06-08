import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_about_section.dart';

void main() {
  Widget wrap(String? about, {String? addPrompt}) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ProfileAboutSection(
          about: about,
          label: 'ABOUT',
          addPrompt: addPrompt,
        ),
      ),
    ),
  );

  testWidgets('renders the eyebrow + bio when about is present', (
    tester,
  ) async {
    await tester.pumpWidget(wrap('Licensed sparky, 12 years on site.'));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Licensed sparky, 12 years on site.'), findsOneWidget);
  });

  testWidgets('renders nothing when about is null', (tester) async {
    await tester.pumpWidget(wrap(null));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsNothing);
  });

  testWidgets('renders nothing when about is blank/whitespace', (tester) async {
    await tester.pumpWidget(wrap('   '));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsNothing);
  });

  // Owner mode: when addPrompt is supplied, an empty bio shows the eyebrow +
  // a tappable Add prompt instead of hiding (own-profile discoverability).
  testWidgets('shows eyebrow + Add prompt when empty and addPrompt given', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(null, addPrompt: 'Add a short bio'));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Add a short bio'), findsOneWidget);
  });

  testWidgets('addPrompt is ignored when a bio exists', (tester) async {
    await tester.pumpWidget(wrap('real bio', addPrompt: 'Add a short bio'));
    await tester.pumpAndSettle();

    expect(find.text('real bio'), findsOneWidget);
    expect(find.text('Add a short bio'), findsNothing);
  });
}
