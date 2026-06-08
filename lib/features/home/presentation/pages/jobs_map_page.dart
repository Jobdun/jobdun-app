part of 'home_page.dart';

/// Full-screen tradie jobs map, pushed OVER the bottom-nav shell (route
/// `/jobs/map`) so it's edge-to-edge with its own back button — mirroring the
/// builder-side [DiscoveryMapPage]. Sources the same feed the home list uses
/// (already loaded by HomePage), so the pins always agree with the list.
///
/// Declared as a `part of home_page.dart` to reuse the [_MapView] defined there
/// without de-part-ifying the whole map stack.
class JobsMapPage extends ConsumerWidget {
  const JobsMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final jobs = ref.watch(jobsControllerProvider.select((s) => s.jobs));
    final placeLabel = ref.watch(
      profileControllerProvider.select(
        (s) => s.tradeProfile?.displayLocation ?? 'Parramatta, NSW',
      ),
    );
    // Offline guardrail: tiles fetch over the network. Pins still render from
    // in-memory feed state; the pill just explains the grey basemap.
    final offline = !(ref.watch(isOnlineProvider).asData?.value ?? true);

    return Scaffold(
      backgroundColor: c.background,
      body: _MapView(
        // Full feed (plottable + coordinate-less) so the map can show the
        // "showing X of Y nearby" coverage hint.
        jobs: jobs,
        placeLabel: placeLabel,
        offline: offline,
        onBack: () => context.pop(),
        onJobTap: (j) =>
            context.push('/jobs/${j.id}', extra: JobDetailArgs.fromJob(j)),
      ),
    );
  }
}
