part of 'home_page.dart';

// Map verdict #1+#2 (2026-06-11): price-bearing pins + clustering, synced to
// a bottom card carousel. Mixin-on-State + part-file per the house file-size
// recipe — home_map_view.dart stays under the 500-LOC ceiling.

/// Short, information-bearing pin label: URGENT beats QUOTE beats the rate.
String _jobPinLabel(Job job) {
  if (job.urgency == JobUrgency.urgent) return 'URGENT';
  if (job.pricingType == PricingType.requestQuote) return 'QUOTE';
  if (job.budgetAmount == null) return 'OPEN';
  return '\$${job.budgetAmount!.toStringAsFixed(0)}${job.pricingUnit.suffix}';
}

/// Two-way pin ↔ carousel sync for the jobs map: swipe a card → its pin
/// selects and the camera follows; tap a pin → the carousel snaps to it.
/// Clusters render as count bubbles that zoom in on tap.
mixin _MapPinSync on State<_MapView> {
  /// Implemented by [_MapViewState] — the flutter_map camera handle.
  MapController get _mapController;

  int? _selectedJobIndex;
  double _mapZoom = 12;
  late final PageController _jobPageController = PageController(
    viewportFraction: 0.88,
  );

  @override
  void dispose() {
    _jobPageController.dispose();
    super.dispose();
  }

  /// Jobs with coordinates, in feed order — the carousel's page order and
  /// the pins' index space. Derived per build so a feed refresh stays in sync.
  List<Job> get _plottable => [
    for (final j in widget.jobs)
      if (j.hasLocation) j,
  ];

  void _trackZoom(double zoom) {
    // Re-cluster only on meaningful zoom change — not every pan frame.
    if ((zoom - _mapZoom).abs() < 0.3) return;
    setState(() => _mapZoom = zoom);
  }

  void _onPinTap(int index, LatLng at) {
    setState(() => _selectedJobIndex = index);
    if (_jobPageController.hasClients) {
      _jobPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _mapController.move(at, _mapZoom < 13 ? 13 : _mapZoom);
  }

  void _onCarouselChanged(int index) {
    final jobs = _plottable;
    if (index < 0 || index >= jobs.length) return;
    setState(() => _selectedJobIndex = index);
    final job = jobs[index];
    _mapController.move(
      LatLng(job.latitude!, job.longitude!),
      _mapZoom < 13 ? 13 : _mapZoom,
    );
  }

  /// Price pins for singles, count bubbles for clusters.
  List<Marker> _buildJobMarkers(BuildContext context) {
    final jobs = _plottable;
    final clusters = clusterByGrid([
      for (var i = 0; i < jobs.length; i++)
        MapPoint(lat: jobs[i].latitude!, lng: jobs[i].longitude!, item: i),
    ], zoom: _mapZoom);
    return [
      for (final cluster in clusters)
        if (cluster.isSingle)
          Marker(
            point: LatLng(
              jobs[cluster.items.single].latitude!,
              jobs[cluster.items.single].longitude!,
            ),
            width: 86,
            height: 32,
            alignment: Alignment.center,
            child: JMapPricePin(
              label: _jobPinLabel(jobs[cluster.items.single]),
              selected: _selectedJobIndex == cluster.items.single,
              urgent: jobs[cluster.items.single].urgency == JobUrgency.urgent,
              onTap: () => _onPinTap(
                cluster.items.single,
                LatLng(
                  jobs[cluster.items.single].latitude!,
                  jobs[cluster.items.single].longitude!,
                ),
              ),
            ),
          )
        else
          Marker(
            point: LatLng(cluster.lat, cluster.lng),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: JMapClusterBubble(
              count: cluster.count,
              onTap: () => _mapController.move(
                LatLng(cluster.lat, cluster.lng),
                _mapZoom + 2,
              ),
            ),
          ),
    ];
  }

  /// Bottom carousel overlay — browsing lives in the thumb zone; the map is
  /// for eyes. Hidden when nothing is plottable.
  Widget _buildJobCarousel(BuildContext context) {
    final jobs = _plottable;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: JMapCarousel(
            controller: _jobPageController,
            itemCount: jobs.length,
            onPageChanged: _onCarouselChanged,
            itemBuilder: (context, i) => _JobMapCarouselCard(
              job: jobs[i],
              selected: _selectedJobIndex == i,
              onTap: () => widget.onJobTap(jobs[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One swipeable job card in the map carousel. Tap opens the job detail —
/// the card IS the preview step the old tap-a-pin-and-jump flow lacked.
class _JobMapCarouselCard extends StatelessWidget {
  const _JobMapCarouselCard({
    required this.job,
    required this.selected,
    required this.onTap,
  });

  final Job job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          '${job.title}, ${job.displayBudget}, ${job.displayLocation}. '
          'Opens job details.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: selected ? c.action : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                  ),
                  if (job.urgency == JobUrgency.urgent) ...[
                    Gap(6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: c.urgentBg,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'URGENT',
                        style: tt.labelSmall!.copyWith(
                          letterSpacing: 0.6,
                          color: c.urgentTx,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Gap(4.h),
              Text(
                '${job.displayBudget} · ${job.displayLocation}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall!.copyWith(color: c.text3),
              ),
              Gap(2.h),
              Text(
                'Tap for details →',
                style: tt.bodySmall!.copyWith(color: c.actionInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
