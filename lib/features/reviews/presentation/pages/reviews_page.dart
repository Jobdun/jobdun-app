import '../../../../core/widgets/feature_scaffold_page.dart';

class ReviewsPage extends FeatureScaffoldPage {
  const ReviewsPage({super.key})
    : super(
        title: 'Reviews',
        subtitle: 'Ratings and reviews from completed jobs.',
        bullets: const [
          'Builders rate trades after job completion.',
          'Trades rate builders after job completion.',
          'Reviews are public and shown on profiles.',
        ],
      );
}
