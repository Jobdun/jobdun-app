import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/review.dart';
import '../repositories/review_repository.dart';

class SubmitReview {
  const SubmitReview(this._repository);
  final ReviewRepository _repository;

  Future<Either<Failure, void>> call(Review review) =>
      _repository.submitReview(review);
}
