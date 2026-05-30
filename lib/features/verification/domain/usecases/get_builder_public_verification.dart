import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/builder_public_verification.dart';
import '../repositories/verifications_repository.dart';

/// Reads the minimized counterparty projection for [userId] — the
/// "Verified business" trust signal shown to the other party.
class GetBuilderPublicVerification {
  const GetBuilderPublicVerification(this._repository);
  final VerificationsRepository _repository;

  Future<Either<Failure, List<BuilderPublicVerification>>> call(
    String userId,
  ) => _repository.getPublicVerification(userId);
}
