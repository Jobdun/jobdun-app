import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_incomplete_banner.dart';

// S8: the profile body leads with ONE specific, highest-impact missing item —
// never a progress ring (profile-dashboard.md anti-pattern). The resolver picks
// the top gap in priority order; the banner renders it (or nothing when done).
void main() {
  group('topTradeGap — priority order', () {
    test('licence is the top gap and routes to verification', () {
      final gap = topTradeGap(
        hasLicence: false,
        hasPortfolio: false,
        hasSuburb: false,
        hasTrade: false,
        phoneVerified: false,
      );
      expect(gap, isNotNull);
      expect(gap!.route, '/verification');
      expect(gap.message.toLowerCase(), contains('licence'));
    });

    test('falls through to portfolio once licensed', () {
      final gap = topTradeGap(
        hasLicence: true,
        hasPortfolio: false,
        hasSuburb: false,
        hasTrade: false,
        phoneVerified: false,
      );
      expect(gap!.message.toLowerCase(), contains('photo'));
    });

    test('returns null when the trade profile is complete', () {
      final gap = topTradeGap(
        hasLicence: true,
        hasPortfolio: true,
        hasSuburb: true,
        hasTrade: true,
        phoneVerified: true,
      );
      expect(gap, isNull);
    });
  });

  group('topBuilderGap — priority order', () {
    test('ABN is the top gap and routes to verification', () {
      final gap = topBuilderGap(
        hasAbn: false,
        hasCompany: false,
        hasServiceArea: false,
        phoneVerified: false,
      );
      expect(gap!.route, '/verification');
      expect(gap.message.toLowerCase(), contains('abn'));
    });

    test('returns null when the builder profile is complete', () {
      final gap = topBuilderGap(
        hasAbn: true,
        hasCompany: true,
        hasServiceArea: true,
        phoneVerified: true,
      );
      expect(gap, isNull);
    });
  });

  Widget wrap(ProfileGap? gap) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: ProfileIncompleteBanner(gap: gap)),
    ),
  );

  testWidgets('banner renders nothing when gap is null', (tester) async {
    await tester.pumpWidget(wrap(null));
    await tester.pumpAndSettle();
    expect(find.text('ADD NOW'), findsNothing);
  });

  testWidgets('banner shows the missing item + ADD NOW', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProfileGap(
          message: 'Add your licence to get more jobs.',
          route: '/verification',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add your licence to get more jobs.'), findsOneWidget);
    expect(find.text('ADD NOW'), findsOneWidget);
  });
}
