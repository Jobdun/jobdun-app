import '../../domain/entities/job.dart';

/// Counts behind the tradie "jobs near you" map hint. Pre-resolved off the feed
/// so the widget layer stays thin and the projection is unit-testable.
class JobMapSummary {
  const JobMapSummary({required this.plotted, required this.total});

  /// Jobs actually drawn as pins (have both coordinates).
  final int plotted;

  /// All jobs in the feed (plotted + coordinate-less).
  final int total;

  /// Every job in the feed has a pin location.
  bool get allPlotted => total > 0 && plotted == total;

  /// At least one job is missing coordinates, so the map shows fewer pins than
  /// the list — the trigger for the "showing X of Y nearby" hint.
  bool get someDropped => total > plotted;

  /// Jobs exist but none can be plotted (all coordinate-less). Distinct from an
  /// empty feed: drives the "no map pins yet — switch to the list" note.
  bool get nonePlotted => total > 0 && plotted == 0;
}

/// Pure projection helpers for the tradie job map. No Flutter — testable in
/// isolation (see test/features/jobs/job_map_data_test.dart). Mirrors
/// [DiscoveryMapData] on the builder side.
class JobMapData {
  const JobMapData._();

  /// Plottable jobs — only those with BOTH coordinates. The marker source.
  static List<Job> plottable(List<Job> jobs) =>
      jobs.where((j) => j.hasLocation).toList();

  /// Plotted-vs-total counts for the map hint.
  static JobMapSummary summary(List<Job> jobs) => JobMapSummary(
    plotted: jobs.where((j) => j.hasLocation).length,
    total: jobs.length,
  );
}
