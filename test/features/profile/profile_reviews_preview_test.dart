import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/reviews/domain/entities/review.dart';
import 'package:jobdun/features/reviews/presentation/providers/reviews_provider.dart';
import 'package:jobdun/features/reviews/presentation/widgets/review_card.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_reviews_preview.dart';

Review _review(String id) => Review(
  id: id,
  jobId: 'j',
  reviewerId: 'r',
  revieweeId: 'u1',
  rating: 5,
  createdAt: DateTime(2026, 5, 1),
  comment: 'Solid work on $id',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget wrap(List<Review> reviews, {String? emptyMessage}) {
    return ProviderScope(
      overrides: [
        reviewsForUserProvider('u1').overrideWith((ref) async => reviews),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileReviewsPreview(
                userId: 'u1',
                emptyMessage: emptyMessage,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows at most 3 cards and a SEE ALL row when there are more', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap([_review('a'), _review('b'), _review('c'), _review('d')]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewCard), findsNWidgets(3));
    expect(find.textContaining('SEE ALL'), findsOneWidget);
  });

  testWidgets('shows all cards and no SEE ALL row at or below 3', (
    tester,
  ) async {
    await tester.pumpWidget(wrap([_review('a'), _review('b')]));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewCard), findsNWidgets(2));
    expect(find.textContaining('SEE ALL'), findsNothing);
  });

  testWidgets('renders nothing when there are no reviews', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewCard), findsNothing);
    expect(find.text('REVIEWS'), findsNothing);
  });

  // Owner mode: empty + emptyMessage shows the eyebrow + an informational note
  // (you can't add your own reviews, so it's a note, not an Add CTA).
  testWidgets('shows eyebrow + note when empty and emptyMessage given', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const [],
        emptyMessage: 'No reviews yet — complete a job to earn one.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewCard), findsNothing);
    expect(find.text('REVIEWS'), findsOneWidget);
    expect(
      find.text('No reviews yet — complete a job to earn one.'),
      findsOneWidget,
    );
  });
}
