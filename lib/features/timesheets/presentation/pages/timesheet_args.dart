/// Navigation payload for [TimesheetPage] (#16) — passed via GoRouter `extra`
/// from the schedule. Carries the parties so the trade can clock on/off.
class TimesheetArgs {
  const TimesheetArgs({
    required this.jobId,
    required this.builderId,
    required this.tradeId,
    this.jobTitle,
  });

  final String jobId;
  final String builderId;
  final String tradeId;
  final String? jobTitle;
}
