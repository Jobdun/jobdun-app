import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/review.dart';

abstract interface class ReviewRepository {
  Future<Either<Failure, void>> submitReview(Review review);
  Future<Either<Failure, List<Review>>> getReviewsForUser(String userId);
  Future<Either<Failure, double>> getAverageRating(String userId);
  Future<Either<Failure, Review?>> getReviewForJob({
    required String jobId,
    required String reviewerId,
  });
}
