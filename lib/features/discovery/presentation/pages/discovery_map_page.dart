import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../providers/discovery_provider.dart';
import 'discovery_map_data.dart';

part 'discovery_map_widgets.dart';

/// Full-screen map of nearby tradies for builders (route `/discovery/map`).
/// Markers come from the same `tradeSearchControllerProvider` that feeds the
/// discovery list, so the map and the list always agree. Tapping a pin opens a
/// compact tradie card. Centre is the builder's service location (the search
/// origin); no extra GPS prompt — the origin is already resolved on home.
class DiscoveryMapPage extends ConsumerStatefulWidget {
  const DiscoveryMapPage({super.key});

  @override
  ConsumerState<DiscoveryMapPage> createState() => _DiscoveryMapPageState();
}

class _DiscoveryMapPageState extends ConsumerState<DiscoveryMapPage> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPinCard(TradiePin pin) {
    showJSheet<void>(
      context: context,
      builder: (_) => _TradiePinCard(pin: pin),
    );
  }

  List<Marker> _markers(List<TradiePin> pins, LatLng center, JColors c) => [
    for (final pin in pins)
      Marker(
        point: pin.point,
        width: 44,
        height: 56,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            _showPinCard(pin);
          },
          child: SvgPicture.asset(
            'lib/core/assets/map-pin-jobdun.svg',
            width: 44,
            height: 56,
          ),
        ),
      ),
    // Origin — white dot, orange ring. Distinct from the orange tradie pins.
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
              RichAttributionWidget(
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
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MapTopBar(count: pins.length, offline: offline),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 12.w, 28.h),
                child: _CircleButton(
                  icon: AppIcons.location,
                  semanticLabel: 'Recentre on your area',
                  onTap: () => _controller.move(center, 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
