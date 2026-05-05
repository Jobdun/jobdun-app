import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class UpdateProfile {
  const UpdateProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(UserProfile profile) =>
      _repository.updateProfile(profile);
}
