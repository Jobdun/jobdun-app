import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

/// Mints a short-lived signed URL for a resume.
///
/// Authorisation is enforced by Postgres, not here: the caller gets a URL only
/// if private_docs_owner_select (they own it) or
/// private_docs_resume_applied_builder_select (the apprentice applied to one
/// of their jobs) admits them. Anyone else gets a Failure, which is the policy
/// working as designed.
///
/// The URL expires in 60 minutes, so mint on tap rather than caching it.
class GetResumeUrl {
  const GetResumeUrl(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, String>> call(String storagePath) =>
      _repo.getResumeSignedUrl(storagePath);
}
