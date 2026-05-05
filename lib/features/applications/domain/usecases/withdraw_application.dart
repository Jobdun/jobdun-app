import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/application_repository.dart';

class WithdrawApplication {
  const WithdrawApplication(this._repository);
  final ApplicationRepository _repository;

  Future<Either<Failure, void>> call(String applicationId) =>
      _repository.withdraw(applicationId);
}
