import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/job.dart';

/// Immutable payload passed via GoRouter `extra` when pushing to `/jobs/:id`.
/// Lives in its own file (re-exported from `job_detail_page.dart`) so the page
/// stays under the file-size budget while existing import sites are unchanged.
class JobDetailArgs {
  const JobDetailArgs({
    this.id,
    required this.title,
    required this.description,
    required this.rate,
    required this.startDate,
    required this.distanceKm,
    required this.isUrgent,
    this.tradeType = 'Trades',
    this.suburb,
    this.state,
    this.companyName,
    this.builderInitials,
    this.requiresWhiteCard = false,
    this.requiresLiability = true,
  });

  final String? id;
  final String title;
  final String description;
  final String rate;
  final String startDate;
  final double distanceKm;
  final bool isUrgent;
  final String tradeType;
  final String? suburb;
  final String? state;
  final String? companyName;
  final String? builderInitials;
  final bool requiresWhiteCard;
  final bool requiresLiability;

  factory JobDetailArgs.fromJob(Job job) => JobDetailArgs(
    id: job.id,
    title: job.title,
    description: job.description,
    rate: job.displayBudget,
    startDate: job.startDate != null
        ? StringUtils.fmtDate(job.startDate!)
        : 'TBD',
    distanceKm: 0.0,
    isUrgent: job.urgency == JobUrgency.urgent,
    tradeType: job.tradeTypeRequired,
    suburb: job.suburb,
    state: job.state,
    requiresWhiteCard: job.requiresWhiteCard,
    requiresLiability: job.requiresPublicLiability,
  );
}
