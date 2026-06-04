import 'package:equatable/equatable.dart';

// Matches schema enum application_status exactly
enum ApplicationStatus {
  pending,
  shortlisted,
  rejected,
  withdrawn,
  hired,
  declinedByTrade,
}

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
    ApplicationStatus.pending => 'Pending',
    ApplicationStatus.shortlisted => 'Shortlisted',
    ApplicationStatus.rejected => 'Rejected',
    ApplicationStatus.withdrawn => 'Withdrawn',
    ApplicationStatus.hired => 'Hired',
    ApplicationStatus.declinedByTrade => 'Declined',
  };

  String get dbValue => switch (this) {
    ApplicationStatus.declinedByTrade => 'declined_by_trade',
    _ => name,
  };

  static ApplicationStatus fromDb(String v) {
    if (v == 'declined_by_trade') return ApplicationStatus.declinedByTrade;
    return ApplicationStatus.values.firstWhere(
      (s) => s.name == v,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

class JobApplication extends Equatable {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.tradeId,
    required this.builderId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.coverNote,
    this.proposedRate,
    this.proposedRateType,
    this.quoteAmount,
    this.availableFrom,
    this.rejectionReason,
    // Joined fields
    this.jobTitle,
    this.jobSuburb,
    this.jobState,
    this.jobStatus,
    this.tradeFullName,
    this.tradePrimaryTrade,
    this.tradeIsVerified,
    this.builderCompanyName,
  });

  final String id;
  final String jobId;
  final String tradeId;
  final String builderId;
  final ApplicationStatus status;
  final String? coverNote;
  // Legacy applicant rate — superseded by [quoteAmount] (in the job's unit).
  final double? proposedRate;
  final String? proposedRateType;
  // The tradie's quote, in the job's pricing unit. Lands on the application
  // only — never writes back to the job. Null when they applied without a quote.
  final double? quoteAmount;
  final DateTime? availableFrom;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined from jobs (trade view)
  final String? jobTitle;
  final String? jobSuburb;
  final String? jobState;
  final String? jobStatus;

  // Joined from trade_profiles (builder view)
  final String? tradeFullName;
  final String? tradePrimaryTrade;
  final bool? tradeIsVerified;

  // Joined from builder_profiles (trade view)
  final String? builderCompanyName;

  @override
  List<Object?> get props => [id, jobId, tradeId, status];
}
