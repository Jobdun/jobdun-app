import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/features/reviews/domain/entities/review.dart';
import 'package:jobdun/features/reviews/domain/repositories/review_repository.dart';
import 'package:jobdun/features/reviews/presentation/providers/reviews_provider.dart';
import 'package:jobdun/features/reviews/presentation/widgets/review_compose_sheet.dart';
import 'package:jobdun/features/reviews/presentation/widgets/review_cta.dart';
import 'package:mocktail/mocktail.dart';

class _MockReviewRepository extends Mock implements ReviewRepository {}

Review _review({int rating = 4}) => Review(
  id: 'r-1',
  jobId: 'j-1',
  reviewerId: 'user-1',
  revieweeId: 'trade-1',
  rating: rating,
  createdAt: DateTime(2026, 6, 12),
);

void main() {
  late _MockReviewRepository repo;

  setUpAll(() {
    registerFallbackValue(_review());
  });

  setUp(() {
    repo = _MockReviewRepository();
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(repo),
      currentUserIdSyncProvider.overrideWithValue('user-1'),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );

  group('ReviewCta', () {
    testWidgets('offers the review button when no review exists', (
      tester,
    ) async {
      when(
        () => repo.getReviewForJob(jobId: 'j-1', reviewerId: 'user-1'),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        wrap(
          const ReviewCta(
            jobId: 'j-1',
            revieweeId: 'trade-1',
            revieweeName: 'Mick',
            label: 'REVIEW TRADIE',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REVIEW TRADIE'), findsOneWidget);
    });

    testWidgets('shows the rated state once a review exists', (tester) async {
      when(
        () => repo.getReviewForJob(jobId: 'j-1', reviewerId: 'user-1'),
      ).thenAnswer((_) async => Right(_review(rating: 4)));

      await tester.pumpWidget(
        wrap(
          const ReviewCta(
            jobId: 'j-1',
            revieweeId: 'trade-1',
            revieweeName: 'Mick',
            label: 'REVIEW TRADIE',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOU RATED 4/5'), findsOneWidget);
      expect(find.text('REVIEW TRADIE'), findsNothing);
    });
  });

  group('ReviewComposeSheet', () {
    testWidgets('submit stays disabled until a star rating is picked', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ReviewComposeSheet(
            jobId: 'j-1',
            revieweeId: 'trade-1',
            revieweeName: 'Mick',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(ReviewComposeSheet),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('picking stars and submitting writes the review', (
      tester,
    ) async {
      when(
        () => repo.submitReview(any()),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        wrap(
          const ReviewComposeSheet(
            jobId: 'j-1',
            revieweeId: 'trade-1',
            revieweeName: 'Mick',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 4th star.
      await tester.tap(find.byIcon(AppIcons.starFilled).at(3));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Quality work, on time.');
      await tester.tap(find.text('SUBMIT REVIEW'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => repo.submitReview(captureAny())).captured.single
              as Review;
      expect(captured.jobId, 'j-1');
      expect(captured.revieweeId, 'trade-1');
      expect(captured.reviewerId, 'user-1');
      expect(captured.rating, 4);
      expect(captured.comment, 'Quality work, on time.');
    });
  });
}
