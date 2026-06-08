import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_rating_block.dart';

// S11: the credibility multiplier isn't the score, it's the COUNT. Show the
// star bar + numeric average + "(N reviews)"; hide entirely when there are
// none (no "0.0" / "no reviews" placeholder on this surface).
void main() {
  group('reviewCountLabel', () {
    test('singular for one review', () {
      expect(reviewCountLabel(1), '1 review');
    });
    test('plural for many', () {
      expect(reviewCountLabel(24), '24 reviews');
    });
  });

  Widget wrap({double? average, required int count}) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ProfileRatingBlock(average: average, count: count),
      ),
    ),
  );

  testWidgets('hides the stars + count when there are no ratings', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(average: null, count: 0));
    await tester.pumpAndSettle();
    expect(find.byType(RatingBarIndicator), findsNothing);
    expect(find.textContaining('review'), findsNothing);
  });

  testWidgets('shows the bar + average + count when rated', (tester) async {
    await tester.pumpWidget(wrap(average: 4.8, count: 24));
    await tester.pumpAndSettle();
    expect(find.byType(RatingBarIndicator), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('(24 reviews)'), findsOneWidget);
  });
}
