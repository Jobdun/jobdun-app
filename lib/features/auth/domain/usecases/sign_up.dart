import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  const SignUp(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, AppUser>> call({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _repository.register(email: email, password: password, fullName: fullName);
}
