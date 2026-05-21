import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/datasources/review_remote_datasource.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/usecases/get_average_rating.dart';
import '../../domain/usecases/get_reviews_for_user.dart';
import '../../domain/usecases/submit_review.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final reviewDatasourceProvider = Provider<ReviewRemoteDataSource>(
  (ref) => ReviewRemoteDataSourceImpl(SupabaseConfig.client),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepositoryImpl(ref.read(reviewDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final getReviewsForUserUseCaseProvider = Provider(
  (ref) => GetReviewsForUser(ref.read(reviewRepositoryProvider)),
);

final getAverageRatingUseCaseProvider = Provider(
  (ref) => GetAverageRating(ref.read(reviewRepositoryProvider)),
);

final submitReviewUseCaseProvider = Provider(
  (ref) => SubmitReview(ref.read(reviewRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
final reviewsControllerProvider =
    NotifierProvider<ReviewsController, ReviewsState>(ReviewsController.new);

class ReviewsController extends Notifier<ReviewsState> {
  @override
  ReviewsState build() => const ReviewsState();

  Future<void> loadFor(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    final listResult = await ref
        .read(getReviewsForUserUseCaseProvider)
        .call(userId);
    final avgResult = await ref
        .read(getAverageRatingUseCaseProvider)
        .call(userId);
    final reviews = listResult.fold((_) => const <Review>[], (r) => r);
    final avg = avgResult.fold((_) => 0.0, (a) => a);
    final err = listResult.fold((f) => f.message, (_) => null);
    state = state.copyWith(
      isLoading: false,
      reviews: reviews,
      averageRating: avg,
      error: err,
    );
  }

  Future<bool> submit(Review review) async {
    final result = await ref.read(submitReviewUseCaseProvider).call(review);
    return result.fold((f) {
      state = state.copyWith(error: f.message);
      return false;
    }, (_) => true);
  }
}

class ReviewsState {
  const ReviewsState({
    this.reviews = const [],
    this.averageRating = 0.0,
    this.isLoading = false,
    this.error,
  });

  final List<Review> reviews;
  final double averageRating;
  final bool isLoading;
  final String? error;

  ReviewsState copyWith({
    List<Review>? reviews,
    double? averageRating,
    bool? isLoading,
    String? error,
  }) => ReviewsState(
    reviews: reviews ?? this.reviews,
    averageRating: averageRating ?? this.averageRating,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
