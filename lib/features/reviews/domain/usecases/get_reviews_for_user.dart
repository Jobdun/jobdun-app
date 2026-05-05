import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/review.dart';
import '../repositories/review_repository.dart';

class GetReviewsForUser {
  const GetReviewsForUser(this._repository);
  final ReviewRepository _repository;

  Future<Either<Failure, List<Review>>> call(String userId) =>
      _repository.getReviewsForUser(userId);
}
