import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification.dart';
import '../repositories/verifications_repository.dart';

class InvokeVerifyAbn {
  const InvokeVerifyAbn(this._repository);
  final VerificationsRepository _repository;

  Future<Either<Failure, VerifyResult>> call(String abn) =>
      _repository.verifyAbn(abn);
}
