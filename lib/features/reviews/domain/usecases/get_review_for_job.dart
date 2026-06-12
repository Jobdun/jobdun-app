import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/review.dart';
import '../repositories/review_repository.dart';

/// The reviewer's existing review for a job, or null — backs the
/// "already reviewed" state on hired-application cards (one review per
/// reviewer per job, enforced by the DB unique constraint).
class GetReviewForJob {
  const GetReviewForJob(this._repository);
  final ReviewRepository _repository;

  Future<Either<Failure, Review?>> call({
    required String jobId,
    required String reviewerId,
  }) => _repository.getReviewForJob(jobId: jobId, reviewerId: reviewerId);
}
