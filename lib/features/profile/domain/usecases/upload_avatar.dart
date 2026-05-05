import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

class UploadAvatar {
  const UploadAvatar(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, String>> call(String userId, File file) =>
      _repository.uploadAvatar(userId, file);
}
