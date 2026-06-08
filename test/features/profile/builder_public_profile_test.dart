import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/builder_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/builder_public_profile_page.dart';
import 'package:jobdun/features/reviews/domain/entities/review.dart';
import 'package:jobdun/features/reviews/presentation/providers/reviews_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

// S13: the public builder profile a tradie opens before applying. Verifies the
// page surfaces the company + track record on load, and degrades to an empty
// state (never a crash) when the builder can't be fetched.
void main() {
  Widget app() => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: const BuilderPublicProfilePage(builderId: 'b1'),
    ),
  );

  testWidgets('shows company + track record when the builder loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          builderPublicProfileProvider('b1').overrideWith(
            (ref) async => const BuilderProfile(
              id: 'b1',
              companyName: 'Acme Builders',
              totalJobsPosted: 12,
              hireCount: 8,
              averageRating: 4.7,
              ratingCount: 9,
            ),
          ),
          verificationsForUserProvider(
            'b1',
          ).overrideWith((ref) async => <Verification>[]),
          reviewsForUserProvider('b1').overrideWith((ref) async => <Review>[]),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acme Builders'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // jobs posted
    expect(find.text('4.7'), findsOneWidget); // rating
    expect(find.text('(9 reviews)'), findsOneWidget); // social-proof count
  });

  testWidgets('degrades to an empty state when the builder is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          builderPublicProfileProvider('b1').overrideWith((ref) async => null),
          verificationsForUserProvider(
            'b1',
          ).overrideWith((ref) async => <Verification>[]),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load this builder"), findsOneWidget);
  });
}
