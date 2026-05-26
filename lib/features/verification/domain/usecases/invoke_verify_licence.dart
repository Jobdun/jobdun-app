import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification.dart';
import '../repositories/verifications_repository.dart';

class InvokeVerifyLicence {
  const InvokeVerifyLicence(this._repository);
  final VerificationsRepository _repository;

  Future<Either<Failure, VerifyResult>> call({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  }) => _repository.verifyLicence(
    licenceNumber: licenceNumber,
    state: state,
    tradeClass: tradeClass,
  );
}
