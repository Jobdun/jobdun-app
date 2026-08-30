import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/resume_rules.dart';
import '../repositories/profile_repository.dart';

/// Uploads an apprentice resume and stamps it on the trade profile.
///
/// Validates locally first so an oversized or wrong-type file is rejected
/// instantly rather than after a round-trip — a 5 MB upload on site data is a
/// slow way to learn the file was a .pages.
class UploadResume {
  const UploadResume(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, String>> call(
    String userId,
    Uint8List bytes,
    String fileName,
  ) {
    final problem = resumeFileProblem(fileName, bytes.length);
    if (problem != null) {
      return Future.value(Left(ValidationFailure(problem)));
    }
    return _repo.uploadResume(userId, bytes, fileName);
  }
}
