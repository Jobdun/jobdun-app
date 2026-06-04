import '../../domain/entities/job_application.dart';

/// Pure tab model for the applications status filter.
///
/// Owns the roster per role, the predicate per tab, per-tab counts (for the
/// chip badges), and the display label — so the page stays a thin view and the
/// filter/count logic is unit-testable without pumping a widget.
enum AppTab { all, pending, shortlisted, hired, rejected }

extension AppTabX on AppTab {
  String get label => switch (this) {
    AppTab.all => 'All',
    AppTab.pending => 'Pending',
    AppTab.shortlisted => 'Shortlisted',
    AppTab.hired => 'Hired',
    AppTab.rejected => 'Rejected',
  };

  /// Whether [a] belongs in this tab. `all` always matches.
  bool matches(JobApplication a) => switch (this) {
    AppTab.all => true,
    AppTab.pending => a.status == ApplicationStatus.pending,
    AppTab.shortlisted => a.status == ApplicationStatus.shortlisted,
    AppTab.hired => a.status == ApplicationStatus.hired,
    AppTab.rejected => a.status == ApplicationStatus.rejected,
  };
}

class ApplicationTabs {
  const ApplicationTabs._();

  /// The status filters shown for a role. Builders also triage rejections, so
  /// they get the `Rejected` tab; tradies don't.
  static List<AppTab> forRole({required bool isBuilder}) => [
    AppTab.all,
    AppTab.pending,
    AppTab.shortlisted,
    AppTab.hired,
    if (isBuilder) AppTab.rejected,
  ];

  static List<JobApplication> filter(List<JobApplication> apps, AppTab tab) =>
      tab == AppTab.all ? apps : apps.where(tab.matches).toList();

  static int count(List<JobApplication> apps, AppTab tab) =>
      tab == AppTab.all ? apps.length : apps.where(tab.matches).length;
}
