import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/profile_patches.dart';
import '../repositories/profile_repository.dart';

class PatchUserProfile {
  const PatchUserProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(String userId, UserProfilePatch patch) =>
      _repository.patchUserProfile(userId, patch);
}

class PatchTradeProfile {
  const PatchTradeProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(String userId, TradeProfilePatch patch) =>
      _repository.patchTradeProfile(userId, patch);
}

class PatchBuilderProfile {
  const PatchBuilderProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(
    String userId,
    BuilderProfilePatch patch,
  ) => _repository.patchBuilderProfile(userId, patch);
}
