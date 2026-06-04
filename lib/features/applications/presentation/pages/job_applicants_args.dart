import '../../domain/entities/job_application.dart';

/// Immutable payload for the Job → Applicants screen, passed via GoRouter
/// `extra` when pushing `/jobs/:id/applicants`. Display strings only — the
/// applicant rows come from the loaded applications list (filtered by [jobId]).
class JobApplicantsArgs {
  const JobApplicantsArgs({
    required this.jobId,
    required this.title,
    this.tradeType,
    this.locationLabel,
    this.payLabel,
    this.statusLabel,
  });

  final String jobId;
  final String title;
  final String? tradeType;
  final String? locationLabel; // "Parramatta, NSW"
  final String? payLabel; // "$85/hr" or "Quotes requested"
  final String? statusLabel; // "OPEN"
}

/// Immutable payload for the Applicant detail screen (pushed from a row in the
/// Job → Applicants list or the global Applicants tab). Carries the full
/// [JobApplication]; the screen fetches the tradie's profile + verifications
/// from its `tradeId`.
class ApplicantDetailArgs {
  const ApplicantDetailArgs({required this.application, this.jobTitle});

  final JobApplication application;
  final String? jobTitle;
}
