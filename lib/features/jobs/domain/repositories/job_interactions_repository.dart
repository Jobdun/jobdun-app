import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';

/// Per-user "interactions" with jobs that don't live on the job row itself.
///
/// Backed by the `saved_jobs` + `hidden_jobs` join tables added in
/// `supabase/migrations/20260520000004_swipe_actions.sql`. Lives in its
/// own repository so the core [JobRepository] (which deals with the jobs
/// canon — create/read/update on the listings) stays focused.
///
/// Tradie-only surface for now. Builders don't save or hide their own
/// listings; the RLS policies on both tables only allow the row owner to
/// read/write so a builder calling these methods would hit empty results
/// rather than a failure.
abstract interface class JobInteractionsRepository {
  /// Mark a job as saved by the current user. Idempotent — re-saving an
  /// already-saved job is a no-op server-side (primary key is
  /// `(user_id, job_id)`).
  Future<Either<Failure, void>> saveJob(String userId, String jobId);

  /// Remove a job from the user's saved list.
  Future<Either<Failure, void>> unsaveJob(String userId, String jobId);

  /// Hide a job from the user's feed. The job row itself is untouched; only
  /// this user's view filters it out. Other tradies still see it.
  Future<Either<Failure, void>> hideJob(String userId, String jobId);

  /// IDs only — used to drive the filter that hides rows from the main
  /// feed and to toggle the SAVE/UNSAVE swipe label on each card without
  /// joining the whole job rows.
  Future<Either<Failure, Set<String>>> getSavedJobIds(String userId);

  Future<Either<Failure, Set<String>>> getHiddenJobIds(String userId);

  /// Full job rows for the "Saved" feed view. Joins `saved_jobs` to `jobs`
  /// at the data layer so the caller gets a uniform `List<Job>` to render.
  Future<Either<Failure, List<Job>>> getSavedJobs(String userId);
}
