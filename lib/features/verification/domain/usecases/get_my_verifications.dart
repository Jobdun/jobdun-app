import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification.dart';
import '../repositories/verifications_repository.dart';

class GetMyVerifications {
  const GetMyVerifications(this._repository);
  final VerificationsRepository _repository;

  Future<Either<Failure, List<Verification>>> call(String userId) =>
      _repository.getForUser(userId);
}
