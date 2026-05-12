import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review.dart';

final reviewsControllerProvider =
    NotifierProvider<ReviewsController, ReviewsState>(ReviewsController.new);

class ReviewsController extends Notifier<ReviewsState> {
  @override
  ReviewsState build() => const ReviewsState();
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
