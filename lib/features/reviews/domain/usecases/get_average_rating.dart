import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/review_repository.dart';

class GetAverageRating {
  const GetAverageRating(this._repository);
  final ReviewRepository _repository;

  Future<Either<Failure, double>> call(String userId) =>
      _repository.getAverageRating(userId);
}
