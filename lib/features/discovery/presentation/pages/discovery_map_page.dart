import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/map/j_map_carousel.dart';
import '../../../../core/design/widgets/map/j_map_cluster_bubble.dart';
import '../../../../core/design/widgets/map/j_map_price_pin.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/utils/map_clustering.dart';
import '../providers/discovery_provider.dart';
import 'discovery_map_data.dart';

part 'discovery_map_widgets.dart';

/// Full-screen map of nearby tradies for builders (route `/discovery/map`).
/// Markers come from the same `tradeSearchControllerProvider` that feeds the
/// discovery list, so the map and the list always agree.
///
/// Map verdict #1+#2 (2026-06-11): trade-labelled pins (not generic droplets)
/// with clustering, synced both ways to a bottom card carousel — swipe a card
/// and its pin selects + the camera follows; tap a pin and the carousel
/// snaps. Tapping a card opens the compact tradie sheet (the detail step).
class DiscoveryMapPage extends ConsumerStatefulWidget {
  const DiscoveryMapPage({super.key});

  @override
  ConsumerState<DiscoveryMapPage> createState() => _DiscoveryMapPageState();
}

class _DiscoveryMapPageState extends ConsumerState<DiscoveryMapPage> {
  final MapController _controller = MapController();
  late final PageController _pageController = PageController(
    viewportFraction: 0.88,
  );
  int? _selectedIndex;
  double _zoom = 11;

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showPinCard(TradiePin pin) {
    showJSheet<void>(
      context: context,
      builder: (_) => _TradiePinCard(pin: pin),
    );
  }

  void _trackZoom(double zoom) {
    if ((zoom - _zoom).abs() < 0.3) return;
    setState(() => _zoom = zoom);
  }

  void _onPinTap(int index, TradiePin pin) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _controller.move(pin.point, _zoom < 12 ? 12 : _zoom);
  }

  void _onCarouselChanged(List<TradiePin> pins, int index) {
    if (index < 0 || index >= pins.length) return;
    setState(() => _selectedIndex = index);
    _controller.move(pins[index].point, _zoom < 12 ? 12 : _zoom);
  }

  List<Marker> _markers(List<TradiePin> pins, LatLng center, JColors c) {
    final clusters = clusterByGrid([
      for (var i = 0; i < pins.length; i++)
        MapPoint(
          lat: pins[i].point.latitude,
          lng: pins[i].point.longitude,
          item: i,
        ),
    ], zoom: _zoom);
    return [
      for (final cluster in clusters)
        if (cluster.isSingle)
          Marker(
            point: pins[cluster.items.single].point,
            width: 96,
            height: 32,
            alignment: Alignment.center,
            child: JMapPricePin(
              label: pins[cluster.items.single].primaryTrade,
              selected: _selectedIndex == cluster.items.single,
              onTap: () =>
                  _onPinTap(cluster.items.single, pins[cluster.items.single]),
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
              onTap: () =>
                  _controller.move(LatLng(cluster.lat, cluster.lng), _zoom + 2),
            ),
          ),
      // Origin — white dot, orange ring. Distinct from the labelled pins.
      Marker(
        point: center,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white, // intentional: white-on-action
            shape: BoxShape.circle,
            border: Border.all(color: c.action, width: 3),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final results = ref.watch(
      tradeSearchControllerProvider.select((s) => s.results),
    );
    final filter = ref.watch(
      tradeSearchControllerProvider.select((s) => s.filter),
    );
    final pins = DiscoveryMapData.pins(results);
    final center = DiscoveryMapData.center(filter);
    // Offline guardrail: tiles fetch over the network, so explain the grey
    // (cached pins still render). Best-effort — see isOnlineProvider.
    final offline = !(ref.watch(isOnlineProvider).asData?.value ?? true);

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: (camera, _) => _trackZoom(camera.zoom),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: DiscoveryMapData.cartoVoyagerUrl,
                subdomains: DiscoveryMapData.cartoSubdomains,
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.example.jobdun',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: (filter.radiusKm * 1000).toDouble(),
                    useRadiusInMeter: true,
                    color: c.action.withValues(alpha: 0.08),
                    borderColor: c.action,
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(markers: _markers(pins, center, c)),
              // Lifts above the carousel when cards are showing.
              Padding(
                padding: EdgeInsets.only(bottom: pins.isEmpty ? 0 : 112.h),
                child: RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                    ),
                    TextSourceAttribution(
                      'CARTO',
                      onTap: () =>
                          launchUrl(Uri.parse('https://carto.com/attribution')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MapTopBar(count: pins.length, offline: offline),
          ),
          // Recentre control rides above the carousel.
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  12.w,
                  pins.isEmpty ? 28.h : 124.h,
                ),
                child: _CircleButton(
                  icon: AppIcons.location,
                  semanticLabel: 'Recentre on your area',
                  onTap: () => _controller.move(center, 11),
                ),
              ),
            ),
          ),
          // Bottom card carousel (verdict #1) — browse tradies in the thumb
          // zone; tapping a card opens the compact tradie sheet.
          if (pins.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: JMapCarousel(
                    controller: _pageController,
                    itemCount: pins.length,
                    onPageChanged: (i) => _onCarouselChanged(pins, i),
                    itemBuilder: (context, i) => _TradieMapCarouselCard(
                      pin: pins[i],
                      selected: _selectedIndex == i,
                      onTap: () => _showPinCard(pins[i]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One swipeable tradie card in the map carousel — the preview step before
/// the detail sheet. Single caller above.
class _TradieMapCarouselCard extends StatelessWidget {
  const _TradieMapCarouselCard({
    required this.pin,
    required this.selected,
    required this.onTap,
  });

  final TradiePin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          '${pin.name}, ${pin.primaryTrade}, '
          '${pin.distanceKm.toStringAsFixed(1)} kilometres away. '
          'Opens tradie card.',
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
          child: Row(
            children: [
              AvatarBlock(
                initials: pin.name.isEmpty ? '?' : pin.name[0].toUpperCase(),
                size: 40,
                circle: true,
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text1,
                            ),
                          ),
                        ),
                        if (pin.isVerified) ...[
                          Gap(4.w),
                          Icon(
                            AppIcons.verified,
                            size: AppIconSize.micro.r,
                            color: c.verified,
                          ),
                        ],
                      ],
                    ),
                    Gap(2.h),
                    Text(
                      '${pin.primaryTrade} · '
                      '${pin.distanceKm.toStringAsFixed(1)} km away',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.inline.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
