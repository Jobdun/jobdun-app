import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/trade_public_profile_page.dart';
import 'package:jobdun/features/reviews/domain/entities/review.dart';
import 'package:jobdun/features/reviews/presentation/providers/reviews_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

// The tradie-side mirror of builder_public_profile_test.dart: what a builder
// opens from a discovery tile before hiring, and what the tradie's own
// "Preview public profile" link points at. Verifies it surfaces the trade +
// track record on load and degrades to an empty state (never a crash) when
// the tradie can't be fetched.
void main() {
  Widget app() => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: const TradePublicProfilePage(tradeId: 't1'),
    ),
  );

  testWidgets('shows the tradie + track record when the profile loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradePublicProfileProvider('t1').overrideWith(
            (ref) async => const TradeProfile(
              id: 't1',
              fullName: 'Dave Nguyen',
              primaryTrade: 'carpenter',
              yearsExperience: 8,
              crewSize: 3,
              averageRating: 4.7,
              ratingCount: 9,
            ),
          ),
          verificationsForUserProvider(
            't1',
          ).overrideWith((ref) async => <Verification>[]),
          reviewsForUserProvider('t1').overrideWith((ref) async => <Review>[]),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dave Nguyen'), findsOneWidget);
    expect(find.text('Carpenter'), findsOneWidget); // slug → display name
    // Both the figure row and the rating block below it show the average.
    expect(find.text('4.7'), findsWidgets); // rating
    expect(find.text('8+'), findsOneWidget); // years experience
    expect(find.text('(9 reviews)'), findsOneWidget); // social-proof count
  });

  testWidgets('renders the trade the tradie typed under "Other"', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradePublicProfileProvider('t1').overrideWith(
            (ref) async => const TradeProfile(
              id: 't1',
              fullName: 'Dave Nguyen',
              primaryTrade: 'other',
              tradeOther: 'Scaffolder',
            ),
          ),
          verificationsForUserProvider(
            't1',
          ).overrideWith((ref) async => <Verification>[]),
          reviewsForUserProvider('t1').overrideWith((ref) async => <Review>[]),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scaffolder'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
  });

  testWidgets('degrades to an empty state when the tradie is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tradePublicProfileProvider('t1').overrideWith((ref) async => null),
          verificationsForUserProvider(
            't1',
          ).overrideWith((ref) async => <Verification>[]),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load this tradie"), findsOneWidget);
  });
}
