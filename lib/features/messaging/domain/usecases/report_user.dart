import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/report_submission.dart';
import '../repositories/message_repository.dart';

class ReportUser {
  const ReportUser(this._repo);
  final MessageRepository _repo;

  /// Validates before the network: "other" needs free text so admins have
  /// something to act on; the 500-char cap mirrors the DB CHECK.
  Future<Either<Failure, void>> call(ReportSubmission report) {
    final details = report.details?.trim() ?? '';
    if (report.reason == ReportReason.other && details.isEmpty) {
      return Future.value(
        left(const ValidationFailure('Tell us what happened.')),
      );
    }
    if (details.length > 500) {
      return Future.value(
        left(
          const ValidationFailure('Details must be 500 characters or fewer.'),
        ),
      );
    }
    return _repo.reportUser(report: report);
  }
}
