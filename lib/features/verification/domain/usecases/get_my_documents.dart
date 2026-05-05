import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification_document.dart';
import '../repositories/verification_repository.dart';

class GetMyDocuments {
  const GetMyDocuments(this._repository);
  final VerificationRepository _repository;

  Future<Either<Failure, List<VerificationDocument>>> call(String userId) =>
      _repository.getMyDocuments(userId);
}
