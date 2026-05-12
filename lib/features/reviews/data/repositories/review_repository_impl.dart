import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_datasource.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._datasource);
  final ReviewRemoteDataSource _datasource;

  @override
  Future<Either<Failure, void>> submitReview(Review review) async {
    try {
      await _datasource.submitReview(review as ReviewModel);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Review>>> getReviewsForUser(String userId) async {
    try {
      return right(await _datasource.getReviewsForUser(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, double>> getAverageRating(String userId) async {
    try {
      final reviews = await _datasource.getReviewsForUser(userId);
      if (reviews.isEmpty) return right(0.0);
      final avg =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      return right(avg);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Review?>> getReviewForJob({
    required String jobId,
    required String reviewerId,
  }) async {
    try {
      return right(
        await _datasource.getReviewForJob(jobId: jobId, reviewerId: reviewerId),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
