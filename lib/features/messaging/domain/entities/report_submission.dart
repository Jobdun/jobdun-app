import 'package:equatable/equatable.dart';

/// The five report reasons (Ken-locked, Phase D OQ-3). Mirrors the CHECK
/// constraint on public.reports.reason.
enum ReportReason {
  harassment,
  spamOrScam,
  fakeProfile,
  inappropriateContent,
  other;

  String get dbValue => switch (this) {
    harassment => 'harassment',
    spamOrScam => 'spam_or_scam',
    fakeProfile => 'fake_profile',
    inappropriateContent => 'inappropriate_content',
    other => 'other',
  };

  String get label => switch (this) {
    harassment => 'Harassment or bullying',
    spamOrScam => 'Spam or scam',
    fakeProfile => 'Fake profile',
    inappropriateContent => 'Inappropriate content',
    other => 'Something else',
  };
}

/// Typed payload for filing a report — wraps the six inputs so the repo
/// method stays within the ≤4-named-params rule.
class ReportSubmission extends Equatable {
  const ReportSubmission({
    required this.reporterId,
    required this.reportedId,
    required this.conversationId,
    required this.reason,
    this.messageId,
    this.details,
  });

  final String reporterId;
  final String reportedId;
  final String conversationId;
  final String? messageId;
  final ReportReason reason;

  /// Free text, required UX-wise only when [reason] is [ReportReason.other];
  /// capped at 500 chars by the DB CHECK (validated in the use case).
  final String? details;

  @override
  List<Object?> get props => [
    reporterId,
    reportedId,
    conversationId,
    messageId,
    reason,
    details,
  ];
}
