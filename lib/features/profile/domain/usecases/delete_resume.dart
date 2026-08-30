import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

/// Deletes the resume object from private-docs and clears both columns.
class DeleteResume {
  const DeleteResume(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, void>> call(String userId) =>
      _repo.deleteResume(userId);
}
